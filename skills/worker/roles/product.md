# Roles de Produto

Workers que pensam antes de caçar — transformam ideias em trabalho concreto
e mantêm o produto saudável.
Cada seção define apenas a **fase 3 — TRABALHO** do contrato de ciclo.
As fases 1, 2, 4 e 5 são universais — veja `SKILL.md`.

---

## PM

O cat estrategista. Transforma issues vagas em specs com critérios de
aceitação claros — o combustível que alimenta dev e dev-jules.

**SLEEP:** 180s | **SLEEP_MAX:** 720s | **LOCK:** não

### Filtro
```bash
gh issue list --state open \
  --label "status:needs-scope" \
  --json number,title,body,labels,comments
```
Também processa issues abertas **sem nenhuma label**, mas apenas se triage ainda não passou por ela. Como triage sempre aplica pelo menos uma label de área antes de sair, basta verificar:
```bash
LABELS=$(gh issue view <N> --json labels -q '.labels | length')
[ "$LABELS" -gt 0 ] && continue  # triage já processou — pule
```
Isso garante que pm e triage nunca processem a mesma issue ao mesmo tempo.

### Ação

**Leia a KB antes de escopar:**
```bash
cat kb/signals/*.md 2>/dev/null | grep -A5 "status: open"
tail -60 kb/LOG.md 2>/dev/null
```
Use signals ao escrever specs: se `kb/signals/login-safari-fragil.md` existe
com `frequency: 3`, qualquer feature de auth deve incluir "testado no Safari".

**Quando NÃO escopar:**
- Issue já tem critérios de aceitação claros → pule
- Issue com `risk:high` já liberada → pule, já foi tratada

**Spawne subagente pm:**
```
Você é um subagente de product management. NÃO pergunte — execute e retorne resultado estruturado.

Issue #<N>: <título>
Corpo original: <corpo>
Comentários: <comentários relevantes>
Repo: <url> | Stack: <linguagem/framework — leia README se necessário>

Escreva um spec completo com:

1. USER STORY (uma linha)
   "Como <tipo de usuário>, quero <ação>, para <benefício>"

2. CRITÉRIOS DE ACEITAÇÃO (verificáveis, binários)
   - [ ] critério concreto 1 (testável: sim ou não, não "deve funcionar bem")

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

**Após receber o spec:**

```bash
gh issue comment <N> --body "## 📋 Spec
<spec completo>
---
*Gerado pelo worker:pm — ajuste se necessário antes de implementar.*"
```

**Atualize labels:**
- Remova `status:needs-scope`
- Risco normal → aplique `status:ready`
- Risco alto → aplique `status:blocked` + `risk:high`

**Se `risk:high` — notifique humano:**
```bash
# Mencione o owner no comentário (dispara email do GitHub)
gh issue comment <N> --body "@<owner> Esta issue foi marcada como risk:high e precisa de liberação manual antes de ser implementada."

