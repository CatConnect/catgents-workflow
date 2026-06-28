# role: team-manager (orquestrador)

**Cadência:** 5 minutos
**Responsabilidade:** ler o estado completo do repo e atribuir trabalho aos workers certos.

O team-manager é o único que decide o que deve ser feito.
Ele nunca implementa, nunca revisa código, nunca mergeia — só orquestra.

---

## Inicialização — Normalizar labels do repo

Execute **uma única vez** antes do loop. Garante que o repo usa exatamente
o padrão de labels da skill — sem truncadas, duplicatas ou aliases.

```bash
echo "[worker:team-manager] normalizando labels do repo..."

# ─── Labels canônicas ────────────────────────────────────────────────────────
# Formato: "LABEL|COR" — pipe como separador (labels têm ":" internamente)
CANONICAL_LABELS="
area:backend|0075ca
area:frontend|0075ca
area:infra|0075ca
area:db|0075ca
area:docs|0075ca
area:qa|0075ca
area:admin|0075ca
area:billing|0075ca
area:pipeline|0075ca
area:content|0075ca
area:integrations|0075ca
area:distribution|0075ca
status:needs-scope|e4e669
status:ready|e4e669
status:in-progress|e4e669
status:blocked|e4e669
status:needs-review|e4e669
status:qa-approved|e4e669
status:qa-blocked|e4e669
risk:low|d93f0b
risk:high|d93f0b
risk:conflict|d93f0b
risk:migration|d93f0b
risk:auth|d93f0b
"

# ─── Mapeamento explícito de aliases → canônica ───────────────────────────────
# Formato: "ALIAS|CANONICA" — mapeamento determinístico, sem ambiguidade
ALIAS_MAP="
area:backen|area:backend
area:fronten|area:frontend
area:infr|area:infra
area:d|area:db
area:q|area:qa
area:ui|area:frontend
area:auth|area:backend
risk:aut|risk:auth
risk:conflic|risk:conflict
risk:hig|risk:high
risk:lo|risk:low
risk:migratio|risk:migration
risk:medium|risk:low
status:blocke|status:blocked
status:in-progres|status:in-progress
status:needs-revie|status:needs-review
status:needs-scop|status:needs-scope
status:qa-approve|status:qa-approved
status:qa-blocke|status:qa-blocked
status:read|status:ready
status:ready-to-merge|status:qa-approved
"

# 1. Criar labels canônicas ausentes
echo "$CANONICAL_LABELS" | grep -v '^$' | while IFS='|' read LABEL COLOR; do
  EXISTS=$(gh label list --limit 200 --json name \
    -q "[.[] | select(.name == \"$LABEL\")] | length" 2>/dev/null || echo 0)
  if [ "$EXISTS" = "0" ]; then
    gh label create "$LABEL" --color "$COLOR" --force 2>/dev/null
    echo "[worker:team-manager] ✓ label criada: $LABEL"
  fi
done

# 2. Migrar aliases para canônicas e deletar alias
echo "$ALIAS_MAP" | grep -v '^$' | while IFS='|' read ALIAS CANONICAL; do
  EXISTS=$(gh label list --limit 200 --json name \
    -q "[.[] | select(.name == \"$ALIAS\")] | length" 2>/dev/null || echo 0)
  [ "$EXISTS" = "0" ] && continue

  echo "[worker:team-manager] migrando: '$ALIAS' → '$CANONICAL'"

  gh issue list --label "$ALIAS" --state all --limit 200 --json number \
    -q '.[].number' 2>/dev/null | while read N; do
      gh issue edit "$N" --add-label "$CANONICAL" --remove-label "$ALIAS" 2>/dev/null || true
    done

  gh pr list --label "$ALIAS" --state all --limit 200 --json number \
    -q '.[].number' 2>/dev/null | while read N; do
      gh pr edit "$N" --add-label "$CANONICAL" --remove-label "$ALIAS" 2>/dev/null || true
    done

  gh label delete "$ALIAS" --yes 2>/dev/null || true
  echo "[worker:team-manager] ✓ '$ALIAS' migrado e removido"
done

echo "[worker:team-manager] labels normalizadas — ecossistema pronto"
```

