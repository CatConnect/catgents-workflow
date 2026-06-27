# role: team-manager (orquestrador)

**Cadência:** 5 minutos
**Responsabilidade:** ler o estado completo do repo e atribuir trabalho aos workers certos.

O team-manager é o único que decide o que deve ser feito.
Ele nunca implementa, nunca revisa código, nunca mergeia — só orquestra.

---

## Fase 1 — BUSCAR

```bash
# Estado completo do repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
echo "[worker:team-manager] lendo estado de $REPO"

# Issues sem label de status (não classificadas)
UNCLASSIFIED=$(gh issue list --state open --json number,title,labels \
  | jq '[.[] | select(.labels | map(.name) | any(startswith("status:")) | not)]')

# Issues needs-scope sem spec (aguardando definição)
NEEDS_SCOPE=$(gh issue list --state open --label "status:needs-scope" \
  --json number,title,assignees,comments --limit 20)

# Issues ready sem assignee (prontas, ninguém pegou)
READY_UNASSIGNED=$(gh issue list --state open --label "status:ready" \
  --json number,title,assignees,labels \
  | jq '[.[] | select(.assignees | length == 0)]')

# PRs abertas sem label de status (precisam de QA)
PRS_NO_LABEL=$(gh pr list --state open --json number,title,labels,author \
  | jq '[.[] | select(.labels | map(.name) | any(startswith("status:")) | not)]')

# PRs needs-review sem assignee de QA
PRS_NEEDS_QA=$(gh pr list --state open --label "status:needs-review" \
  --json number,title,assignees \
  | jq '[.[] | select(.assignees | length == 0)]')

# PRs qa-approved sem assignee de reviewer
PRS_NEEDS_REVIEW=$(gh pr list --state open --label "status:qa-approved" \
  --json number,title,assignees \
  | jq '[.[] | select(.assignees | length == 0)]')

# PRs qa-blocked sem assignee de dev para corrigir
PRS_QA_BLOCKED=$(gh pr list --state open --label "status:qa-blocked" \
  --json number,title,assignees,author \
  | jq '[.[] | select(.assignees | length == 0)]')

echo "[worker:team-manager] não-classificadas: $(echo $UNCLASSIFIED | jq length)"
echo "[worker:team-manager] needs-scope: $(echo $NEEDS_SCOPE | jq length)"
echo "[worker:team-manager] ready sem assignee: $(echo $READY_UNASSIGNED | jq length)"
echo "[worker:team-manager] PRs sem status: $(echo $PRS_NO_LABEL | jq length)"
echo "[worker:team-manager] PRs aguardando QA: $(echo $PRS_NEEDS_QA | jq length)"
echo "[worker:team-manager] PRs aguardando merge: $(echo $PRS_NEEDS_REVIEW | jq length)"
echo "[worker:team-manager] PRs qa-blocked sem dev: $(echo $PRS_QA_BLOCKED | jq length)"
```

---

## Fase 2 — EXECUTAR

Execute cada ação abaixo na ordem. Cada uma é independente — não pare se uma não tiver itens.

### Ação 1 — Classificar issues não-classificadas

Para cada issue em `UNCLASSIFIED`, spawne subagente de classificação:

```
Você é um subagente de triage. NÃO pergunte — classifique e retorne JSON.

Issue: #<N> — <título>
Body: <body>
Repo: <url>

Raciocine passo a passo antes de retornar.

Classifique:
1. A issue tem escopo suficiente para implementar? (critérios claros, área definida)
2. Qual área? (backend/frontend/infra/db/docs/qa)
3. Qual risco? (low/high/conflict/migration/auth)
4. Se risk:high ou risk:auth ou risk:migration → status:needs-scope (humano deve aprovar)
5. Se escopo insuficiente → status:needs-scope
6. Se tudo ok → status:ready

Retorne:
{
  "reasoning": "...",
  "status": "needs-scope" | "ready" | "blocked",
  "area": "backend" | "frontend" | "infra" | "db" | "docs" | "qa",
  "risk": "low" | "high" | "conflict" | "migration" | "auth",
  "scope_comment": "uma linha explicando a classificação"
}
```

Após receber retorno do subagente:
```bash
gh issue edit <N> \
  --add-label "status:<status>,area:<area>,risk:<risk>"
gh issue comment <N> \
  --body "## 🏷️ Classificado pelo team-manager\n\n<scope_comment>\n\nStatus: status:<status> | Área: area:<area> | Risco: risk:<risk>"
```

### Ação 2 — Escrever spec para issues needs-scope

Para cada issue em `NEEDS_SCOPE` sem comentário de spec (sem "## Spec" no histórico):

```
Você é um subagente de produto. NÃO pergunte — escreva a spec e retorne JSON.

Issue: #<N> — <título>
Body: <body>
Repo: <url>

Raciocine passo a passo antes de retornar.

Escreva uma spec implementável com:
1. Contexto (por que isso importa)
2. Critérios de aceitação (checkboxes mensuráveis)
3. Escopo explícito (o que NÃO está incluído)
4. Área e risco confirmados

Retorne:
{
  "reasoning": "...",
  "spec_markdown": "## Spec\n\n...",
  "pronto_para_dev": true | false,
  "motivo_bloqueio": "..." | null
}
```