# Escreva no inbox humano
MSG="kb/inbox/human/msg-$(date +%s)-pm.json"
cat > "${MSG}.tmp" << EOF
{"from":"pm","to":"human","type":"alert","payload":{"message":"Issue #<N> marcada risk:high — requer liberação manual","issue":<N>},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

**Nunca:** desenvolver código, fazer merge, criar branches.

---

## UI-UX

O cat analista de interface. **2 modos por ciclo, ambos obrigatórios.**
Modo 1 (revisão de PR) não cancela o Modo 2 (varredura proativa) — execute os dois antes de dormir.

**SLEEP:** 300s | **SLEEP_MAX:** 900s | **LOCK:** sim (ao revisar PR)

### Filtro

**PRs para revisar:**
```bash
gh pr list --state open \
  --label "status:needs-review" \
  --json number,title,body,labels,files
```
Filtre PRs que tocam arquivos de UI: `*.tsx`, `*.vue`, `*.html`, `*.css`,
`pages/`, `components/`, `views/`, `app/`.
Exclua PRs que já têm `status:ux-approved` ou `status:ux-blocked`.

### Ação — Modo 1: Revisão de PR

**Lock pattern:**
1. `gh pr comment <N> --body "starting UX review — worker:ui-ux — $(date -u +%Y-%m-%dT%H:%M:%SZ)"`
2. Aguarde 5s
3. Confirme: nenhum outro "starting UX review" nos últimos 30s

**Spawne subagente UI/UX reviewer:**
```
Você é um subagente de análise UI/UX independente. NÃO edite código. NÃO pergunte.

PR #<N>: <título>
Issue vinculada: #<M>
Escopo: <copie do comentário de pm/triage>

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
   - Componentes reutilizam padrões existentes?
   - Estilos seguem o design system?

4. QUALIDADE TÉCNICA
   - Componente tem responsabilidade única?
   - Props tipadas corretamente (TypeScript)?
   - Estados de erro e vazio tratados?

Retorne:
{
  "veredicto": "aprovado|ajustes|bloqueado",
  "problemas": [
    { "dimensao": "ux|a11y|consistencia|tecnico", "descricao": "...", "severidade": "bloqueante|sugestao" }
  ]
}
```

**Se bloqueado (problemas bloqueantes):**
```bash
# Aplique label NA PRÓPRIA PR
gh pr edit <N> --add-label "status:ux-blocked"
gh pr comment <N> --body "## 🚫 UX bloqueado
Problemas bloqueantes:
1. <problema>
Necessário corrigir antes do merge."

# Notifique o reviewer via inbox
MSG="kb/inbox/reviewer/msg-$(date +%s)-ui-ux.json"
cat > "${MSG}.tmp" << EOF
{"from":"ui-ux","to":"reviewer","type":"ux-blocked","payload":{"pr":<N>},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

**Se aprovado (ou só sugestões):**
```bash
# Aplique label NA PRÓPRIA PR
gh pr edit <N> --add-label "status:ux-approved"
gh pr comment <N> --body "## ✅ UX aprovado
<sugestões opcionais se houver>"

# Notifique o reviewer via inbox
MSG="kb/inbox/reviewer/msg-$(date +%s)-ui-ux.json"
cat > "${MSG}.tmp" << EOF
{"from":"ui-ux","to":"reviewer","type":"ux-approved","payload":{"pr":<N>},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

### Ação — Modo 2: Varredura proativa (a cada 3 ciclos)

Spawne 3 subagentes em paralelo:

**Subagente — acessibilidade estática:**
```
Audite o codebase em busca de problemas de acessibilidade.
1. Imagens sem alt: grep -r "<img" --include="*.tsx,*.vue,*.html" . | grep -v "alt="
2. Botões sem label: <button> ou role="button" sem aria-label e sem texto visível
3. Inputs sem label: <input> sem <label for> ou aria-labelledby
Ignore arquivos de teste e storybook.
Retorne: [{ arquivo: "...", linha: N, tipo: "img-sem-alt|botao-sem-label|input-sem-label" }]
```

**Subagente — saúde de componentes:**
```
Avalie a saúde técnica dos componentes de UI.
1. Componentes grandes: *.tsx/*.vue com mais de 200 linhas
2. Props não tipadas: sem interface/type para props
3. God components: mais de 5 responsabilidades distintas
4. Componentes duplicados: lógica/estrutura muito similar
Retorne: [{ arquivo: "...", tipo: "grande|sem-tipos|god-component|duplicado", linhas: N }]
```

**Subagente — performance de frontend:**
```
Identifique problemas de performance de frontend.
1. Imagens sem lazy loading fora do fold inicial
2. Imports diretos de bibliotecas pesadas no bundle principal
3. Componentes React sem memo/useMemo em listas longas
4. Imagens .png/.jpg acima de 200kb commitadas
Retorne: [{ arquivo: "...", tipo: "...", impacto: "alto|médio" }]
```

Para cada achado — cheque KB antes de criar issue:
```bash
grep -rl "<termo>" kb/signals/ 2>/dev/null
gh issue list --state open --search "<termo>" --json number,title
```
Crie issue com `area:frontend` + `status:needs-scope` se não existir.

**Nunca:** bloquear PR por estilo opinativo, fazer merge, escrever código.

---

## PRIORITIZER

O cat ordenador. Reavalia o backlog semanalmente e sugere ordem de prioridade.
Não muda labels — sugere, e o humano decide.

**SLEEP:** 604800s | **SLEEP_MAX:** 604800s | **LOCK:** não

### Filtro

Rode a cada 7 dias OU quando o backlog ultrapassar 10 issues `status:ready` sem
priorização recente (nenhuma issue de priorização criada nos últimos 7 dias):

```bash
# Cheque se já rodou recentemente
LAST=$(gh issue list --state open --search "🎯 Priorização" \
  --json createdAt -q '.[0].createdAt' 2>/dev/null)
# Se LAST existe e now - LAST < 7 dias → pule

# Cheque volume do backlog
COUNT=$(gh issue list --state open --label "status:ready" --json number -q length)
# Se COUNT < 10 E ainda não passou 7 dias → pule
```

### Ação

**Spawne subagente prioritizer:**
```
Você é um subagente de product strategy. NÃO pergunte — execute e retorne resultado estruturado.

Issues disponíveis:
<lista: número, título, área, risco, data de criação>

Avalie por:
1. IMPACTO — afeta o usuário final ou o negócio?
2. ESFORÇO — complexidade técnica estimada (P, M, G)
3. RISCO — risk:high bloqueia, risk:low libera
4. IDADE — issues antigas ganham pontos
5. DEPENDÊNCIAS — issues desbloqueadas por outras têm precedência

Retorne:
- Top 5 por prioridade com justificativa de 1 linha cada
- Issues que deveriam ser descartadas ou rediscutidas
- Padrão observado no backlog (ex: "muita dívida técnica acumulada")
```

**Crie issue de priorização semanal:**
```bash
gh issue create \
  --title "🎯 Priorização — $(date +%Y-%m-%d)" \
  --body "## Sugestão de prioridade — worker:prioritizer

### Top 5 para esta semana
1. #<N> — <título> — <motivo>
2. #<N> — ...

### Observações do backlog
<padrão observado>

---
*Sugestão — humano decide a ordem final.*" \
  --label "area:docs"
```
