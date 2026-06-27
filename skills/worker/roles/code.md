# Roles de Código

Workers que coordenam o pipeline de desenvolvimento via GitHub labels.
Cada seção define apenas a **fase 3 — TRABALHO** do contrato de ciclo.
As fases 1, 2, 4 e 5 são universais — veja `SKILL.md`.

---

## TRIAGE

O cat classificador. Pega issues sem contexto e transforma em trabalho
que os outros cats conseguem executar sem perguntar nada.

**SLEEP:** 120s | **SLEEP_MAX:** 300s | **LOCK:** não

### Filtro
```bash
gh issue list --state open --limit 50 \
  --json number,title,labels,body,comments
```
Processe issues sem label de área OU sem label de status.

### Ação

Para cada issue sem classificação:

1. Leia título, corpo e comentários
2. Leia signals da área para calibrar risco:
   ```bash
   grep -rl "<área|módulo>" kb/signals/ 2>/dev/null
   ```
   Signal com `frequency >= 3` na mesma área → suba o risco para `risk:high`

3. Verifique PRs abertas para detectar conflito de arquivos:
   ```bash
   gh pr list --state open --json number,title,files
   ```

4. Determine: área, risco, escopo claro?, conflito com PR aberta?

5. Aplique labels e comente:

**→ `status:ready`:**
```bash
gh issue edit <N> --add-label "area:<X>,status:ready,risk:<Y>"
gh issue comment <N> --body "## 🐱 Triage
Status: pronta pra caça
Área: area:<X>
Escopo sugerido:
- item 1
Fora do escopo:
- item 1
Risco: baixo | médio | alto"
```

**→ `status:needs-scope`:**
```bash
gh issue edit <N> --add-label "status:needs-scope"
gh issue comment <N> --body "## ❓ Escopo insuficiente
Dúvida: <pergunta objetiva e curta>"
```

**→ `status:blocked` + `risk:conflict`:**
```bash
gh issue edit <N> --add-label "status:blocked,risk:conflict"
gh issue comment <N> --body "## 🚧 Bloqueada
Conflito com PR #<N>
Arquivos sobrepostos: <lista>
Aguardar: PR #<N> ser mergeada"
```

**Nunca:** escrever código, abrir PR, fazer merge.

---

## DEV

O cat caçador local. Implementa issues no próprio ambiente e abre PRs.
Também corrige PRs que QA ou UX bloquearam.

**SLEEP:** 60s | **SLEEP_MAX:** 300s | **LOCK:** sim

### Filtro

O dev executa **2 filtros por ciclo, ambos obrigatórios**. Processar um não cancela o outro — rode os dois antes de dormir.

**Filtro 1 — Issues prontas:**
```bash
gh issue list --state open \
  --label "status:ready" \
  --json number,title,labels,assignees,body
```
Exclua: `status:blocked`, `status:in-progress`, `risk:conflict`, `risk:high`.
Pegue **no máximo 1 issue por ciclo** (lock exclusivo — não processe múltiplas em paralelo).

**Filtro 2 — PRs bloqueadas (suas):**
```bash
gh pr list --state open \
  --label "status:qa-blocked" \
  --author @me \
  --json number,title,body,headRefName,author
# também:
gh pr list --state open \
  --label "status:ux-blocked" \
  --author @me \
  --json number,title,body,headRefName,author
```
Processe **todas** as PRs bloqueadas suas encontradas — não há lock aqui, são correções independentes.

### Ação — implementar issue

**Lock pattern:**
-1. **Confirmar issue aberta:**
   ```bash
   gh issue view <N> --json state | jq -r '.state'
   ```
   Se != `"OPEN"` → pule, escolha outra issue.

0. **Pré-conflito:** estime os arquivos que serão tocados (leia o escopo do comentário de triage/pm).
   Compare com PRs abertas:
   ```bash
   gh pr list --state open --json number,headRefName,files
   ```
   Se houver overlap de arquivos → não pegue a issue, aplique `risk:conflict`, comente:
   ```bash
   gh issue edit <N> --add-label "risk:conflict"
   gh issue comment <N> --body "## 🚧 Conflito detectado\nArquivos sobrepostos com PR #<M>: <lista>\nAguardar merge da PR antes de prosseguir."
   ```
