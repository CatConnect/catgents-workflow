# role: dev (executor)

**Cadência:** 10 minutos
**Responsabilidade:** implementar issues e corrigir PRs com worker:dev.

O dev só trabalha no que tem `worker:dev`. Se não há nada → exit.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:dev] buscando trabalho..."

# Issues para implementar
MY_ISSUES=$(gh issue list --state open \
  --label "worker:dev" \
  --json number,title,body,labels)

# PRs para corrigir (QA bloqueou)
MY_PRS=$(gh pr list --state open \
  --label "worker:dev" \
  --json number,title,body,headRefName)

TOTAL_ISSUES=$(echo "$MY_ISSUES" | jq length)
TOTAL_PRS=$(echo "$MY_PRS" | jq length)

echo "[worker:dev] issues: $TOTAL_ISSUES | PRs para corrigir: $TOTAL_PRS"

if [ "$TOTAL_ISSUES" -eq 0 ] && [ "$TOTAL_PRS" -eq 0 ]; then
  echo "[worker:dev] 😴 nada com worker:dev — saindo"
  exit 0
fi
```

---

## Fase 2 — EXECUTAR

**Prioridade: PRs para corrigir primeiro, issues novas depois.**

### Prioridade 1 — Corrigir PRs bloqueadas pelo QA

Para cada PR em `MY_PRS`:

```bash
echo "[worker:dev] → corrigindo PR #<N>"

# Ler comentário de QA para entender o problema
QA_COMMENT=$(gh pr view <N> --json comments \
  -q '[.comments[] | select(.body | contains("❌ QA bloqueado"))] | last | .body')
```

Spawne subagente de correção:
```
Você é um subagente de dev. NÃO pergunte — corrija e retorne resultado.

PR: #<N> — <título>
Branch: <headRefName>
Repo: <url>
Problema apontado pelo QA:
<QA_COMMENT>

Raciocine passo a passo antes de retornar.

Instruções:
1. git fetch && git checkout <branch> && git pull origin <branch>
2. Leia o código afetado
3. Corrija exatamente os problemas listados — nada mais
4. Rode typecheck e testes se existirem
5. git commit -m "fix: <descrição>" && git push

Retorne:
{
  "reasoning": "...",
  "correcoes": ["...", "..."],
  "testes_passando": true | false,
  "commit": "hash ou null"
}
```

Após retorno:
```bash
# Remove worker:dev, aplica worker:qa para nova revisão
gh pr edit <N> --remove-label "worker:dev" --add-label "worker:qa"
gh pr comment <N> \
  --body "## 🔧 Correções aplicadas — dev\n\n**Corrigido:**\n- <correcoes>\n\nRoteado de volta para QA."
echo "[worker:dev] ✓ PR #<N> — correções pushadas → worker:qa"
```

### Prioridade 2 — Implementar issue (máx 1 por ciclo)

Para a primeira issue em `MY_ISSUES`:

```bash
echo "[worker:dev] → implementando #<N> — <título>"

# Marcar issue como in-progress
gh issue edit <N> --add-label "status:in-progress" --remove-label "status:ready"
```

**Preparação git:**
```bash
git fetch --prune
git checkout main && git pull origin main

BRANCH_EXISTS=$(git branch -r --list "origin/*/<N>-*" | head -1)
if [ -z "$BRANCH_EXISTS" ]; then
  git checkout -b feat/<N>-<slug>
else
  git checkout "${BRANCH_EXISTS#origin/}" && git pull
fi
```

Spawne subagente de implementação:
```
Você é um subagente de dev. NÃO pergunte — implemente e retorne resultado.

Issue: #<N> — <título>
Repo: <url>
Branch: <branch>
Body:
<body>

Raciocine passo a passo antes de retornar.

Instruções:
1. Leia CLAUDE.md ou AGENTS.md para convenções do projeto
2. Implemente exatamente o que a issue pede — nada mais
3. Não toque em auth, billing, migrations sem aprovação explícita na issue
4. Rode typecheck e testes
5. git add <arquivos> && git commit -m "feat: <descrição> (#<N>)" && git push origin <branch>

Retorne:
{
  "reasoning": "...",
  "arquivos_modificados": ["..."],
  "testes_passando": true | false | "sem testes",
  "typecheck": "ok" | "erros_preexistentes" | "erros_novos",
  "commit": "hash",
  "pr_title": "feat: descrição curta",
  "pr_body": "## O que foi feito\n...\n\nCloses #<N>"
}
```

Após retorno — abrir PR:
```bash
gh pr create \
  --title "<pr_title>" \
  --body "<pr_body>" \
  --base main \
  --head <branch>

PR_N=$(gh pr list --head <branch> --json number -q '.[0].number')
gh pr edit "$PR_N" --add-label "status:in-progress" --add-label "worker:qa"

# Remove worker:dev da issue (PR aberta, trabalho do dev terminou)
gh issue edit <N> --remove-label "worker:dev"

gh issue comment <N> \
  --body "## 🚀 Implementado — dev\n\nPR #$PR_N aberta para revisão."
echo "[worker:dev] ✓ #<N> — PR #$PR_N aberta → worker:qa"
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:dev] ciclo concluído — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
```
