# Roles de Produto

Workers que pensam antes de caçar — transformam ideias vagas em trabalho
concreto e mantêm o backlog ordenado por impacto real.

---

## PM

O cat estrategista. Pega issues sem escopo (`status:needs-scope`) ou com
corpo vago e transforma em specs com critérios de aceitação claros — o
combustível que alimenta o `dev` e o `dev-jules`.

Um issue bem scopado pelo pm elimina perguntas de implementação. O dev
(humano ou Jules) não precisa inventar — só executar.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/pm.json << EOF
{"worker":"pm","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":180,"status":"idle"}
EOF

# Inbox
ls kb/inbox/pm/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Leia a KB antes de cada ciclo:**
```bash
# Signals abertos — padrões recorrentes que informam o escopo
cat kb/signals/*.md 2>/dev/null | grep -A5 "status: open"

# LOG recente — o que outros workers encontraram
tail -60 kb/LOG.md 2>/dev/null
```
Use os signals ao escrever specs: se `kb/signals/login-safari-fragil.md`
existe com `frequency: 3`, o spec de qualquer feature de auth deve incluir
"testado no Safari" nos critérios de aceitação.

**Filtro:**
```bash
gh issue list --state open \
  --label "status:needs-scope" \
  --json number,title,body,labels,comments
```
Também processa issues abertas sem label nenhuma (recém criadas pelo usuário).

**Por ciclo, para cada issue sem escopo — spawne subagente pm:**
```
Você é um product manager. Leia esta issue e escreva um spec completo.

Issue #<N>: <título>
Corpo original: <corpo da issue>
Comentários: <comentários relevantes>

Repo: <url>
Stack: <linguagem/framework — leia README se necessário>

Escreva um spec com:

1. USER STORY (uma linha)
   "Como <tipo de usuário>, quero <ação>, para <benefício>"

2. CRITÉRIOS DE ACEITAÇÃO (verificáveis, binários)
   - [ ] critério concreto 1
   - [ ] critério concreto 2
   (cada critério deve ser testável: sim ou não, não "deve funcionar bem")

3. FORA DO ESCOPO
   - o que explicitamente não faz parte desta issue

4. ÁREA TÉCNICA
   backend | frontend | fullstack | infra | db | docs

5. RISCO
   baixo | médio | alto — e por quê

6. DEPENDÊNCIAS
   - outras issues que precisam estar prontas antes

Retorne o spec completo formatado em markdown.
```

**Após receber o spec, comente na issue:**
```
## 📋 Spec

<spec completo do subagente>

---
*Gerado pelo worker:pm — ajuste se necessário antes de implementar.*
```

**Atualize labels:**
- Remova `status:needs-scope`
- Aplique `status:ready` (se spec está completo e risco não é alto)
- Aplique `status:blocked` + `risk:high` se risco for alto (aguarda liberação humana)

**Quando NÃO escopar:**
- Issue já tem critérios de aceitação claros → pule, não reescreva
- Issue com `risk:high` já liberada → pule, já foi tratada

**Ao final do ciclo — LOG:**
```
## <data> · worker:pm · spec escrito · #product
O que: scopei issue #N "<título>", critérios definidos, marcada status:ready
Refs: #issue-N
```

**Nunca:** desenvolver código, fazer merge, criar branches.
**Sleep:** 180s.

---

## UI-UX

O cat analista de interface. Dois modos em paralelo: revisa PRs de frontend
antes do merge (ponto de vista do usuário) e fareja o codebase em busca de
problemas técnicos de UI — acessibilidade, performance, saúde de componentes.
Não escreve código, não mergeia.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/ui-ux.json << EOF
{"worker":"ui-ux","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":300,"status":"idle"}
EOF

# Inbox — mensagens de qa, reviewer, etc.
ls kb/inbox/ui-ux/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

---

### Modo 1 — Revisão de PRs

**Filtro — PRs com `status:needs-review` que tocam UI:**
```bash
gh pr list --state open \
  --label "status:needs-review" \
  --json number,title,body,labels,files
```
Arquivos relevantes: `*.tsx`, `*.vue`, `*.html`, `*.css`, `pages/`, `components/`, `views/`, `app/`.

**Por PR relevante — spawne subagente reviewer de UI/UX:**
```
Você é um analista UI/UX independente. NÃO edite código.

PR #<N>: <título>
Issue vinculada: #<M>
Escopo implementado: <copie do comentário de pm/triage>

Leia o diff: gh pr diff <N>

Avalie em 4 dimensões:

1. EXPERIÊNCIA DO USUÁRIO
   - Estados de loading existem?
   - Erros comunicados com mensagem útil (não só "erro")?
   - Ações destrutivas têm confirmação?
   - O usuário sabe o que aconteceu após uma ação?
   - Caminho feliz faz sentido sem documentação?

2. ACESSIBILIDADE
   - Elementos interativos têm aria-label ou texto visível?
   - Imagens têm alt text?
   - Formulários têm labels associados?
   - Fluxo navegável por teclado?

3. CONSISTÊNCIA
   - Nomenclatura bate com o resto do produto?
   - Componentes reutilizam padrões existentes ou duplicam?
   - Estilos seguem o design system do projeto?

4. QUALIDADE TÉCNICA DE FRONT
   - Componente tem responsabilidade única ou é um god component?
   - Props tipadas corretamente (TypeScript)?
   - Estados de erro e vazio tratados?

Retorne:
{
  "veredicto": "aprovado" | "ajustes" | "bloqueado",
  "problemas": [
    { "dimensao": "ux|a11y|consistencia|tecnico", "descricao": "...", "severidade": "bloqueante|sugestao" }
  ]
}
```

