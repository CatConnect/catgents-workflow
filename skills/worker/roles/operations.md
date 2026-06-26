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

O stale opera em 4 varreduras por ciclo, nesta ordem:

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
cat kb/presence/<assignee>.json 2>/dev/null
# worker morto = last_cycle não existe OU now - last_cycle > 3 × sleep_interval
```
Se worker morto → remova `status:in-progress`, aplique `status:ready`, comente:
```
## 🔄 Estado corrigido pelo stale
Worker assignado não responde há <tempo>. Issue retornada para status:ready.
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

**Primeira passagem — aviso (7 dias):**
```bash
gh issue comment <N> --body "## 😴 Issue inativa
Sem atividade há 30+ dias. Se ainda é relevante, atualize com contexto.
Será fechada em 7 dias automaticamente.
*worker:stale*"
```
Não adicione nenhum label — `status:blocked` tem semântica de conflito/risco e confunde outros workers.

**Segunda passagem — fechar (37d+ sem atividade):**
```bash
gh issue close <N> --comment "Fechada por inatividade (37+ dias).
Reabra se ainda for relevante." --reason "not planned"
```

---

**Varredura 4 — PRs abandonadas (14d+)**

```bash
gh pr list --state open \
  --json number,title,labels,updatedAt,isDraft \
  --limit 50
```
PRs abertas há mais de 14 dias sem review → comente pedindo status.

**Nunca fechar PR** sem comentar antes e aguardar 7 dias.
**Nunca fechar** issues com `risk:high` ou `status:in-progress` com assignee ativo.

---

## RELEASE

O cat entregador. Detecta quando há PRs suficientes para um release, empacota
o trabalho e publica após aprovação humana.

**SLEEP:** 3600s (verificação de threshold) | **SLEEP_MONITOR:** 300s (monitorando PR de release) | **LOCK:** não

### Filtro

**Modo normal — verificar threshold:**
```bash
# Última tag
LAST_RELEASE=$(gh release list --limit 1 --json tagName,publishedAt)
LAST_DATE=$(echo $LAST_RELEASE | jq -r '.[0].publishedAt')

# PRs mergeadas desde então
PR_COUNT=$(gh pr list --state merged \
  --search "merged:>$LAST_DATE" \
  --json number | jq length)

# Dias desde o último release
DAYS_SINCE=$(( ( $(date +%s) - $(date -d "$LAST_DATE" +%s) ) / 86400 ))
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

**Se ainda aberta** → aguarde (não faça nada).

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
