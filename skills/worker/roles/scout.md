# role: scout (analista)

**Cadência:** 6 horas
**Responsabilidade:** varredura passiva — detecta problemas e cria issues para o team-manager agir.

O scout nunca aplica labels de worker nem atribui trabalho. Só observa e reporta.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:scout] iniciando varredura — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
```

---

## Fase 2 — EXECUTAR

### Varredura 1 — Branches órfãs

**Requer clone local.** Pula se não houver.

```bash
echo "[worker:scout] varredura 1/4 — branches órfãs"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "[worker:scout] sem clone local — pulando varredura 1"
else
  PROTECTED="main master develop staging production"

  git fetch --prune
  git branch -r | grep -v HEAD | sed 's|origin/||' | while read BRANCH; do
    for P in $PROTECTED; do [ "$BRANCH" = "$P" ] && continue 2; done

    PR_STATE=$(gh pr list --state all --head "$BRANCH" --json state \
      -q '.[0].state // "NONE"' 2>/dev/null)
    DAYS_OLD=$(( ($(date +%s) - $(git log -1 --format="%ct" "origin/$BRANCH" 2>/dev/null || echo $(date +%s))) / 86400 ))

    THRESHOLD=30
    [ "$PR_STATE" = "MERGED" ] || [ "$PR_STATE" = "CLOSED" ] && THRESHOLD=7

    if [ "$DAYS_OLD" -ge "$THRESHOLD" ] && [ "$PR_STATE" != "OPEN" ]; then
      git push origin --delete "$BRANCH" 2>/dev/null
      echo "[worker:scout] ✓ branch deletada: $BRANCH (${DAYS_OLD}d, PR: $PR_STATE)"
    fi
  done
fi

echo "[worker:scout] varredura 1/4 — concluída"
```

### Varredura 2 — Issues estagnadas

```bash
echo "[worker:scout] varredura 2/4 — issues estagnadas"

gh issue list --state open --json number,updatedAt,labels | \
  jq -r '.[] | select(
    (.labels | map(.name) | any(. == "status:ready" or . == "status:in-progress")) and
    ((now - (.updatedAt | fromdateiso8601)) > 37 * 86400)
  ) | .number' | while read N; do
    ALREADY=$(gh issue view "$N" --json comments \
      -q '[.comments[] | select(.body | contains("Alerta de estagnação"))] | length')
    if [ "$ALREADY" = "0" ]; then
      gh issue comment "$N" \
        --body "## ⏰ Alerta de estagnação — scout\n\nSem atividade há mais de 37 dias."
      echo "[worker:scout] ✓ #$N — alerta enviado"
    fi
  done

echo "[worker:scout] varredura 2/4 — concluída"
```

### Varredura 3 — Backlog alto

```bash
echo "[worker:scout] varredura 3/4 — backlog"

COUNT=$(gh issue list --state open --label "status:backlog" --json number | jq length)
echo "[worker:scout] issues em backlog: $COUNT"

if [ "$COUNT" -ge 10 ]; then
  RECENT=$(gh issue list --state open \
    --search "Backlog alto scout" \
    --json createdAt \
    -q '[.[] | select((now - (.createdAt | fromdateiso8601)) < 7 * 86400)] | length')

  if [ "$RECENT" = "0" ]; then
    gh issue create \
      --title "⚠️ Backlog alto: $COUNT issues sem spec" \
      --body "## Alerta — scout\n\nHá $COUNT issues em status:backlog sem spec.\nO team-manager deve priorizar a escrita de specs." \
      --label "status:backlog"
    echo "[worker:scout] ✓ alerta de backlog criado"
  fi
fi

echo "[worker:scout] varredura 3/4 — concluída"
```

### Varredura 4 — PRs sem issue vinculada

```bash
echo "[worker:scout] varredura 4/4 — PRs sem issue"

gh pr list --state open --json number,createdAt,body,author | \
  jq -r '.[] | select(
    (.body | test("Closes #|Fixes #|Resolves #") | not) and
    ((now - (.createdAt | fromdateiso8601)) > 3 * 86400)
  ) | .number' | while read N; do
    ALREADY=$(gh pr view "$N" --json comments \
      -q '[.comments[] | select(.body | contains("sem issue vinculada"))] | length')
    if [ "$ALREADY" = "0" ]; then
      gh pr comment "$N" \
        --body "## ⚠️ PR sem issue vinculada — scout\n\nAdicione 'Closes #N' no body para fechar a issue automaticamente no merge."
      echo "[worker:scout] ✓ PR #$N — aviso enviado"
    fi
  done

echo "[worker:scout] varredura 4/4 — concluída"
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:scout] varredura completa — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
```
