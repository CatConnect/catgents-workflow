# role: scout (analista)

**Cadência:** 6 horas
**Responsabilidade:** varredura passiva do repo — detecta padrões, cria issues para o team-manager decidir.

O scout nunca atribui trabalho. Só observa e reporta via issues.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:scout] iniciando varredura — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
```

---

## Fase 2 — EXECUTAR

Execute todas as varreduras. Cada uma é independente.

### Varredura 1 — Branches órfãs

```bash
echo "[worker:scout] varredura 1/5 — branches órfãs"

git fetch --prune
BRANCHES=$(git branch -r | grep -v HEAD | sed 's|origin/||')
COUNT=0

echo "$BRANCHES" | while read BRANCH; do
  PR_STATE=$(gh pr list --state all --head "$BRANCH" --json state -q '.[0].state // "NONE"' 2>/dev/null)
  DAYS_OLD=$(( ($(date +%s) - $(git log -1 --format="%ct" "origin/$BRANCH" 2>/dev/null || echo $(date +%s))) / 86400 ))

  THRESHOLD=30
  [ "$PR_STATE" = "MERGED" ] || [ "$PR_STATE" = "CLOSED" ] && THRESHOLD=7

  if [ "$DAYS_OLD" -ge "$THRESHOLD" ] && [ "$PR_STATE" != "OPEN" ]; then
    git push origin --delete "$BRANCH" 2>/dev/null && COUNT=$((COUNT+1))
    echo "[worker:scout] branch deletada: $BRANCH (${DAYS_OLD}d, PR: $PR_STATE)"
  fi
done

echo "[worker:scout] varredura 1/5 — branches órfãs: concluída"
```

### Varredura 2 — Issues in-progress com PR mergeada (não fecharam)

```bash
echo "[worker:scout] varredura 2/5 — issues presas"

gh issue list --state open --label "status:in-progress" --json number,title | jq -r '.[].number' | while read N; do
  MERGED=$(gh pr list --state merged \
    --search "Closes #$N OR Fixes #$N OR Resolves #$N" \
    --json number -q '.[0].number // empty' 2>/dev/null)
  if [ -n "$MERGED" ]; then
    gh issue close "$N" --comment "## ✅ Fechada pelo scout\n\nPR #$MERGED foi mergeada mas a issue não fechou automaticamente."
    echo "[worker:scout] ✓ issue #$N fechada — PR #$MERGED já mergeada"
  fi
done

echo "[worker:scout] varredura 2/5 — issues presas: concluída"
```

### Varredura 3 — Issues estagnadas

```bash
echo "[worker:scout] varredura 3/5 — issues estagnadas"

# Issues ready ou in-progress sem atividade há 37+ dias
gh issue list --state open --json number,title,updatedAt,labels | \
  jq -r '.[] | select(
    (.labels | map(.name) | any(. == "status:ready" or . == "status:in-progress")) and
    ((now - (.updatedAt | fromdateiso8601)) > 37 * 86400)
  ) | .number' | while read N; do
    EXISTING=$(gh issue list --state open --search "estagnada #$N" --json number -q '.[0].number // empty')
    if [ -z "$EXISTING" ]; then
      gh issue comment "$N" --body "## ⏰ Alerta de estagnação — scout\n\nEsta issue está sem atividade há mais de 37 dias. O team-manager irá avaliar."
      echo "[worker:scout] ✓ #$N — alerta de estagnação enviado"
    fi
  done

echo "[worker:scout] varredura 3/5 — issues estagnadas: concluída"
```

### Varredura 4 — Backlog de descoberta

```bash
echo "[worker:scout] varredura 4/5 — backlog needs-scope"

NEEDS_SCOPE_COUNT=$(gh issue list --state open --label "status:needs-scope" --json number | jq length)
echo "[worker:scout] issues needs-scope: $NEEDS_SCOPE_COUNT"

if [ "$NEEDS_SCOPE_COUNT" -ge 10 ]; then
  # Verifica se já existe alerta recente (menos de 7 dias)
  RECENT=$(gh issue list --state open \
    --search "backlog needs-scope scout" \
    --json number,createdAt \
    -q '[.[] | select((now - (.createdAt | fromdateiso8601)) < 7 * 86400)] | length')

  if [ "$RECENT" -eq 0 ]; then
    gh issue create \
      --title "⚠️ Backlog de needs-scope alto: $NEEDS_SCOPE_COUNT issues aguardando spec" \
      --body "## Alerta do scout\n\nHá $NEEDS_SCOPE_COUNT issues com status:needs-scope sem spec escrita.\nO team-manager deve priorizar a escrita de specs para desbloquear o pipeline." \
      --label "status:needs-scope,area:docs"
    echo "[worker:scout] ✓ issue de alerta criada — backlog: $NEEDS_SCOPE_COUNT"
  fi
fi

echo "[worker:scout] varredura 4/5 — backlog: concluída"
```

### Varredura 5 — PRs sem issue vinculada abertas há mais de 3 dias

```bash
echo "[worker:scout] varredura 5/5 — PRs soltas"

gh pr list --state open --json number,title,createdAt,body | \
  jq -r '.[] | select(
    (.body | test("Closes #|Fixes #|Resolves #") | not) and
    ((now - (.createdAt | fromdateiso8601)) > 3 * 86400)
  ) | .number' | while read N; do
    ALREADY=$(gh pr view "$N" --json comments \
      -q '[.comments[] | select(.body | contains("sem issue vinculada"))] | length')
    if [ "$ALREADY" -eq 0 ]; then
      gh pr comment "$N" --body "## ⚠️ PR sem issue vinculada — scout\n\nEsta PR não referencia nenhuma issue via 'Closes #N'. Adicione no body para fechar a issue automaticamente no merge."
      echo "[worker:scout] ✓ PR #$N — aviso enviado"
    fi
  done

echo "[worker:scout] varredura 5/5 — PRs soltas: concluída"
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:scout] varredura completa — $(date -u +%Y-%m-%dT%H:%M:%SZ) | próximo: 6h"
```
