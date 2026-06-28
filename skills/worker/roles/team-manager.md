# role: team-manager (orquestrador)

**Cadência:** 5 minutos
**Responsabilidade:** classificar issues, rotear PRs para os workers certos, corrigir estados inválidos.

O team-manager não implementa, não revisa código, não mergeia.
Ele lê o estado do repo, aplica labels e comenta decisões.

---

## Inicialização — Limpar e normalizar labels do repo

Execute **uma única vez por invocação**, antes do BUSCAR.
Remove tudo que não faz parte do ecossistema e migra labels legadas.

```bash
echo "[worker:team-manager] normalizando labels..."

# Labels canônicas do ecossistema — formato: "LABEL|COR"
CANONICAL="
status:backlog|8b949e
status:ready|0075ca
status:in-progress|fbca04
status:blocked|d93f0b
worker:dev|c5def5
worker:qa|c5def5
worker:reviewer|c5def5
priority:high|e99695
priority:low|c2e0c6
"

# 1. Criar labels canônicas ausentes
echo "$CANONICAL" | grep -v '^$' | while IFS='|' read LABEL COLOR; do
  EXISTS=$(gh label list --limit 200 --json name \
    -q "[.[] | select(.name == \"$LABEL\")] | length" 2>/dev/null || echo 0)
  if [ "$EXISTS" = "0" ]; then
    gh label create "$LABEL" --color "$COLOR" --force 2>/dev/null
    echo "[worker:team-manager] ✓ label criada: $LABEL"
  fi
done

# 2. Migrar labels legadas para canônicas — formato: "LABEL_ANTIGA|LABEL_NOVA"
MIGRATIONS="
status:needs-scope|status:backlog
status:qa-approved|worker:reviewer
status:qa-blocked|worker:dev
status:needs-review|worker:qa
area:backend|
area:frontend|
area:infra|
area:db|
area:docs|
area:qa|
area:admin|
area:billing|
area:pipeline|
area:content|
area:integrations|
area:distribution|
area:ui|
area:auth|
risk:low|
risk:high|
risk:conflict|
risk:migration|
risk:auth|
risk:medium|
type:bug|
type:chore|
type:feature|
type:docs|
complexity:simple|
complexity:medium|
complexity:complex|
priority:p0|priority:high
priority:p1|priority:high
priority:p2|priority:low
priority:p3|priority:low
jules|
approved-for-jules|
needs-triage|
needs-breakdown|
needs-decomposition|
needs-investigation|
needs-spec|
ready|
model-b|
epic|
reliability|
billing|
p0|priority:high
p1|priority:high
p2|priority:low
p3|priority:low
"

echo "$MIGRATIONS" | grep -v '^$' | while IFS='|' read OLD NEW; do
  EXISTS=$(gh label list --limit 200 --json name \
    -q "[.[] | select(.name == \"$OLD\")] | length" 2>/dev/null || echo 0)
  [ "$EXISTS" = "0" ] && continue

  if [ -n "$NEW" ]; then
    echo "[worker:team-manager] migrando: '$OLD' → '$NEW'"
    gh issue list --label "$OLD" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh issue edit "$N" --add-label "$NEW" --remove-label "$OLD" 2>/dev/null || true
      done
    gh pr list --label "$OLD" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh pr edit "$N" --add-label "$NEW" --remove-label "$OLD" 2>/dev/null || true
      done
  else
    echo "[worker:team-manager] removendo label sem equivalente: '$OLD'"
    gh issue list --label "$OLD" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh issue edit "$N" --remove-label "$OLD" 2>/dev/null || true
      done
    gh pr list --label "$OLD" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh pr edit "$N" --remove-label "$OLD" 2>/dev/null || true
      done
  fi

  gh label delete "$OLD" --yes 2>/dev/null || true
  echo "[worker:team-manager] ✓ '$OLD' processada"
done

# Migração especial: status:needs-review → status:in-progress + worker:qa
# (needs-review já foi mapeado para worker:qa acima, mas falta o status:in-progress)
gh pr list --label "worker:qa" --state open --json number,labels \
  -q '.[] | select(.labels | map(.name) | any(. == "status:in-progress") | not) | .number' \
  2>/dev/null | while read N; do
    gh pr edit "$N" --add-label "status:in-progress" 2>/dev/null || true
  done

# 3. Deletar qualquer label que não seja canônica
CANONICAL_NAMES=$(echo "$CANONICAL" | grep -v '^$' | cut -d'|' -f1)
gh label list --limit 200 --json name -q '.[].name' 2>/dev/null | while read LABEL; do
  IS_CANONICAL=false
  while IFS= read -r C; do
    [ "$LABEL" = "$C" ] && IS_CANONICAL=true && break
  done <<< "$CANONICAL_NAMES"
  if [ "$IS_CANONICAL" = "false" ]; then
    # Remover de todos os itens antes de deletar
    gh issue list --label "$LABEL" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh issue edit "$N" --remove-label "$LABEL" 2>/dev/null || true
      done
    gh pr list --label "$LABEL" --state all --limit 200 --json number \
      -q '.[].number' 2>/dev/null | while read N; do
        gh pr edit "$N" --remove-label "$LABEL" 2>/dev/null || true
      done
    gh label delete "$LABEL" --yes 2>/dev/null || true
    echo "[worker:team-manager] ✓ label extra removida: $LABEL"
  fi
done

echo "[worker:team-manager] labels normalizadas — ecossistema pronto"
```

