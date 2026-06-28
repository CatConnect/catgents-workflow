# role: reviewer (executor)

**Cadência:** 10 minutos
**Responsabilidade:** mergear PRs com worker:reviewer.

O reviewer não analisa código — confia no veredicto do QA.
Só verifica CI e conflitos antes de mergear.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:reviewer] buscando PRs para mergear..."

MY_PRS=$(gh pr list --state open \
  --label "worker:reviewer" \
  --json number,title,body,headRefName,statusCheckRollup,mergeable)

TOTAL=$(echo "$MY_PRS" | jq length)
echo "[worker:reviewer] PRs para mergear: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  echo "[worker:reviewer] 😴 nada com worker:reviewer — saindo"
  exit 0
fi
```

---

## Fase 2 — EXECUTAR

Para cada PR em `MY_PRS`:

```bash
echo "[worker:reviewer] → mergeando PR #<N> — <título>"

# 1. CI passando?
CI_FAILING=$(gh pr view <N> --json statusCheckRollup \
  -q '[.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")] | length')

if [ "$CI_FAILING" -gt 0 ]; then
  gh pr edit <N> --remove-label "worker:reviewer" --add-label "worker:dev"
  gh pr comment <N> \
    --body "## ⚠️ Merge bloqueado — CI falhando\n\nCI falhou após aprovação do QA. Retornado para correção."
  echo "[worker:reviewer] ✗ PR #<N> — CI falhando → worker:dev"
  continue
fi

# 2. Conflitos?
MERGEABLE=$(gh pr view <N> --json mergeable -q '.mergeable')
if [ "$MERGEABLE" != "MERGEABLE" ]; then
  AUTHOR=$(gh pr view <N> --json author -q '.author.login')
  gh pr edit <N> --remove-label "worker:reviewer" --add-label "worker:dev"
  gh pr comment <N> \
    --body "## ⚠️ Merge bloqueado — conflitos\n\nPR tem conflitos com main.\n\nCorrija com: \`git fetch origin && git rebase origin/main\`"
  echo "[worker:reviewer] ✗ PR #<N> — conflito → worker:dev"
  continue
fi

# 3. Mergear
gh pr merge <N> --squash --auto

AUTO_MERGE=$(gh pr view <N> --json autoMergeRequest -q '.autoMergeRequest // empty')

if [ -n "$AUTO_MERGE" ]; then
  gh pr edit <N> --remove-label "worker:reviewer"
  gh pr comment <N> --body "## 🔀 Auto-merge enfileirado — reviewer\n\nAguardando CI para merge final."
  echo "[worker:reviewer] ✓ PR #<N> — auto-merge enfileirado"
else
  PR_STATE=$(gh pr view <N> --json state -q '.state')
  if [ "$PR_STATE" = "MERGED" ]; then
    gh pr comment <N> --body "## ✅ Mergeado — reviewer"
    echo "[worker:reviewer] ✓ PR #<N> mergeada"

    # Fechar issue vinculada se não fechou automaticamente
    ISSUE_N=$(gh pr view <N> --json body -q '.body' \
      | grep -oE '(Closes|Fixes|Resolves) #[0-9]+' | head -1 | grep -oE '[0-9]+')
    if [ -n "$ISSUE_N" ]; then
      STATE=$(gh issue view "$ISSUE_N" --json state -q '.state' 2>/dev/null)
      if [ "$STATE" = "OPEN" ]; then
        gh issue close "$ISSUE_N" \
          --comment "## ✅ Fechada — reviewer\n\nPR #<N> mergeada."
        echo "[worker:reviewer] ✓ issue #$ISSUE_N fechada"
      fi
    fi
  else
    echo "[worker:reviewer] ✗ PR #<N> — merge falhou, estado: $PR_STATE"
  fi
fi
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:reviewer] ciclo concluído — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
```
