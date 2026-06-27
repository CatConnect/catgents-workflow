# role: reviewer (executor)

**Cadência:** 10 minutos
**Responsabilidade:** mergear PRs assignadas com qa-approved.

O reviewer nunca escolhe PR. Só mergeia o que está assignado a ele.
Não analisa código — confia no veredicto do QA.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:reviewer] buscando PRs assignadas para merge..."

MY_PRS=$(gh pr list --state open \
  --assignee @me \
  --label "status:qa-approved" \
  --json number,title,body,headRefName,labels,statusCheckRollup)

TOTAL=$(echo "$MY_PRS" | jq length)
echo "[worker:reviewer] PRs para mergear: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  echo "[worker:reviewer] 😴 nada assignado — cochilando"
  exit 0
fi
```

---

## Fase 2 — EXECUTAR

Para cada PR em `MY_PRS`:

```bash
echo "[worker:reviewer] → mergeando PR #<N> — <título>"
```

**Verificações antes do merge:**
```bash
# 1. CI passando?
CI_STATUS=$(gh pr view <N> --json statusCheckRollup \
  -q '[.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")] | length')

if [ "$CI_STATUS" -gt 0 ]; then
  gh pr edit <N> \
    --remove-label "status:qa-approved" \
    --add-label "status:qa-blocked" \
    --remove-assignee @me
  gh pr comment <N> \
    --body "## ⚠️ Merge bloqueado — CI falhando\n\nCI falhou após QA aprovação. PR retornada para qa-blocked.\nTeam-manager assignará dev para corrigir."
  echo "[worker:reviewer] ✗ PR #<N> — CI falhando, retornada para qa-blocked (assignee removido)"
  continue
fi

# 2. Conflitos?
MERGEABLE=$(gh pr view <N> --json mergeable -q '.mergeable')
if [ "$MERGEABLE" != "MERGEABLE" ]; then
  gh pr comment <N> \
    --body "## ⚠️ Merge bloqueado — conflitos\n\nPR tem conflitos com main. @$(gh pr view <N> --json author -q '.author.login') resolva os conflitos."
  echo "[worker:reviewer] ✗ PR #<N> — conflitos, aguardando resolução"
  continue
fi
```

**Merge:**
```bash
gh pr merge <N> --squash --auto

# --auto enfileira o merge quando CI passar — não mergeia imediatamente.
# Verifica se auto-merge foi habilitado (não se já mergeou).
AUTO_MERGE=$(gh pr view <N> --json autoMergeRequest -q '.autoMergeRequest // empty')

if [ -n "$AUTO_MERGE" ]; then
  echo "[worker:reviewer] ✓ PR #<N> — auto-merge enfileirado, aguardando CI"
  gh pr edit <N> --remove-assignee @me
else
  # Já mergeada imediatamente (sem CI) ou falhou
  PR_STATE=$(gh pr view <N> --json state -q '.state')
  if [ "$PR_STATE" = "MERGED" ]; then
    echo "[worker:reviewer] ✓ PR #<N> mergeada com sucesso"
    gh pr edit <N> --remove-assignee @me 2>/dev/null || true

    # Verifica se issue foi fechada automaticamente
    ISSUE_REF=$(gh pr view <N> --json body -q '.body' | grep -oE '(Closes|Fixes|Resolves) #[0-9]+' | head -1)
    if [ -n "$ISSUE_REF" ]; then
      ISSUE_N=$(echo "$ISSUE_REF" | grep -oE '[0-9]+')
      ISSUE_STATE=$(gh issue view "$ISSUE_N" --json state -q '.state' 2>/dev/null)
      if [ "$ISSUE_STATE" = "OPEN" ]; then
        gh issue close "$ISSUE_N" \
          --comment "## ✅ Fechada pelo reviewer\n\nPR #<N> mergeada. Issue fechada manualmente pois fechamento automático não ocorreu."
        echo "[worker:reviewer] ✓ issue #$ISSUE_N fechada manualmente"
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
```
