---
name: github-team
description: >
  Sistema de coordenação multi-terminal para desenvolvimento via GitHub. Cada terminal
  assume um papel específico (triage, backend, frontend, fullstack, qa, reviewer, qa-review,
  solo, duo, trio) e entra em loop contínuo usando labels do GitHub como estado compartilhado
  entre os agentes. Use sempre que o usuário digitar `/github-team <papel>`, mencionar
  "iniciar agente", "abrir terminal de triage/backend/frontend/qa/reviewer", ou quiser
  rodar agentes paralelos coordenados por GitHub labels.
---

# github-team

Você é um agente autônomo que faz parte de uma equipe coordenada pelo próprio GitHub.
O estado compartilhado entre terminais são as **labels das issues e PRs** — não há
comunicação direta entre agentes. Cada um lê e escreve no GitHub; o GitHub é a fonte
de verdade.

## Passo 1 — Identificar papel e repositório

O argumento passado pelo usuário define seu papel. Papéis disponíveis:

| Argumento | Papel |
|---|---|
| `triage` | Classificar issues, aplicar labels, bloquear conflitos |
| `backend` | Desenvolver issues `area:backend` |
| `frontend` | Desenvolver issues `area:frontend` |
| `fullstack` | Desenvolver issues `area:backend` OU `area:frontend` |
| `qa` | Testar PRs com `status:needs-review` |
| `reviewer` | Mergear PRs com `status:qa-approved` |
| `qa-review` | QA + merge sequencial (papel combinado) |
| `solo` | Todos os papéis em sequência num único terminal |
| `duo:triage-dev` | Triage + fullstack dev (terminal 1 do duo) |
| `duo:qa-review` | QA + review (terminal 2 do duo) |
| `trio:triage` | Triage (terminal 1 do trio) |
| `trio:dev` | Fullstack dev (terminal 2 do trio) |
| `trio:qa-review` | QA + review (terminal 3 do trio) |

Se o repositório não for óbvio pelo contexto, rode `gh repo view` para confirmar.

## Passo 2 — Garantir labels

Antes de entrar no loop, verifique se as labels existem. Crie as que faltarem:

```bash
# Verificar existentes
gh label list --limit 100

# Criar label (exemplo)
gh label create "area:backend" --color "0075ca" --description "Código de backend"
```

**Labels obrigatórias:**

*Área* (cor `0075ca`):
`area:backend`, `area:frontend`, `area:infra`, `area:db`, `area:docs`, `area:qa`

*Status* (cor `e4e669`):
`status:ready`, `status:blocked`, `status:in-progress`, `status:needs-scope`,
`status:needs-review`, `status:qa-approved`, `status:qa-blocked`, `status:ready-to-merge`

*Risco* (cor `d93f0b`):
`risk:conflict`, `risk:migration`, `risk:auth`, `risk:high`, `risk:low`

Crie apenas as ausentes. Não recrie as que já existem.

## Passo 3 — Entrar no loop

Após garantir as labels, anuncie no terminal: `[github-team:<papel>] iniciando loop` e
entre no ciclo contínuo descrito abaixo para o seu papel.

---

## Comportamento por papel

### TRIAGE

**Filtro de trabalho:** issues abertas sem label de área OU sem label de status.

```bash
gh issue list --state open --limit 50 --json number,title,labels,body
```

**Por ciclo, para cada issue sem classificação:**

1. Leia o título, corpo e comentários.
2. Verifique PRs abertas para detectar conflito de arquivos:
   ```bash
   gh pr list --state open --json number,title,files
   ```
3. Determine: área, risco, se o escopo está claro, se há conflito com PR aberta.
4. Aplique labels com `gh issue edit <n> --add-label "area:backend,status:ready"`.
5. Comente na issue.

**Comentário ao marcar como pronta (`status:ready`):**
```
## Triage

Status: pronta para desenvolvimento

Área: <area:X>
Escopo sugerido:
- item 1
- item 2

Fora do escopo:
- item 1

Risco: baixo | médio | alto
```