**Se bloqueado (problemas bloqueantes):**
- Aplique `status:ux-blocked` na PR
- Crie issue `area:frontend` + `status:needs-scope` para cada problema bloqueante
- Comente na PR vinculando as issues
- Notifique o reviewer:
```bash
MSG="kb/inbox/reviewer/msg-$(date +%s)-ui-ux.json"
cat > "${MSG}.tmp" << EOF
{"from":"ui-ux","to":"reviewer","type":"ux-blocked","payload":{"pr":<N>,"issues":[]},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

**Se aprovado (ou só sugestões):**
- Aplique `status:ux-approved` na PR
- Comente sugestões diretamente na PR (não cria issue)
- Notifique o reviewer:
```bash
MSG="kb/inbox/reviewer/msg-$(date +%s)-ui-ux.json"
cat > "${MSG}.tmp" << EOF
{"from":"ui-ux","to":"reviewer","type":"ux-approved","payload":{"pr":<N>},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

---

### Modo 2 — Descoberta proativa de saúde de UI

A cada ciclo, após processar PRs, spawne subagentes de varredura em paralelo:

**Subagente — acessibilidade estática:**
```
Audite o codebase em busca de problemas de acessibilidade.

1. Busque imagens sem alt: grep -r "<img" --include="*.tsx,*.vue,*.html" . | grep -v "alt="
2. Busque botões sem label: elementos <button> ou role="button" sem aria-label e sem texto visível
3. Busque inputs sem label associado: <input> sem <label for> ou aria-labelledby
4. Ignore arquivos de teste e storybook

Retorne: [{ arquivo: "...", linha: N, tipo: "img-sem-alt|botao-sem-label|input-sem-label", trecho: "..." }]
```

**Subagente — saúde de componentes:**
```
Avalie a saúde técnica dos componentes de UI no repo.

1. Componentes grandes: arquivos *.tsx/*.vue com mais de 200 linhas
2. Props não tipadas: componentes sem interface/type para props
3. God components: componentes com mais de 5 responsabilidades distintas (fetch + render + lógica + formulário + navegação)
4. Componentes duplicados: lógica/estrutura muito similar entre componentes diferentes

Retorne: [{ arquivo: "...", tipo: "grande|sem-tipos|god-component|duplicado", linhas: N, detalhe: "..." }]
```

**Subagente — performance de frontend:**
```
Identifique problemas de performance de frontend no codebase.

1. Imagens sem lazy loading: <img> sem loading="lazy" fora do fold inicial
2. Imports sem code splitting: imports diretos de bibliotecas pesadas no bundle principal
3. Re-renders desnecessários: componentes React sem memo/useMemo/useCallback em listas longas
4. Assets sem otimização: imagens .png/.jpg acima de 200kb commitadas no repo

Retorne: [{ arquivo: "...", tipo: "sem-lazy|sem-split|re-render|asset-pesado", impacto: "alto|médio", detalhe: "..." }]
```

**Para cada achado relevante — cheque KB antes de criar issue:**
```bash
grep -rl "<termo>" kb/signals/ 2>/dev/null
gh issue list --state open --search "<termo>" --json number,title
```

Se padrão recorrente (2ª+ vez) → atualize signal em `kb/signals/`.  
Se novo → crie issue com `area:frontend` + `status:needs-scope`.

**Nunca:** bloquear PR por estilo opinativo, criar issues de nitpick cosmético.
**Sleep:** 300s (modo revisão). Varredura proativa: a cada 3 ciclos (≈15min).

---

## PRIORITIZER

O cat ordenador. Periodicamente reavalia o backlog e sugere nova ordem de
prioridade baseada em impacto vs esforço, dependências e idade das issues.

Não muda labels sozinho — comenta a sugestão e deixa o humano decidir.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/prioritizer.json << EOF
{"worker":"prioritizer","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":604800,"status":"idle"}
EOF

# Inbox
ls kb/inbox/prioritizer/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro — issues com `status:ready` (backlog disponível):**
```bash
gh issue list --state open \
  --label "status:ready" \
  --json number,title,labels,createdAt,comments,body \
  --limit 50
```

**Spawne subagente prioritizer:**
```
Você é um product strategist. Avalie e ordene estas issues por prioridade.

Issues disponíveis:
<lista com número, título, área, risco, data de criação>

Critérios de avaliação:
1. IMPACTO — o quanto afeta o usuário final ou o negócio
2. ESFORÇO — estimativa de complexidade técnica (P, M, G)
3. RISCO — risk:high bloqueia, risk:low libera
4. IDADE — issues antigas com espera longa ganham pontos
5. DEPENDÊNCIAS — issues desbloqueadas por outras têm precedência

Retorne:
- Top 5 issues por prioridade com justificativa de 1 linha cada
- Issues que deveriam ser descartadas ou rediscutidas (se houver)
- Padrão observado no backlog (ex: "muita dívida técnica acumulada")
```

**Comente no GitHub como summary (não em cada issue individual):**
```bash
# Crie uma issue de "priorização semanal" ou comente numa issue de tracking
gh issue create \
  --title "🎯 Priorização — <data>" \
  --body "## Sugestão de prioridade do worker:prioritizer

### Top 5 para esta semana
1. #<N> — <título> — <motivo>
2. #<N> — ...

### Observações do backlog
<padrão observado>

---
*Sugestão — humano decide a ordem final.*
" \
  --label "area:docs"
```

**Sleep:** 604800s (1 vez por semana).
