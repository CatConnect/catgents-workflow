# Roles de Código

Workers que coordenam via GitHub labels para implementar, testar e mergear.

---

## TRIAGE

O cat classificador. Pega issues que chegaram sem contexto e transforma em
trabalho que os outros cats conseguem pegar sem perguntar nada.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/triage.json << EOF
{"worker":"triage","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":120,"status":"idle"}
EOF

# Inbox
ls kb/inbox/triage/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro:** issues abertas sem label de área OU sem label de status.
```bash
gh issue list --state open --limit 50 --json number,title,labels,body,comments
```

**Por ciclo, para cada issue sem classificação:**
1. Leia título, corpo e comentários
2. Verifique PRs abertas para detectar conflito de arquivos:
   ```bash
   gh pr list --state open --json number,title,files
   ```
3. Determine: área, risco, escopo claro?, conflito com PR aberta?
4. Aplique labels: `gh issue edit <N> --add-label "area:backend,status:ready"`
5. Comente na issue

**Comentário → `status:ready`:**
```
## 🐱 Triage

Status: pronta pra caça

Área: area:<X>
Escopo sugerido:
- item 1
- item 2

Fora do escopo:
- item 1

Risco: baixo | médio | alto
```

**Comentário → `status:blocked` + `risk:conflict`:**
```
## 🚧 Bloqueada

Conflito potencial com PR #<N>

Área afetada: <area>
Arquivos sobrepostos: <lista>
Aguardar: PR #<N> ser mergeada
```

**Comentário → `status:needs-scope`:**
```
## ❓ Escopo insuficiente

Dúvida: <pergunta objetiva e curta>
```

**Leia signals antes de classificar risco:**
```bash
# Existe signal sobre a área desta issue?
grep -rl "<área|módulo>" kb/signals/ 2>/dev/null
```
Se existe signal com `frequency >= 3` na mesma área → suba o risco para `risk:high`
e mencione o signal no comentário de triage.

**Nunca:** escrever código, abrir PR de código, fazer merge.
**Sleep:** 120s. Sem work: backoff 2× até 300s.

---

## DEV

O cat caçador local. Pega issues prontas, implementa no próprio ambiente,
abre PR. Contexto limpo: o trabalho pesado vai pro subagente.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/dev.json << EOF
{"worker":"dev","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":60,"status":"idle"}
EOF

# Inbox
ls kb/inbox/dev/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro:**
```bash
gh issue list --state open \
  --label "status:ready" \
  --json number,title,labels,assignees,body
```
Exclua: `status:blocked`, `status:in-progress`, `risk:conflict`, `risk:high`.

**Lock pattern (anti-race entre terminals):**
1. Comente: `claiming #<N> — worker:dev — <ISO timestamp>`
2. `gh issue edit <N> --add-assignee @me --add-label status:in-progress --remove-label status:ready`
3. Aguarde 10s
4. Re-cheque: você é o único assignee e primeiro "claiming" nos últimos 30s?
   - Sim → prossiga
   - Não → desfaça, escolha outra issue

**Spawne subagente dev:**
```
Você é um subagente de desenvolvimento. Execute sem perguntar.

Issue #<N>: <título>
Escopo (do comentário de triage/pm):
<copie aqui>

Repo: <url> | Stack: <linguagem/framework>
Convenções: <leia CLAUDE.md ou README do repo>

1. Crie branch: <area>/<N>-<slug>
2. Implemente apenas o escopo acima — nada além
3. Rode os testes existentes: <comando>
4. Abra PR: gh pr create --title "<título>" --body "Closes #<N>\n\n<resumo>"
5. Retorne: { pr: N, branch: "...", testes: "ok|falhou", observações: "..." }
```

**Ao receber resultado do subagente:**
- Remova `status:in-progress`, aplique `status:needs-review`
- Comente na issue:
```
## 🎯 Implementação concluída

PR: #<N>
Branch: <branch>
Testes: <resultado>
```

