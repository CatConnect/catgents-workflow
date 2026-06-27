# Roles de Operações

Workers que mantêm o território limpo — corrigem estados inválidos, fecham
o que foi abandonado e empacotam o que foi entregue.
Cada seção define apenas a **fase 3 — TRABALHO** do contrato de ciclo.
As fases 1, 2, 4 e 5 são universais — veja `SKILL.md`.

---

## STALE

O cat limpador e guardião de invariantes. Detecta e corrige estados inválidos
do sistema, fecha issues/PRs abandonadas e mantém o board saudável.

**SLEEP:** 86400s | **SLEEP_MAX:** 86400s | **LOCK:** não

### Filtro + Ação

O stale opera em **6 varreduras por ciclo, todas obrigatórias**.

**ANTES DE DORMIR**, confirme no log do terminal que todas foram executadas:
```
[worker:stale] varredura 1/6 — estados inválidos: <N achados>
[worker:stale] varredura 2/6 — timeouts por estado: <N achados>
[worker:stale] varredura 3/6 — issues abandonadas: <N achados>
[worker:stale] varredura 4/6 — consolidação de signals: <N consolidados>
[worker:stale] varredura 5/6 — PRs abandonadas: <N achados>
[worker:stale] varredura 6/6 — branches órfãs: <N deletadas>
```
Se uma linha estiver faltando → a varredura não rodou. Volte e execute-a.
Encontrar trabalho em uma varredura **não encerra o ciclo**.

---

**Varredura 1 — Estados inválidos (invariantes do sistema)**

Detecta e corrige estados que nunca deveriam existir:

**`status:in-progress` com worker morto:**
```bash
gh issue list --state open --label "status:in-progress" \
  --json number,title,assignees,updatedAt
```
Para cada issue `in-progress`, verifique o presence do assignee:
```bash
ASSIGNEE=$(gh issue view <N> --json assignees -q '.assignees[0].login // empty')
PRESENCE_FILE="kb/presence/${ASSIGNEE}.json"
WORKER_DEAD=true
if [ -n "$ASSIGNEE" ] && [ -f "$PRESENCE_FILE" ]; then
  LAST_CYCLE=$(jq -r '.last_cycle // empty' "$PRESENCE_FILE" 2>/dev/null)
  SLEEP_INTERVAL=$(jq -r '.sleep_interval // 300' "$PRESENCE_FILE" 2>/dev/null)
  if [ -n "$LAST_CYCLE" ]; then
    LAST_EPOCH=$(date -d "$LAST_CYCLE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_CYCLE" +%s 2>/dev/null || echo 0)
    NOW=$(date +%s)
    [ $((NOW - LAST_EPOCH)) -le $((3 * SLEEP_INTERVAL)) ] && WORKER_DEAD=false
  fi
fi
```
Se `WORKER_DEAD=true` → remova `status:in-progress`, aplique `status:ready`, comente:
```
## 🔄 Estado corrigido pelo stale
Worker assignado não responde. Issue retornada para status:ready.
```

**`status:in-progress` com PR já mergeada (issue não fechou automaticamente):**
```bash
gh issue list --state open --label "status:in-progress" \
  --json number,title,body,comments
```
Para cada issue `in-progress`, verifique se alguma PR mergeada a menciona:
```bash
# Busca PRs mergeadas que referenciam esta issue
MERGED_PR=$(gh pr list --state merged \
  --search "Closes #<N> OR Fixes #<N> OR Resolves #<N>" \
  --json number,state -q '.[0].number // empty' 2>/dev/null)
if [ -n "$MERGED_PR" ]; then
  gh issue close <N> --comment "## ✅ Fechada pelo stale
PR #$MERGED_PR foi mergeada mas esta issue não foi fechada automaticamente.
Referência 'Closes #<N>' na PR não funcionou corretamente."
  echo "[worker:stale] issue #<N> fechada — PR #$MERGED_PR já mergeada"
fi
```

**`status:blocked` + `risk:conflict` com PR já mergeada:**
```bash
gh issue list --state open --label "status:blocked,risk:conflict" \
  --json number,title,comments
```
Para cada issue, leia o comentário de bloqueio para identificar a PR conflitante.
Se a PR já foi mergeada (`gh pr view <N> --json state` = `MERGED`):
```bash
gh issue edit <N> --remove-label "status:blocked,risk:conflict" --add-label "status:ready"
gh issue comment <N> --body "## ✅ Conflito resolvido pelo stale
PR conflitante já foi mergeada. Retomando."
```