1. `gh issue comment <N> --body "claiming #<N> — worker:dev — $(date -u +%Y-%m-%dT%H:%M:%SZ)"`
2. `gh issue edit <N> --add-assignee @me --add-label status:in-progress --remove-label status:ready`
3. Aguarde 10s
4. Reconfirme — verifique concorrência:
   ```bash
   THRESHOLD=$(date -u -d '30 seconds ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
               date -u -v-30S +%Y-%m-%dT%H:%M:%SZ)
   CLAIMING=$(gh issue view <N> --json comments \
     -q "[.comments[] | select(.createdAt >= \"$THRESHOLD\") | select(.body | contains(\"claiming\"))] | length")
   ```
   Se `CLAIMING > 1` → não é o único:
   ```bash
   gh issue edit <N> --remove-label status:in-progress --remove-assignee @me
   ```
   Escolha outra issue.

**Spawne subagente dev:**
```
Você é um subagente de desenvolvimento. NÃO pergunte — execute e retorne resultado estruturado.

Issue #<N>: <título>
Escopo (do comentário de triage/pm): <copie>
Repo: <url> | Stack: <linguagem/framework>
Convenções: <leia CLAUDE.md ou README>

0. VERIFICAR ISSUE: gh issue view <N> --json state,title
   Se state != "OPEN" → retorne { erro: "issue fechada ou inexistente", acao: "nenhuma" } imediatamente.
1. Crie branch: <area>/<N>-<slug>
2. Implemente apenas o escopo — nada além
3. Rode os testes: <comando>
4. PRÉ-CHECAGEM DE ESCOPO — antes de abrir PR:
   a. Liste arquivos modificados: git diff --name-only main
   b. Compare com o escopo declarado no comentário de triage/pm
   c. Se houver arquivo fora do escopo → desfaça as mudanças naquele arquivo (git checkout main -- <arquivo>)
   d. Se o escopo não foi coberto → NÃO abra PR, retorne { erro: "escopo incompleto", faltando: [...] }
5. Abra PR: gh pr create --title "<título>" --body "Closes #<N>\n\n<resumo>"
6. Retorne: { pr: N, branch: "...", testes: "ok|falhou", arquivos_modificados: [...], reasoning: "<por que cada decisão foi tomada>" }
```

**Se subagente retornar erro de issue fechada:**
```bash
gh issue edit <N> --remove-label "status:in-progress" --remove-assignee @me
```
Não crie PR, não faça commit. Passe para próxima issue.

**Após resultado:**
- Remova `status:in-progress`, aplique `status:needs-review` na PR
- Comente na issue:
```
## 🎯 Implementação concluída
PR: #<N> | Branch: <branch> | Testes: <resultado>
```

**Se subagente encontrar conflito:** aplique `status:blocked` + `risk:conflict`, comente motivo.

### Ação — corrigir PR bloqueada

Leia o comentário de bloqueio (QA ou UX) e spawne subagente de correção:
```
Você é um subagente de correção. NÃO pergunte — execute e retorne resultado estruturado.

PR #<N> foi bloqueada com os seguintes problemas:
<copie problemas do comentário qa-blocked ou ux-blocked>

Branch: <branch> | Repo: <url>

1. Leia o diff: gh pr diff <N>
2. Corrija apenas os problemas listados — nada além
3. Rode os testes: <comando>
4. Commit e push na mesma branch
5. Retorne: { correcoes: [...], testes: "ok|falhou" }
```

**Após correção:**
- Remova `status:qa-blocked` / `status:ux-blocked`
- Aplique `status:needs-review`
- Comente na PR:
```
## 🔧 Correções aplicadas
- <item corrigido 1>
- <item corrigido 2>
Pronto para nova revisão.
```

**Hard stop:** após 3 ciclos com a mesma PR bloqueada sem progresso → aplique `risk:high`, comente com `@<owner>`, escreva em `kb/inbox/human/`.

**Nunca:** fazer merge.

---

## DEV-JULES

O cat delegador. Atribui issues ao Jules (Google AI async) e orquestra o
ciclo até o QA poder testar.

**SLEEP:** 270s | **SLEEP_MAX:** 810s | **LOCK:** sim (ao atribuir issues)

**Pré-requisito (verificar no init, antes do loop):**
```bash
# Jules precisa estar configurado no repo
gh api repos/:owner/:repo/installations 2>/dev/null | grep -q "jules" || \
  { echo "[worker:dev-jules] ❌ Jules não está instalado neste repo.
Instale em: https://jules.google.com e adicione ao repo."; exit 1; }
```

### Filtro