Após receber retorno:
```bash
gh issue comment <N> --body "<spec_markdown>"

# Se pronto_para_dev:
gh issue edit <N> --remove-label "status:needs-scope" --add-label "status:ready"

# Se bloqueado:
gh issue comment <N> --body "## ⚠️ Requer decisão humana\n\n<motivo_bloqueio>\n\n@<owner>"
gh issue edit <N> --add-label "risk:high"
```

### Ação 3 — Atribuir dev para issues ready

Para cada issue em `READY_UNASSIGNED` (máx 1 por ciclo para não sobrecarregar):

```bash
# Verifica se dev já tem issue em andamento
DEV_LOAD=$(gh issue list --state open --label "status:in-progress" \
  --assignee vhsmdev --json number | jq length)

if [ "$DEV_LOAD" -lt 2 ]; then
  gh issue edit <N> \
    --add-assignee vhsmdev \
    --add-label "status:in-progress" \
    --remove-label "status:ready"
  gh issue comment <N> \
    --body "## 👷 Atribuído pelo team-manager\n\n@vhsmdev implementar conforme spec acima."
  echo "[worker:team-manager] ✓ #<N> atribuída para dev"
else
  echo "[worker:team-manager] dev já tem $DEV_LOAD issues — aguardando"
fi
```

### Ação 4 — Rotular PRs sem status

Para cada PR em `PRS_NO_LABEL`:
```bash
# Verifica se tem issue vinculada
HAS_ISSUE=$(gh pr view <N> --json body -q '.body' | grep -cE 'Closes #|Fixes #|Resolves #' || echo 0)

if [ "$HAS_ISSUE" -eq 0 ]; then
  gh pr edit <N> --add-label "status:needs-review"
  gh pr comment <N> --body "## ⚠️ PR sem issue vinculada\n\nAdicione 'Closes #N' no body para fechar a issue automaticamente no merge."
else
  gh pr edit <N> --add-label "status:needs-review"
fi
echo "[worker:team-manager] ✓ PR #<N> → status:needs-review"
```

### Ação 5 — Atribuir QA para PRs needs-review

Para cada PR em `PRS_NEEDS_QA`:
```bash
gh pr edit <N> --add-assignee vhsmdev  # ou usuário do qa worker
gh pr comment <N> --body "## 🔍 Atribuído para QA pelo team-manager"
echo "[worker:team-manager] ✓ PR #<N> → qa assignado"
```

### Ação 6 — Atribuir reviewer para PRs qa-approved

Para cada PR em `PRS_NEEDS_REVIEW`:
```bash
gh pr edit <N> --add-assignee vhsmdev  # ou usuário do reviewer
gh pr comment <N> --body "## ✅ QA aprovado — atribuído para merge pelo team-manager"
echo "[worker:team-manager] ✓ PR #<N> → reviewer assignado"
```

### Ação 7 — Reatribuir dev para PRs qa-blocked

Para cada PR em `PRS_QA_BLOCKED`:
```bash
# Atribui de volta ao autor original da PR
AUTHOR=$(gh pr view <N> --json author -q '.author.login')
gh pr edit <N> --add-assignee "$AUTHOR"
gh pr comment <N> --body "## 🔄 Retornado para correção pelo team-manager\n\n@$AUTHOR veja os comentários de QA acima e corrija."
echo "[worker:team-manager] ✓ PR #<N> → $AUTHOR para corrigir qa-blocked"
```

### Ação 8 — Detectar e corrigir estados inválidos

```bash
# issues in-progress sem assignee (dev morreu)
ORPHAN_ISSUES=$(gh issue list --state open --label "status:in-progress" \
  --json number,title,assignees \
  | jq '[.[] | select(.assignees | length == 0)]')

echo "$ORPHAN_ISSUES" | jq -r '.[] | "#\(.number)"' | while read N; do
  gh issue edit "$N" --remove-label "status:in-progress" --add-label "status:ready"
  gh issue comment "$N" --body "## 🔧 Corrigido pelo team-manager\n\nIssue estava in-progress sem assignee (worker morreu). Retornada para status:ready."
  echo "[worker:team-manager] ✓ #$N corrigido → status:ready"
done

# issues in-progress com PR já mergeada (não fechou automaticamente)
gh issue list --state open --label "status:in-progress" --json number | jq -r '.[].number' | while read N; do
  MERGED=$(gh pr list --state merged --search "Closes #$N OR Fixes #$N OR Resolves #$N" \
    --json number -q '.[0].number // empty' 2>/dev/null)
  if [ -n "$MERGED" ]; then
    gh issue close "$N" --comment "## ✅ Fechada pelo team-manager\n\nPR #$MERGED foi mergeada. Issue fechada manualmente pois 'Closes #$N' não funcionou automaticamente."
    echo "[worker:team-manager] ✓ #$N fechada — PR #$MERGED já mergeada"
  fi
done
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:team-manager] ciclo concluído — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[worker:team-manager] próximo ciclo em 5 minutos"
```