**`status:blocked` + `risk:high` sem atividade humana por 48h+:**
```bash
gh issue list --state open --label "status:blocked,risk:high" \
  --json number,title,updatedAt,comments
```
Se última atividade > 48h → re-notifique:
```bash
gh issue comment <N> --body "## ⚠️ Aguardando liberação humana
Esta issue está marcada risk:high há mais de 48h sem resposta.
Precisa de decisão humana para prosseguir."

MSG="kb/inbox/human/msg-$(date +%s)-stale.json"
cat > "${MSG}.tmp" << EOF
{"from":"stale","to":"human","type":"alert","payload":{"message":"Issue #<N> aguarda liberação risk:high há 48h+","issue":<N>},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

**`status:qa-blocked` sem atividade por 24h+:**
```bash
gh pr list --state open --label "status:qa-blocked" \
  --json number,title,updatedAt
```
Se última atividade > 24h → notifique:
```bash
gh pr comment <N> --body "## ⏰ PR bloqueada há 24h+
Esta PR está com status:qa-blocked sem correção. Dev deve investigar."
```

---

**Varredura 2 — Issues com timeout por estado**

| Estado | Threshold | Ação |
|--------|-----------|------|
| `UNCLASSIFIED` (sem labels) | 2h | comente alertando que triage deve processar |
| `needs-scope` | 48h | comente alertando que pm deve processar |
| `qa-approved` sem merge | 8h | comente no PR alertando o reviewer |
| `needs-review` sem QA | 4h | comente na PR alertando que QA deve processar |

Para cada estado com timeout expirado, apenas comente — não altere labels.

**Backlog de discovery crescendo (threshold: 10+ issues `needs-scope`):**
```bash
DISCOVERY_BACKLOG=$(gh issue list --state open --label "status:needs-scope" \
  --json number -q 'length' 2>/dev/null)