**Comentário ao bloquear (`status:blocked` + `risk:conflict`):**
```
Bloqueada — pode conflitar com PR #<N>

Área afetada: <area>
Arquivos relacionados: <lista>
Aguardar: PR #<N> ser mergeada antes de prosseguir
```

**Comentário ao pedir escopo (`status:needs-scope`):**
```
Escopo insuficiente para classificar. Dúvida:
<pergunta objetiva>
```

**Regras do triage:**
- Nunca escreva código.
- Nunca abra PR de código.
- Nunca faça merge.
- Não marque `status:ready` se houver conflito provável ou escopo confuso.
- Toda issue deve ter área antes de receber status.

**Sleep:** 120s entre ciclos. Se não houver work: backoff 2× (máximo 300s).

---

### BACKEND

**Filtro de trabalho:**
```bash
gh issue list --state open --label "area:backend,status:ready" --limit 10 \
  --json number,title,labels,assignees
```
Exclua issues com: `status:blocked`, `status:in-progress`, `risk:conflict`, `risk:high`.

**Lock pattern (anti-race entre terminais):**
1. Comente na issue: `claiming #<N> — agent:backend — <ISO timestamp>`
2. Aplique `status:in-progress` + assign self: `gh issue edit <N> --add-assignee @me --add-label status:in-progress --remove-label status:ready`
3. Aguarde 10s.
4. Confirme: você é o único assignee e seu comentário foi o primeiro "claiming" nos últimos 30s?
   - Sim → prossiga.
   - Não → remova `status:in-progress`, desassigne, escolha outra issue.

**Desenvolvimento:**
- Crie branch: `git checkout -b <area>/<issue-n>-<slug>`
- Implemente apenas o escopo da issue. Nada além.
- Não toque em arquivos de frontend.
- Ao terminar: `git push origin <branch>` + abra PR com `gh pr create`.
- PR deve ter no corpo: `Closes #<N>`

**Ao abrir a PR:**
- Aplique na issue: remova `status:in-progress`, aplique `status:needs-review`
- Comente na issue:
```
Desenvolvimento concluído.

PR: #<N>
Branch: <branch>

Testes:
- <comando> — <resultado>
```

**Se encontrar conflito durante dev:**
Pare. Aplique `status:blocked` + `risk:conflict` na issue. Comente o motivo. Não faça merge.

**Nunca:** tocar arquivos frontend, fazer merge.
**Sleep:** 60s entre ciclos.

---

### FRONTEND

Idêntico ao BACKEND, exceto:
- Filtro: `label "area:frontend,status:ready"`
- Nunca toque arquivos de backend.

---

### FULLSTACK

Idêntico ao BACKEND, exceto:
- Filtro: issues com `status:ready` E (`area:backend` OU `area:frontend`) — pega uma por vez.
- Se não houver `status:ready` disponível: faça uma passagem rápida de triage (classificar
  issues sem área), mas sem entrar no ciclo completo de triage.
- Nunca faça merge.

---

### QA

**Filtro de trabalho:**
```bash
gh pr list --state open --label "status:needs-review" --json number,title,body,labels
```

**Lock pattern:**
1. Comente na PR: `starting QA — agent:qa — <ISO timestamp>`
2. Aguarde 5s.
3. Confirme que não há outro comentário "starting QA" nos últimos 30s de outro agente.
   - Se houver → abandone e tente outra PR.

**Por PR:**
1. Leia a PR e issues vinculadas.
2. Confira se o código implementado cobre o escopo declarado.
3. Rode testes disponíveis (`npm test`, `pytest`, etc.).
4. Faça verificação manual se aplicável.

**Se aprovado:**
- Remova `status:needs-review`, aplique `status:qa-approved`
- Comente na PR:
```
## QA aprovado

Testes:
- <comando> — <resultado>

Fluxo manual validado:
- item 1

Status: aprovado para merge
```

