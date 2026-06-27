# role: dev (executor)

**Cadência:** 10 minutos
**Responsabilidade:** implementar o que foi assignado pelo team-manager.

O dev nunca escolhe issue. Só trabalha no que está assignado a ele.
Se não há nada assignado → dorme.

---

## Fase 1 — BUSCAR

```bash
echo "[worker:dev] buscando trabalho assignado..."

# Issues assignadas a mim para implementar
MY_ISSUES=$(gh issue list --state open \
  --assignee @me \
  --label "status:in-progress" \
  --json number,title,body,labels)

# PRs assignadas a mim para corrigir (qa-blocked)
MY_BLOCKED_PRS=$(gh pr list --state open \
  --assignee @me \
  --label "status:qa-blocked" \
  --json number,title,body,headRefName)

TOTAL_ISSUES=$(echo "$MY_ISSUES" | jq length)
TOTAL_BLOCKED=$(echo "$MY_BLOCKED_PRS" | jq length)

echo "[worker:dev] issues assignadas: $TOTAL_ISSUES | PRs bloqueadas para corrigir: $TOTAL_BLOCKED"

if [ "$TOTAL_ISSUES" -eq 0 ] && [ "$TOTAL_BLOCKED" -eq 0 ]; then
  echo "[worker:dev] 😴 nada assignado — cochilando"
  exit 0
fi
```

---

## Fase 2 — EXECUTAR

**Prioridade: PRs bloqueadas primeiro, issues novas depois.**

### Prioridade 1 — Corrigir PRs qa-blocked

Para cada PR em `MY_BLOCKED_PRS`:

```bash
echo "[worker:dev] → corrigindo PR #<N> — qa-blocked"

# 1. Ler comentários de QA para entender o problema
QA_COMMENT=$(gh pr view <N> --json comments \
  -q '[.comments[] | select(.body | contains("QA bloqueado") or contains("❌"))] | last | .body')

echo "Problema apontado pelo QA: $QA_COMMENT"
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
3. Corrija exatamente os problemas listados pelo QA — nada mais
4. Rode typecheck e testes se existirem
5. git commit -m "fix: <descrição do que foi corrigido>"
6. git push

Retorne:
{
  "reasoning": "...",
  "correcoes_feitas": ["...", "..."],
  "testes_passando": true | false,
  "commit": "hash ou null"
}
```

Após receber retorno:
```bash
gh pr edit <N> \
  --remove-label "status:qa-blocked" \
  --add-label "status:needs-review"
gh pr comment <N> \
  --body "## 🔧 Correções aplicadas\n\n**O que foi corrigido:**\n$(echo $CORRECOES | sed 's/,/\n- /g')\n\nPR pronta para nova revisão de QA."
echo "[worker:dev] ✓ PR #<N> corrigida → status:needs-review"
```

### Prioridade 2 — Implementar issue assignada

Para cada issue em `MY_ISSUES` (máx 1 por ciclo):

```bash
echo "[worker:dev] → implementando #<N> — <título>"
```

**Preparação git (obrigatório antes de qualquer implementação):**
```bash
git fetch --prune
git checkout main && git pull origin main

# Verifica se branch já existe
BRANCH_EXISTS=$(git branch -r --list "origin/<area>/<N>-*" | head -1)
if [ -z "$BRANCH_EXISTS" ]; then
  git checkout -b <area>/<N>-<slug>
  echo "[worker:dev] branch criada: <area>/<N>-<slug>"
else
  git checkout "${BRANCH_EXISTS#origin/}"
  git pull origin "${BRANCH_EXISTS#origin/}"
  echo "[worker:dev] branch existente: ${BRANCH_EXISTS#origin/}"
fi
```

Spawne subagente de implementação:
```
Você é um subagente de dev. NÃO pergunte — implemente e retorne resultado.

Issue: #<N> — <título>
Repo: <url>
Branch atual: <branch>
Body da issue:
<body>

Stack: <leia do CLAUDE.md ou AGENTS.md do repo>

Raciocine passo a passo antes de retornar.

Instruções:
1. Leia o CLAUDE.md/AGENTS.md para entender convenções
2. Implemente exatamente o que a issue pede — nada mais
3. Siga as convenções do projeto
4. Não toque em auth, billing, migrations sem risk:high explícito na issue
5. Rode typecheck e testes se existirem
6. git add <arquivos relevantes> && git commit -m "<tipo>(<área>): <descrição> (#<N>)"
7. git push origin <branch>

Retorne:
{
  "reasoning": "...",
  "arquivos_modificados": ["..."],
  "testes_passando": true | false | "sem testes",
  "typecheck": "ok" | "erros pré-existentes" | "erros novos",
  "commit": "hash",
  "pr_title": "tipo(área): descrição curta",
  "pr_body": "## Summary\n...\n\nCloses #<N>"
}
```

Após receber retorno — abrir PR:
```bash
gh pr create \
  --title "<pr_title>" \
  --body "<pr_body>" \
  --base main \
  --head <branch>

PR_URL=$(gh pr list --head <branch> --json url -q '.[0].url')
gh pr edit --url "$PR_URL" --add-label "status:needs-review"

echo "[worker:dev] ✓ implementação #<N> — PR aberta: $PR_URL"
```

---

## Fase 3 — REPORTAR

```bash
echo "[worker:dev] ciclo concluído — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```