if [ "$DISCOVERY_BACKLOG" -ge 10 ]; then
  # Só alerta se não alertou nos últimos 7 dias
  LAST_ALERT=$(grep "discovery-backlog-alert" kb/LOG.md 2>/dev/null | tail -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  DAYS_SINCE_ALERT=999
  if [ -n "$LAST_ALERT" ]; then
    LAST_EPOCH=$(date -d "$LAST_ALERT" +%s 2>/dev/null || echo 0)
    DAYS_SINCE_ALERT=$(( ( $(date +%s) - LAST_EPOCH ) / 86400 ))
  fi
  if [ "$DAYS_SINCE_ALERT" -ge 7 ]; then
    MSG="kb/inbox/human/msg-$(date +%s)-stale.json"
    cat > "${MSG}.tmp" << EOF
{"from":"stale","to":"human","type":"alert","payload":{"message":"Backlog de discovery acumulou $DISCOVERY_BACKLOG issues needs-scope sem processamento pelo pm","count":$DISCOVERY_BACKLOG},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
    mv "${MSG}.tmp" "${MSG}"
    echo "## $(date +%Y-%m-%d) · worker:stale · discovery-backlog-alert · #backlog
O que: $DISCOVERY_BACKLOG issues needs-scope acumuladas sem processamento" >> kb/LOG.md
  fi
fi
```

---

**Varredura 3 — Issues abandonadas (30d+)**

```bash
gh issue list --state open \
  --json number,title,labels,updatedAt,assignees,comments \
  --limit 100
```
Calcule: `(agora - updatedAt) > 30 dias` → candidata a stale.

Antes de agir, verifique:
- Tem `risk:high`? → nunca feche, notifique humano
- É issue de tracking/roadmap? → ignore
- Tem assignee ativo (presence válido)? → comente pedindo status, não feche

**Primeira passagem — aviso (dias 30-36):**
Antes de avisar, verifique se já avisou neste ciclo consultando o LOG:
```bash
grep "stale-aviso #<N>" kb/LOG.md 2>/dev/null && continue
```
Se não avisou ainda:
```bash
gh issue comment <N> --body "## 😴 Issue inativa
Sem atividade há 30+ dias. Se ainda é relevante, atualize com contexto.
Será fechada em 7 dias automaticamente.
*worker:stale*"

# Registre no LOG para não avisar de novo no próximo ciclo
echo "## $(date +%Y-%m-%d) · worker:stale · stale-aviso #<N> · #stale
O que: Issue #<N> avisada sobre fechamento em 7 dias
Refs: #<N>" >> kb/LOG.md
```
Não adicione nenhum label — `status:blocked` tem semântica de conflito/risco e confunde outros workers.

**Segunda passagem — fechar (37d+ sem atividade):**
```bash
gh issue close <N> --comment "Fechada por inatividade (37+ dias).
Reabra se ainda for relevante." --reason "not planned"
```

---

**Varredura 4 — Consolidação de signals (memória semântica)**

Rode a cada 7 ciclos (uma vez por semana dado SLEEP=86400s). Spawne subagente:
```
Você é um subagente de consolidação de memória. NÃO pergunte — execute e retorne resultado estruturado.

Leia todos os signals em kb/signals/*.md.
Para cada grupo de signals com as mesmas tags[] E frequency >= 3:

1. São sobre o mesmo padrão estrutural? (não apenas o mesmo arquivo)
2. Se sim → proponha um signal consolidado que capture o padrão geral
3. Liste os slugs originais que seriam substituídos

Retorne: [{ slug_consolidado: "...", titulo: "...", tags: [...], frequency_total: N, slugs_originais: [...] }]
Máximo 3 consolidações por ciclo.
```

Para cada consolidação proposta:
```bash
# Crie o signal consolidado
cat > kb/signals/<slug_consolidado>.md << EOF
---
kind: signal
title: "<título consolidado>"
frequency: <frequency_total>
last_seen: $(date +%Y-%m-%d)
status: open
tags: [<tags>]
consolidated_from: [<slugs_originais>]
---
## Observação
<padrão geral identificado>
## Evidência
Consolidado de: <slugs_originais>
## Timeline
- $(date +%Y-%m-%d): consolidado pelo worker:stale
EOF

# Archive os originais (não delete — mantém histórico)
for slug in <slugs_originais>; do
  sed -i 's/^status: open/status: archived/' "kb/signals/${slug}.md"
done
```

---

**Varredura 5 — PRs abandonadas (14d+)**

```bash
gh pr list --state open \
  --json number,title,labels,updatedAt,isDraft \
  --limit 50
```
PRs abertas há mais de 14 dias sem review → comente pedindo status.

PRs abertas há mais de 14 dias sem review → comente pedindo status.

PRs abertas há mais de 14 dias sem review → comente pedindo status.

**Nunca fechar PR** sem comentar antes e aguardar 7 dias.
**Nunca fechar** issues com `risk:high` ou `status:in-progress` com assignee ativo.

---

**Varredura 6 — Branches órfãs**

Liste todas as branches remotas exceto `main`/`master` e branches de PRs abertas:
```bash
# Branches remotas
git fetch --prune
ALL_BRANCHES=$(git branch -r --format='%(refname:short)' | sed 's|origin/||' | grep -v '^main$\|^master$')

# Branches com PR aberta — não toque
OPEN_PR_BRANCHES=$(gh pr list --state open --json headRefName -q '.[].headRefName')

# Branches candidatas = ALL_BRANCHES - OPEN_PR_BRANCHES
for BRANCH in $ALL_BRANCHES; do
  echo "$OPEN_PR_BRANCHES" | grep -qx "$BRANCH" && continue

  # Data do último commit na branch
  LAST_COMMIT=$(git log -1 --format="%ci" "origin/$BRANCH" 2>/dev/null)
  LAST_EPOCH=$(date -d "$LAST_COMMIT" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S %z" "$LAST_COMMIT" +%s 2>/dev/null || echo 0)
  DAYS_OLD=$(( ( $(date +%s) - LAST_EPOCH ) / 86400 ))

  # Verifique o estado da PR associada
  PR_STATE=$(gh pr list --state all --head "$BRANCH" --json state -q '.[0].state // "NONE"')

  # Thresholds diferenciados por estado:
  # - PR MERGED ou CLOSED → delete após 7 dias (branch já cumpriu seu papel)
  # - PR NONE (branch órfã sem PR) → delete após 30 dias
  THRESHOLD=30
  [ "$PR_STATE" = "MERGED" ] || [ "$PR_STATE" = "CLOSED" ] && THRESHOLD=7

  if [ $DAYS_OLD -ge $THRESHOLD ]; then
    git push origin --delete "$BRANCH"
    echo "## $(date +%Y-%m-%d) · worker:stale · branch-deletada · #cleanup
O que: Branch $BRANCH deletada (${DAYS_OLD}d, PR: $PR_STATE, threshold: ${THRESHOLD}d)
Refs: branch/$BRANCH" >> kb/LOG.md
  fi
done
```

**Nunca deletar:** `main`, `master`, branches com PR aberta.
**Thresholds:** PR MERGED/CLOSED → 7 dias | branch sem PR → 30 dias.

---

## RELEASE

O cat entregador. Detecta quando há PRs suficientes para um release, empacota
o trabalho e publica após aprovação humana.

**SLEEP:** 3600s (verificação de threshold) | **SLEEP_MONITOR:** 300s (monitorando PR de release) | **LOCK:** não

### Filtro

**Modo normal — verificar threshold:**
```bash
# Última tag — com fallback para primeiro release
LAST_RELEASE=$(gh release list --limit 1 --json tagName,publishedAt 2>/dev/null)
if [ -z "$LAST_RELEASE" ] || [ "$LAST_RELEASE" = "[]" ]; then
  LAST_DATE="1970-01-01T00:00:00Z"
else
  LAST_DATE=$(echo "$LAST_RELEASE" | jq -r '.[0].publishedAt // "1970-01-01T00:00:00Z"')
fi

# PRs mergeadas desde então
PR_COUNT=$(gh pr list --state merged \
  --search "merged:>$LAST_DATE" \
  --json number 2>/dev/null | jq 'length // 0')

# Dias desde o último release
LAST_EPOCH=$(date -d "$LAST_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_DATE" +%s 2>/dev/null || echo 0)
DAYS_SINCE=$(( ( $(date +%s) - LAST_EPOCH ) / 86400 ))
```

Dispara se **qualquer** condição for verdadeira:
- `PR_COUNT >= 5` — threshold de PRs atingido
- `DAYS_SINCE >= 14` — 2 semanas sem release (mesmo com poucas PRs)

Se nenhuma → dorme (modo normal, 3600s).

**Modo monitor — PR de release já criada:**
```bash
gh pr list --state open --label "status:release-pending" \
  --json number,title,state,mergedAt
```
Se existe PR com `status:release-pending` → entre em modo monitor (sleep 300s).

### Ação — Criar release

**Passo 1 — Spawne subagente changelog:**
```
Você é um subagente de release. NÃO pergunte — execute e retorne resultado estruturado.

Gere um changelog para o repo <url>.

PRs mergeadas desde o último release (<tag anterior>):
<lista: número, título, corpo>

Agrupe por categoria:
- ✨ Novas funcionalidades
- 🐛 Correções
- 🔒 Segurança
- 🏗️ Infraestrutura
- 📚 Documentação

Formato: "- <o que mudou para o usuário> (#<PR>)"
Foco no impacto, não no detalhe técnico.

Determine também o tipo de bump semver:
- MAJOR: breaking change?
- MINOR: feature nova?
- PATCH: só fixes/ajustes?

Retorne: { changelog: "...", bump: "major|minor|patch", versao: "<nova versão>" }
```

**Passo 2 — Criar PR de release:**
```bash
git checkout -b release/<versão>
# Atualize version nos arquivos do projeto (package.json, pyproject.toml, etc.)
git commit -m "chore: release <versão>"
git push origin release/<versão>

gh pr create \
  --title "🚀 Release <versão>" \
  --body "## Release <versão>
<changelog gerado>
---
### Checklist de release
- [ ] Changelog revisado
- [ ] Versão bumped corretamente
- [ ] Testes passando
- [ ] Deploy validado após merge" \
  --label "area:infra,status:release-pending"
```

**Após criar PR → entre em modo monitor (sleep 300s).**

### Ação — Modo monitor (aguardando merge da PR de release)

A cada ciclo de 300s, verifique se a PR de release foi mergeada:
```bash
gh pr view <N-release> --json state,mergedAt -q '.state'
```

**Se ainda aberta** → verifique timeout de 72h:
```bash
PR_CREATED=$(gh pr view <N-release> --json createdAt -q '.createdAt')
PR_EPOCH=$(date -d "$PR_CREATED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PR_CREATED" +%s 2>/dev/null || echo 0)
HOURS_OPEN=$(( ( $(date +%s) - PR_EPOCH ) / 3600 ))
if [ $HOURS_OPEN -ge 72 ]; then
  gh pr comment <N-release> --body "⏰ PR de release aberta há ${HOURS_OPEN}h sem merge. @<owner> decisão necessária."
  # Volta ao modo normal — tenta novamente no próximo ciclo
fi
```

**Se mergeada** → execute o release:
```bash
gh release create <versão> \
  --title "Release <versão>" \
  --notes "<changelog>" \
  --latest

gh pr comment <N-release> --body "## 🎉 Release <versão> publicado
Tag criada e release publicado no GitHub."
```
Após publicar → volte ao modo normal (sleep 3600s).

**Nunca:** fazer merge da PR de release (sempre humano ou reviewer com aprovação explícita).