---

## Regra fundamental

O team-manager **não executa trabalho técnico**.
Só classifica, roteia e corrige. Spawna subagentes apenas para classificar issues e escrever specs.

---

## Fase 1 — BUSCAR

```bash
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
GH_USER=$(gh api user -q '.login')
echo "[worker:team-manager] lendo estado de $REPO"

# Issues sem status (novas, precisam ser classificadas)
UNCLASSIFIED=$(gh issue list --state open --json number,title,labels \
  | jq '[.[] | select(.labels | map(.name) | any(startswith("status:")) | not)]')

# Issues status:backlog sem spec (precisam de spec)
BACKLOG=$(gh issue list --state open --label "status:backlog" \
  --json number,title,body --limit 20)

# Issues status:ready sem worker:dev (precisam ser atribuídas)
READY=$(gh issue list --state open --label "status:ready" \
  --json number,title,labels \
  | jq '[.[] | select(.labels | map(.name) | any(. == "worker:dev") | not)]')

# PRs sem worker:* (novas, precisam ir para QA)
PRS_NEW=$(gh pr list --state open --json number,title,labels \
  | jq '[.[] | select(.labels | map(.name) | any(startswith("worker:")) | not)]')

# Issues/PRs bloqueadas (status:blocked) — para log
BLOCKED=$(gh issue list --state open --label "status:blocked" --json number,title)

echo "[worker:team-manager] não classificadas: $(echo $UNCLASSIFIED | jq length)"
echo "[worker:team-manager] backlog sem spec: $(echo $BACKLOG | jq length)"
echo "[worker:team-manager] ready sem worker: $(echo $READY | jq length)"
echo "[worker:team-manager] PRs novas: $(echo $PRS_NEW | jq length)"
```

---

## Fase 2 — EXECUTAR

### Ação 1 — Classificar issues novas

Para cada issue em `UNCLASSIFIED`, spawne subagente:

```
Você é um subagente de triage. NÃO pergunte — classifique e retorne JSON.

Issue: #<N> — <título>
Body: <body>
Repo: <url>

Raciocine passo a passo antes de retornar.

A issue tem escopo suficiente para implementar agora?
- Critérios claros, comportamento definido → status:ready
- Escopo vago, decisões pendentes, risco alto → status:backlog

Retorne APENAS:
{
  "reasoning": "...",
  "status": "ready" | "backlog",
  "resumo": "uma linha explicando a decisão"
}
```

Após retorno:
```bash
gh issue edit <N> --add-label "status:<status>"
gh issue comment <N> \
  --body "## 🏷️ Classificado — team-manager\n\n<resumo>\n\nStatus: **status:<status>**"
echo "[worker:team-manager] ✓ #<N> → status:<status>"
```

### Ação 2 — Escrever spec para issues em backlog

Para cada issue em `BACKLOG`:
```bash
HAS_SPEC=$(gh issue view <N> --json comments \
  -q '[.comments[] | select(.body | contains("## Spec"))] | length')
[ "$HAS_SPEC" -gt 0 ] && echo "[worker:team-manager] #<N> já tem spec — pulando" && continue
```

Se sem spec, spawne subagente:
```
Você é um subagente de produto. NÃO pergunte — escreva a spec e retorne JSON.

Issue: #<N> — <título>
Body: <body>
Repo: <url>

Raciocine passo a passo antes de retornar.

Escreva uma spec implementável:
1. Contexto — por que isso importa
2. Critérios de aceitação — checkboxes mensuráveis
3. Escopo — o que NÃO está incluído
4. Esta spec está pronta para dev implementar? (true/false)
5. Se não: o que falta decidir?

Retorne:
{
  "reasoning": "...",
  "spec_markdown": "## Spec\n\n...",
  "pronto": true | false,
  "pendencia": "..." | null
}
```