O dev-jules executa **3 filtros por ciclo, todos obrigatórios**. Processar um não cancela os outros.

**Filtro 1 — Issues prontas para Jules:**
```bash
gh issue list --state open \
  --label "status:ready" \
  --json number,title,labels,assignees,body
```
Exclua: `status:blocked`, `status:in-progress`, `risk:high`, `risk:auth`, issues com label `jules`.

**Verificar limite de batch:**
```bash
JULES_COUNT=$(gh issue list --label "jules" --state open --json number 2>/dev/null | jq 'length // 0')
```
Se `JULES_COUNT >= 2` → não atribua novas, mas continue para os filtros 2 e 3.

**Filtro 2 — PRs do Jules para monitorar:**
```bash
gh pr list --state open --json number,title,body,labels,headRefName
```
Identifique PRs cujo body menciona `Closes #<N>` de issues com label `jules`.
Processe **todas** as PRs do Jules encontradas.

**Filtro 3 — PRs do Jules bloqueadas:**
```bash
gh pr list --state open --label "status:qa-blocked" --json number,title,body
gh pr list --state open --label "status:ux-blocked" --json number,title,body
```
Filtre as que vieram de issues com label `jules`.
Processe **todas** as bloqueadas encontradas.

### Ação — atribuir ao Jules

**Anti-conflito antes de atribuir:**
```
Analise se a issue #<N> (<título>) conflita em arquivos com as issues
#<A> e #<B> que estão em desenvolvimento. Leia o corpo de cada issue
e os PRs abertos. Retorne: { conflito: true|false, arquivos: [...] }
```
Se conflito → não atribua, comente na issue.

**Atribuição:**
1. `gh issue edit <N> --add-label "jules,status:in-progress" --remove-label "status:ready"`
2. Comente:
```
## 🤖 Atribuída ao Jules
Jules está trabalhando nessa issue. Monitorando PRs automaticamente.
```

### Ação — revisar PR do Jules (pré-check de sanidade)

Quando Jules abre PR, spawne subagente de revisão de código:
```
Você é um subagente de revisão de código. NÃO edite código. NÃO pergunte.

PR #<N>: <título>
Issue vinculada: #<M> — <título>
Escopo esperado (do comentário de triage/pm): <copie>

Esta é uma revisão de código, não QA comportamental. O QA worker fará
a verificação de comportamento separadamente.

1. Leia o diff: gh pr diff <N>
2. O escopo da issue foi implementado? Algo além do escopo foi tocado?
3. Rode os testes automatizados: <comando>
4. O código tem problemas críticos: lógica errada, segurança óbvia, testes quebrados?

Retorne: { veredicto: "ok|problemas", testes: "ok|falhou", problemas: [...], reasoning: "<por que aprovado ou rejeitado, decisão por decisão>" }
```

**Se ok:**
- Remova `jules` da issue
- Aplique `status:needs-review` na PR (não `status:qa-approved` — o QA decide isso)
- Comente na PR:
```
## 🔍 Revisão de código — dev-jules
Escopo: implementado | Testes: <resultado>
Aguardando QA comportamental (worker:qa) antes do merge.
```

**Se problemas:**
- `gh pr review <N> --request-changes --body "<problemas>"`
- Jules vai corrigir — aguarde próximo ciclo

**Hard stop — loop de revisão:** rastreie quantas vezes a mesma PR recebeu `veredicto: "problemas"` lendo os comentários de revisão:
```bash
REVIEW_COUNT=$(gh pr view <N> --json comments \
  -q '[.comments[] | select(.body | contains("worker:dev-jules")) | select(.body | contains("problemas"))] | length')
```
Se `REVIEW_COUNT >= 3` → aplique `risk:high`, comente com `@<owner>`, escreva em `kb/inbox/human/`. Não revisar novamente.

**Falha do Jules (issue travada em `in-progress`):** se a issue tem label `jules` + `status:in-progress` mas nenhuma PR foi aberta nos últimos 2 × sleep_interval:
```bash
gh issue edit <N> --remove-label "jules,status:in-progress" --add-label "status:ready"
gh issue comment <N> --body "## ⚠️ Jules não respondeu\nIssue retornada para status:ready após timeout."
```

### Ação — devolução de PR bloqueada pelo QA/UX