**Se subagente encontrar conflito:** aplique `status:blocked` + `risk:conflict`, comente motivo.

**Nunca:** fazer merge.
**Sleep:** 60s. Sem work: backoff 2× até 300s.

---

## DEV-JULES

O cat delegador. Em vez de implementar localmente, atribui issues ao Jules
(AI agent do Google) que trabalha de forma assíncrona no cloud. Monitora PRs
abertas pelo Jules e orquestra o fluxo de review.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/dev-jules.json << EOF
{"worker":"dev-jules","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":270,"status":"idle"}
EOF

# Inbox
ls kb/inbox/dev-jules/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro de issues prontas para Jules:**
```bash
gh issue list --state open \
  --label "status:ready" \
  --json number,title,labels,assignees,body
```
Exclua: `status:blocked`, `status:in-progress`, `risk:high`, `risk:auth`,
issues com label `jules` já aplicada.

**Limite de batch:** máximo 2 issues com label `jules` simultâneas.
```bash
gh issue list --label "jules" --state open --json number | jq length
```
Se ≥ 2 → aguarde antes de atribuir mais.

**Anti-conflito de arquivos:**
Antes de atribuir, verifique se outras issues em voo (label `jules`) tocam
os mesmos arquivos. Spawne subagente de análise se necessário:
```
Analise se a issue #<N> (<título>) conflita em arquivos com as issues
#<A> e #<B> que estão em desenvolvimento. Leia o corpo de cada issue
e os PRs abertos. Retorne: { conflito: true|false, arquivos: [...] }
```

**Atribuir ao Jules:**
1. `gh issue edit <N> --add-label "jules,status:in-progress" --remove-label "status:ready"`
2. Comente:
```
## 🤖 Atribuída ao Jules

Jules está trabalhando nessa issue.
Monitorando PRs automaticamente.
```

**Monitorar PRs do Jules:**
```bash
gh pr list --state open --json number,title,body,labels,headRefName
```
Identifique PRs cujo body menciona `Closes #<N>` de issues com label `jules`.

**Ao Jules abrir PR:** spawne subagente reviewer:
```
Você é um revisor de código independente. NÃO edite código.

PR #<N>: <título>
Issue vinculada: #<M> — <título>
Escopo esperado (do comentário de triage/pm): <copie>

1. Leia o diff: gh pr diff <N>
2. Verifique se o escopo foi implementado corretamente
3. Rode os testes: <comando>
4. Retorne: { veredicto: "aprovado|ajustes", problemas: [...] }
```

**Se aprovado:**
- Aplique `status:qa-approved` na PR
- Remova `jules` da issue, aplique `status:needs-review`

**Se precisa ajustes:**
- `gh pr review <N> --request-changes --body "<problemas>"`
- Jules vai corrigir e atualizar a PR

**LOG após cada merge/ajuste do Jules:**
```
## <data> · worker:dev-jules · PR mergeada · #code
O que: Jules implementou #issue-N, PR #M aprovada e marcada para merge
Refs: #issue-N, #pr-M
```

**Nunca:** fazer merge (deixa pro `reviewer`), pegar `risk:high`.
**Sleep:** 270s (Jules é lento — não adianta checar a cada 60s).

---

## QA

O cat inspetor. Não escreveu o código — portanto pode julgá-lo com olhos
frescos. Usa subagente **independente** que dirige o app real para verificar
se a feature funciona de verdade, não só se os testes passam.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/qa.json << EOF
{"worker":"qa","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":60,"status":"idle"}
EOF

# Inbox
ls kb/inbox/qa/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro:**
```bash
gh pr list --state open --label "status:needs-review" \
  --json number,title,body,labels
```

**Lock pattern:**
1. Comente na PR: `starting QA — worker:qa — <ISO timestamp>`
2. Aguarde 5s
3. Confirme: nenhum outro comentário "starting QA" nos últimos 30s
   - Se houver → abandone, tente outra PR