Após retorno:
```bash
gh issue comment <N> --body "<spec_markdown>"

if [ "$PRONTO" = "true" ]; then
  gh issue edit <N> --remove-label "status:backlog" --add-label "status:ready"
  echo "[worker:team-manager] ✓ #<N> → status:ready (spec escrita)"
else
  gh issue comment <N> --body "## ⚠️ Pendência — team-manager\n\n<pendencia>\n\n@$GH_USER decisão necessária."
  echo "[worker:team-manager] ✓ #<N> → aguardando decisão humana"
fi
```

### Ação 3 — Atribuir worker:dev para issues ready

**Issues in-progress ou com worker:dev já**: não faça nada.

Para cada issue em `READY`:
```bash
# Limitar: máx 2 issues com worker:dev simultâneas
DEV_LOAD=$(gh issue list --state open --label "worker:dev" --json number | jq length)

if [ "$DEV_LOAD" -lt 2 ]; then
  gh issue edit <N> --add-label "worker:dev"
  gh issue comment <N> \
    --body "## 👷 Atribuído para dev — team-manager\n\nImplemente conforme spec acima."
  echo "[worker:team-manager] ✓ #<N> → worker:dev"
else
  echo "[worker:team-manager] dev com $DEV_LOAD issues — aguardando"
fi
```

### Ação 4 — Rotear PRs novas para QA

Para cada PR em `PRS_NEW`:
```bash
gh pr edit <N> --add-label "status:in-progress" --add-label "worker:qa"
gh pr comment <N> --body "## 🔍 Roteado para QA — team-manager"
echo "[worker:team-manager] ✓ PR #<N> → worker:qa"
```

**PRs com worker:qa já**: não faça nada. Worker qa irá processar.
**PRs com worker:reviewer já**: não faça nada. Worker reviewer irá processar.
**PRs com worker:dev já**: não faça nada. Worker dev irá corrigir.

### Ação 5 — Detectar e corrigir estados inválidos

```bash
# Issues status:in-progress sem PR aberta há mais de 2 dias
gh issue list --state open --label "status:in-progress" \
  --json number,title,createdAt,labels | \
  jq -r '.[] | select((now - (.createdAt | fromdateiso8601)) > 2 * 86400) | .number' | \
  while read N; do
    HAS_PR=$(gh pr list --state open \
      --search "Closes #$N OR Fixes #$N OR Resolves #$N" \
      --json number -q 'length' 2>/dev/null || echo 0)
    # Também checar pelo body
    HAS_PR_BODY=$(gh pr list --state open --limit 100 --json number,body \
      -q "[.[] | select(.body | test(\"(Closes|Fixes|Resolves) #$N\"))] | length" 2>/dev/null || echo 0)
    if [ "$HAS_PR" = "0" ] && [ "$HAS_PR_BODY" = "0" ]; then
      ALREADY=$(gh issue view "$N" --json comments \
        -q '[.comments[] | select(.body | contains("sem PR associada"))] | length')
      if [ "$ALREADY" = "0" ]; then
        gh issue comment "$N" \
          --body "## ⚠️ Alerta — team-manager\n\nIssue em status:in-progress há mais de 2 dias sem PR associada.\n\n@$GH_USER verifique o andamento."
        echo "[worker:team-manager] ⚠ #$N — in-progress sem PR (alerta enviado)"
      fi
    fi
  done

# Issues status:in-progress com PR já mergeada (não fechou automaticamente)
gh issue list --state open --label "status:in-progress" --json number,labels \
  -q '.[].number' 2>/dev/null | while read N; do
    MERGED=$(gh pr list --state merged --limit 100 --json number,body \
      -q ".[] | select(.body | test(\"(Closes|Fixes|Resolves) #$N\")) | .number" \
      2>/dev/null | head -1)
    if [ -n "$MERGED" ]; then
      gh issue close "$N" \
        --comment "## ✅ Fechada — team-manager\n\nPR #$MERGED mergeada. Fechamento automático não ocorreu."
      echo "[worker:team-manager] ✓ #$N fechada — PR #$MERGED já mergeada"
    fi
  done
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:team-manager] ciclo concluído — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
```