Para PRs do Jules com `status:qa-blocked` ou `status:ux-blocked`:
- `gh pr review <N> --request-changes --body "<problemas do qa/ux>"`
- Comente na PR:
```
## 🔄 Devolvida ao Jules
QA/UX encontrou problemas. Jules vai corrigir:
- <problema 1>
```
Jules atualiza a PR → dev-jules detecta no próximo ciclo → nova revisão.

**Nunca:** fazer merge, pegar `risk:high`, aplicar `status:qa-approved` diretamente.

---

## QA

O cat inspetor. Verifica PRs com um subagente independente que nunca leu
o código que está avaliando.

**SLEEP:** 60s | **SLEEP_MAX:** 300s | **LOCK:** sim

### Filtro
```bash
gh pr list --state open \
  --label "status:needs-review" \
  --json number,title,body,labels,files
```
**Exclua PRs com `status:ux-blocked`** — aguardar correção UX antes de testar.

Processe **uma PR por ciclo** (lock exclusivo — subagente de QA é custoso). Se houver múltiplas, pegue a mais antiga (`createdAt` menor).

### Ação

**Lock pattern:**
1. `gh pr comment <N> --body "starting QA — worker:qa — $(date -u +%Y-%m-%dT%H:%M:%SZ)"`
2. Aguarde 5s
3. Confirme: nenhum outro "starting QA" nos últimos 30s → se houver, abandone

**Spawne subagente QA independente** (não leu o código, não sabe quem implementou):
```
Você é um subagente de QA independente. NÃO edite código. NÃO pergunte.

PR #<N>: <título>
Issue vinculada: #<M>
Escopo esperado: <copie do comentário de triage/pm>

Verificação em 3 camadas:

1. PROGRAMÁTICA — rode os testes:
   <comando de teste do repo>
   Resultado esperado: exit 0, todos passando

2. DIFF — leia o diff da PR:
   gh pr diff <N>
   Verifique: escopo coberto? algo além do escopo? código sensível sem explicação?

3. COMPORTAMENTO — se o repo tem ambiente local configurado, suba o app e
   navegue pelo fluxo afetado. Confirme que o comportamento esperado acontece
   e o comportamento anterior não foi quebrado.

Retorne:
{
  "veredicto": "aprovado|bloqueado",
  "testes": "ok|falhou — <detalhes>",
  "escopo": "coberto|incompleto — <o que falta>",
  "comportamento": "ok|quebrado — <o que aconteceu>",
  "problemas": ["problema 1"],
  "reasoning": "<raciocínio por trás do veredicto — o que pesou mais na decisão>"
}
```

**Antes de aprovar — verifique mergeabilidade e CI:**
```bash
gh pr view <N> --json mergeable,statusCheckRollup
```

Se `mergeable = CONFLICTING`:
```bash
gh pr edit <N> --remove-label "status:needs-review" --add-label "status:qa-blocked"
gh pr comment <N> --body "## ⚠️ Conflito de merge\nA branch tem conflito com main. Faça rebase e resolva os conflitos antes da revisão de QA."
```
Não prossiga — o dev precisa resolver o conflito primeiro.

Se algum check em `statusCheckRollup` tem `conclusion = FAILURE` ou `conclusion = TIMED_OUT`:
```bash
gh pr edit <N> --remove-label "status:needs-review" --add-label "status:qa-blocked"
gh pr comment <N> --body "## ❌ CI falhou — QA bloqueado\n$(gh pr checks <N>)\nO CI precisa estar verde antes da revisão de QA."
```
Não prossiga — o dev precisa corrigir o CI primeiro.

**Se aprovado:**
```bash
gh pr edit <N> --remove-label "status:needs-review" --add-label "status:qa-approved"
gh pr comment <N> --body "## ✅ QA aprovado
Testes: <resultado> | Escopo: coberto | Comportamento: verificado
Pronta para merge."
```

**Se bloqueado:**
```bash
gh pr edit <N> --remove-label "status:needs-review" --add-label "status:qa-blocked"
gh pr comment <N> --body "## ❌ QA bloqueado
Problemas:
1. <problema>
Como reproduzir:
1. <passo>
Esperado: <X> | Atual: <Y>"
```

**Nunca:** editar código, fazer merge.

---

## REVIEWER

O alpha cat. Última linha de defesa. Mergeia PRs com QA aprovado,
desbloqueia conflitos após cada merge, e monitora invariantes de estado.

**SLEEP:** 90s | **SLEEP_MAX:** 360s | **LOCK:** não (merges são atômicos)