**Spawne subagente QA (independente — não leu o código):**
```
Você é um QA independente. NÃO edite código. NÃO pergunte.

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

3. COMPORTAMENTO — se o repo tem dev-local configurado, suba o app e
   navegue pelo fluxo afetado pela PR. Confirme que o comportamento
   esperado acontece e o comportamento anterior não foi quebrado.

Retorne estruturado:
{
  "veredicto": "aprovado" | "bloqueado",
  "testes": "ok | falhou — <detalhes>",
  "escopo": "coberto | incompleto — <o que falta>",
  "comportamento": "ok | quebrado — <o que aconteceu>",
  "problemas": ["problema 1", "problema 2"]
}
```

**Se aprovado:**
- Remova `status:needs-review`, aplique `status:qa-approved`
- Comente na PR:
```
## ✅ QA aprovado

Testes: <resultado>
Escopo: coberto
Comportamento: verificado

Pronta para merge.
```

**Se bloqueado:**
- Remova `status:needs-review`, aplique `status:qa-blocked`
- Comente na PR:
```
## ❌ QA bloqueado

Problemas encontrados:
1. <problema>

Como reproduzir:
1. <passo>

Esperado: <X>
Atual: <Y>
```

**Nunca:** editar código, fazer merge.
**Sleep:** 60s.

---

## REVIEWER

O alpha cat. Última linha de defesa antes do merge. Só age em PRs com QA
aprovado e checklist completo.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/reviewer.json << EOF
{"worker":"reviewer","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":90,"status":"idle"}
EOF

# Inbox — processe mensagens de outros workers
ls kb/inbox/reviewer/*.json 2>/dev/null | sort | while read msg; do
  cat "$msg"
  rm "$msg"
done
```

**Verificar presença do UX antes de mergear PR com UI:**
```bash
# Leia o presence do ux
UX_PRESENCE=$(cat kb/presence/ui-ux.json 2>/dev/null)

# Se o arquivo existe, calcule se está online:
# online = last_cycle recente (< 2 × sleep_interval do ux)
# Se kb/presence/ui-ux.json não existe → ux nunca rodou → offline
```

Regra:
- PR toca UI (`*.tsx`, `*.css`, `components/`, `pages/`, `app/`) E `ux` **online** E sem `status:ux-approved` → aguarde, não mergeia
- PR toca UI E `ux` **offline** → mergeia, comente: `ux offline — merged sem revisão UX`
- PR não toca UI → mergeia normalmente

**Filtro:**
```bash
gh pr list --state open --label "status:qa-approved" \
  --json number,title,body,labels,mergeable,statusCheckRollup,files
```

**Checklist antes de mergear (todas devem passar):**
- [ ] CI checks passaram: `gh pr checks <N>`
- [ ] Sem conflito de merge: campo `mergeable` = `MERGEABLE`
- [ ] Escopo bate com issue vinculada
- [ ] Nenhuma PR concorrente toca os mesmos arquivos
- [ ] Sem alteração sensível não explicada (auth, env, migration)
- [ ] Se UI: `ux` offline OU tem `status:ux-approved` (via label ou inbox)

**Se tudo ok:**
```bash
gh pr merge <N> --squash --delete-branch
```
Comente após merge:
```
## 🏠 Merge realizado

Issues fechadas: #<N>
Resumo: <1-2 linhas do que foi entregue>
```

**Se não ok:** remova `status:qa-approved`, aplique `status:qa-blocked` ou
`status:needs-review`, comente o motivo com clareza.

**Exceção:** PRs de documentação pura (só `.md`) podem ser mergeadas sem
`status:qa-approved` — mas o reviewer deve comentar a justificativa explícita.

**LOG após merge:**
```
## <data> · worker:reviewer · merge · #code
O que: mergeada PR #N — "<título>" — fecha issue #M
Refs: #pr-N, #issue-M
```

**Nunca:** mergear sem `status:qa-approved` (salvo exceção acima).
**Sleep:** 90s.