---

## Regra fundamental

**O team-manager NÃO executa trabalho técnico.**
Ele lê o estado do GitHub, aplica labels e assignees, e spawna subagentes
**apenas** para classificar issues (triage) e escrever specs.

Ele **nunca** spawna subagente para revisar código, implementar, ou mergear.
Isso é responsabilidade dos workers `qa`, `dev` e `reviewer` rodando em
outras sessões. O team-manager apenas atribui o trabalho via GitHub e aguarda
o próximo ciclo para ver o resultado.

---

## Fase 1 — BUSCAR

```bash
# Estado completo do repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
GH_USER=$(gh api user -q '.login')
echo "[worker:team-manager] lendo estado de $REPO — usuário: $GH_USER"

# Labels fora do ecossistema — ignoradas em todas as queries
# Issues/PRs com essas labels não são tocadas por nenhum worker
IGNORE_LABELS=("jules" "approved-for-jules" "needs-triage" "needs-breakdown" "needs-decomposition" "needs-investigation" "needs-spec" "wontfix" "invalid" "duplicate")

# Função auxiliar: verifica se item tem label ignorada
has_ignored_label() {
  local LABELS_JSON="$1"
  for IL in "${IGNORE_LABELS[@]}"; do
    echo "$LABELS_JSON" | jq -e "[.[] | select(.name == \"$IL\")] | length > 0" > /dev/null 2>&1 && return 0
  done
  return 1
}

# Issues sem label de status (não classificadas) — excluindo labels fora do ecossistema
UNCLASSIFIED=$(gh issue list --state open --json number,title,labels \
  | jq --argjson ignore '["jules","approved-for-jules","needs-triage","needs-breakdown","needs-decomposition","needs-investigation","needs-spec","wontfix","invalid","duplicate"]' \
  '[.[] | select(
    (.labels | map(.name) | any(startswith("status:")) | not) and
    (.labels | map(.name) | any(. as $l | $ignore[] | . == $l) | not)
  )]')

# Issues needs-scope (aguardando spec)
NEEDS_SCOPE=$(gh issue list --state open --label "status:needs-scope" \
  --json number,title --limit 20)

# Issues ready sem assignee (prontas, ninguém pegou)
READY_UNASSIGNED=$(gh issue list --state open --label "status:ready" \
  --json number,title,assignees,labels \
  | jq '[.[] | select(.assignees | length == 0)]')

# Autores externos cujas PRs o ecossistema nunca toca
# (Jules é um agente externo — suas PRs têm ciclo próprio)
IGNORE_AUTHORS='["google-labs-jules[bot]","jules-google[bot]","jules"]'

# PRs abertas sem label de status (precisam de QA) — excluindo PRs de autores externos
PRS_NO_LABEL=$(gh pr list --state open --json number,title,labels,author \
  | jq --argjson ign "$IGNORE_AUTHORS" \
  '[.[] | select(
    (.labels | map(.name) | any(startswith("status:")) | not) and
    (.author.login as $a | $ign | any(. == $a) | not)
  )]')

# PRs needs-review sem assignee de QA — excluindo autores externos
PRS_NEEDS_QA=$(gh pr list --state open --label "status:needs-review" \
  --json number,title,assignees,author \
  | jq --argjson ign "$IGNORE_AUTHORS" \
  '[.[] | select(
    (.assignees | length == 0) and
    (.author.login as $a | $ign | any(. == $a) | not)
  )]')

# PRs qa-approved sem assignee de reviewer
PRS_NEEDS_REVIEW=$(gh pr list --state open --label "status:qa-approved" \
  --json number,title,assignees \
  | jq '[.[] | select(.assignees | length == 0)]')

# PRs qa-blocked (todas — manager avalia cada uma)
PRS_QA_BLOCKED=$(gh pr list --state open --label "status:qa-blocked" \
  --json number,title,assignees,author)

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

Para cada issue em `NEEDS_SCOPE`, verifique antes de spawnar:
```bash
HAS_SPEC=$(gh issue view <N> --json comments \
  -q '[.comments[] | select(.body | contains("## Spec"))] | length')