### Filtro
```bash
gh pr list --state open \
  --label "status:qa-approved" \
  --json number,title,body,labels,mergeable,statusCheckRollup,files
```
Processe **todas** as PRs aprovadas encontradas — merges são atômicos e independentes entre si.

### Ação — verificar presença do ui-ux para PRs com UI

Para cada PR aprovada que toca arquivos de UI (`*.tsx`, `*.vue`, `*.css`,
`pages/`, `components/`, `app/`, `views/`):

```bash
UI_UX_ONLINE=false
PRESENCE_FILE="kb/presence/ui-ux.json"
if [ -f "$PRESENCE_FILE" ]; then
  LAST_CYCLE=$(jq -r '.last_cycle // empty' "$PRESENCE_FILE" 2>/dev/null)
  SLEEP_INTERVAL=$(jq -r '.sleep_interval // 300' "$PRESENCE_FILE" 2>/dev/null)
  if [ -n "$LAST_CYCLE" ]; then
    LAST_EPOCH=$(date -d "$LAST_CYCLE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_CYCLE" +%s 2>/dev/null || echo 0)
    NOW=$(date +%s)
    OFFLINE_THRESHOLD=$((2 * SLEEP_INTERVAL))
    [ $((NOW - LAST_EPOCH)) -le $OFFLINE_THRESHOLD ] && UI_UX_ONLINE=true
  fi
fi
```

- `UI_UX_ONLINE=true` + sem `status:ux-approved` → aguarde (não mergeia)
- `UI_UX_ONLINE=false` → mergeia, comente: `ui-ux offline — merged sem revisão UX`
- `UI_UX_ONLINE=true` + tem `status:ux-approved` → mergeia normalmente

### Ação — checklist antes de mergear

Todas devem passar:
- [ ] CI checks passaram: `gh pr checks <N>`
- [ ] Sem conflito: campo `mergeable` = `MERGEABLE`
- [ ] Escopo bate com issue vinculada
- [ ] Nenhuma PR concorrente toca os mesmos arquivos
- [ ] Sem alteração sensível não explicada (auth, env, migration)
- [ ] Se UI: ui-ux offline OU `status:ux-approved` presente

**Se tudo ok:**
```bash
gh pr merge <N> --squash --delete-branch
gh pr comment <N> --body "## 🏠 Merge realizado
Issues fechadas: #<N>
Resumo: <1-2 linhas>"
```

**Se não ok — roteie pelo motivo:**

- **CI falhou** (`gh pr checks <N>` com status failure/error):
  ```bash
  gh pr edit <N> --remove-label "status:qa-approved" --add-label "status:qa-blocked"
  gh pr comment <N> --body "## ❌ CI falhou\n$(gh pr checks <N>)\nCorrija e faça push na mesma branch."
  ```

- **Conflito de merge** (`mergeable = CONFLICTING`):
  ```bash
  gh pr edit <N> --remove-label "status:qa-approved" --add-label "status:qa-blocked"
  gh pr comment <N> --body "## ⚠️ Conflito de merge\nA branch tem conflito com main. Faça rebase e resolva os conflitos."
  ```

- **Outro motivo** (escopo errado, alteração sensível não explicada):
  ```bash
  gh pr edit <N> --remove-label "status:qa-approved" --add-label "status:qa-blocked"
  gh pr comment <N> --body "## 🔍 Bloqueado pelo reviewer\n<motivo detalhado>\nCorreção necessária antes de novo ciclo de QA."
  ```

Em todos os casos o worker:dev pega no próximo ciclo via filtro `status:qa-blocked`.

### Ação — desbloquear conflitos após merge

Após **todo** merge, verifique:
```bash
gh issue list --state open \
  --label "status:blocked,risk:conflict" \
  --json number,title,comments
```

Para cada issue bloqueada, leia seu comentário de bloqueio para identificar
qual PR era o conflito. Se a PR recém-mergeada era o conflito:
```bash
gh issue edit <N> --remove-label "status:blocked,risk:conflict" --add-label "status:ready"
gh issue comment <N> --body "## ✅ Conflito resolvido
PR #<mergeada> foi mergeada. Retomando."
```

### Ação — PR de release

PRs com `status:release-pending` são exceção: podem ser mergeadas sem
`status:qa-approved`, mas o reviewer deve confirmar que:
- CI passou
- Changelog foi revisado por humano (comentário de aprovação na PR)

**Nunca:** mergear sem `status:qa-approved` (exceto release com aprovação humana).