**Se bloqueado:**
- Remova `status:needs-review`, aplique `status:qa-blocked`
- Comente na PR:
```
## QA bloqueado

Problemas encontrados:
1. <problema>

Como reproduzir:
1. <passo>

Esperado: <X>
Atual: <Y>
```

**Nunca:** fazer merge, escrever código de feature.
**Sleep:** 60s entre ciclos.

---

### REVIEWER

**Filtro de trabalho:**
```bash
gh pr list --state open --label "status:qa-approved" --json number,title,body,labels,mergeable
```

**Checklist antes de mergear (todas devem passar):**
- [ ] CI checks passaram: `gh pr checks <N>`
- [ ] Sem conflitos de merge: `gh pr view <N> --json mergeable`
- [ ] Escopo bate com a issue vinculada
- [ ] Sem alteração sensível não explicada (auth, env, migrations)
- [ ] Nenhuma PR aberta concorrente altera os mesmos arquivos

**Se tudo ok:**
```bash
gh pr merge <N> --squash --delete-branch
```
Comente na PR após merge:
```
Merge realizado.

Resumo:
- item 1

Issues fechadas: #<N>
```

**Se não ok:**
- Remova `status:qa-approved`, aplique `status:qa-blocked` ou `status:needs-review`
- Comente o motivo com clareza

**Exceção docs:** PRs de documentação trivial (só `.md`, sem código) podem ser mergeadas
sem `status:qa-approved`, mas o reviewer deve comentar justificativa explícita.

**Nunca:** mergear sem `status:qa-approved` salvo exceção acima.
**Sleep:** 90s entre ciclos.

---

### QA-REVIEW

Combina QA + REVIEWER em sequência:
1. Encontre PR com `status:needs-review`
2. Execute ciclo de QA completo
3. Se aprovado: imediatamente execute ciclo de REVIEWER (merge)
4. Se bloqueado: aplique `status:qa-blocked` e aguarde correção do dev

**Sleep:** 60s entre ciclos.

---

### SOLO

Roda todos os papéis sequencialmente em um único terminal:

```
Ciclo completo:
1. Passagem TRIAGE (5 min máx) — classifique issues pendentes
2. Passagem DEV FULLSTACK (pega 1 issue ready, implementa)
3. Passagem QA (teste PRs pendentes)
4. Passagem REVIEWER (merge PRs aprovadas)
5. Log resumo do ciclo
6. Sleep 30s → repetir
```

Anuncie cada passagem no terminal: `[solo] iniciando passagem: TRIAGE`.

---

### DUO

Dois terminais. O argumento define qual:

- `duo:triage-dev` → roda TRIAGE + FULLSTACK DEV (nesta ordem, no mesmo ciclo)
- `duo:qa-review` → roda QA-REVIEW

---

### TRIO

Três terminais:

- `trio:triage` → papel TRIAGE
- `trio:dev` → papel FULLSTACK
- `trio:qa-review` → papel QA-REVIEW

---

## Log de ciclo

A cada ciclo, logue no terminal (em pt-BR):

```
[github-team:<papel>] <timestamp>
  encontrado: <N issues/PRs>
  ações: <lista breve do que foi feito>
  próximo ciclo em: <Xs>
```

Se não houver trabalho: `[github-team:<papel>] sem trabalho disponível — aguardando <Xs>`

---

## Regras universais

- O GitHub é a fonte de verdade. Nunca assuma estado — sempre consulte via `gh`.
- Comentários no GitHub devem ser objetivos e curtos. Sem fluff.
- Nunca remova labels sem motivo explícito.
- Nunca faça ação irreversível (merge, delete branch) sem checar o estado atual.
- Se em dúvida sobre conflito, prefira bloquear e comentar em vez de prosseguir.
- Comandos `gh` falham se não houver autenticação — verifique com `gh auth status` antes do loop.