if [ "$HAS_SPEC" -gt 0 ]; then
  echo "[worker:team-manager] #<N> já tem spec — pulando"
  continue
fi
```

Somente se `HAS_SPEC = 0`:

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
  --assignee "$GH_USER" --json number | jq length)

if [ "$DEV_LOAD" -lt 2 ]; then
  gh issue edit <N> \
    --add-assignee "$GH_USER" \
    --add-label "status:in-progress" \
    --remove-label "status:ready"
  gh issue comment <N> \
    --body "## 👷 Atribuído pelo team-manager\n\n@$GH_USER implementar conforme spec acima."
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

Para cada PR em `PRS_NEEDS_QA` (sem assignee):
```bash
gh pr edit <N> --add-assignee "$GH_USER"
gh pr comment <N> --body "## 🔍 Atribuído para QA pelo team-manager"
echo "[worker:team-manager] ✓ PR #<N> → qa assignado"
```

**PRs com assignee já atribuído**: não faça nada. O worker `qa` irá processar no próprio ciclo.
Nunca spawne subagente para fazer a revisão — isso é exclusivo do worker `qa`.

### Ação 6 — Atribuir reviewer para PRs qa-approved

Para cada PR em `PRS_NEEDS_REVIEW`:
```bash
gh pr edit <N> --add-assignee "$GH_USER"
gh pr comment <N> --body "## ✅ QA aprovado — atribuído para merge pelo team-manager"
echo "[worker:team-manager] ✓ PR #<N> → reviewer assignado"
```

### Ação 7 — Gerenciar PRs qa-blocked

Para cada PR `qa-blocked`:

```bash
AUTHOR=$(gh pr view <N> --json author -q '.author.login')

# Verifica se já tem correção após o comentário de QA
QA_BLOCKED_AT=$(gh pr view <N> --json comments \
  -q '[.comments[] | select(.body | contains("❌ QA bloqueado"))] | last | .createdAt // empty')
LAST_COMMIT_AT=$(gh pr view <N> --json commits \
  -q '.commits | last | .committedDate // empty')

if [ -n "$QA_BLOCKED_AT" ] && [ -n "$LAST_COMMIT_AT" ] && [[ "$LAST_COMMIT_AT" > "$QA_BLOCKED_AT" ]]; then
  # Dev já corrigiu — promover para needs-review e reatribuir QA
  gh pr edit <N> \
    --remove-label "status:qa-blocked" \
    --add-label "status:needs-review" \
    --add-assignee "$GH_USER"
  gh pr comment <N> --body "## 🔍 Reatribuído para QA pelo team-manager\n\nCorreção detectada após bloqueio. Nova revisão de QA iniciada."
  echo "[worker:team-manager] ✓ PR #<N> → correção detectada, reatribuído para QA"
else
  # Dev ainda não corrigiu — atribuir dev se sem assignee, evitar spam de comentário
  ALREADY_NOTIFIED=$(gh pr view <N> --json comments \
    -q '[.comments[] | select(.body | contains("Retornado para correção"))] | length')
  if [ "$ALREADY_NOTIFIED" -eq 0 ]; then
    gh pr edit <N> --add-assignee "$AUTHOR"
    gh pr comment <N> --body "## 🔄 Retornado para correção pelo team-manager\n\n@$AUTHOR veja os comentários de QA acima e corrija."
    echo "[worker:team-manager] ✓ PR #<N> → $AUTHOR notificado para corrigir"
  else
    echo "[worker:team-manager] PR #<N> → aguardando correção de $AUTHOR (já notificado)"
  fi
fi
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
