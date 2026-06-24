# Roles de Descoberta

Workers que farejam problemas e criam issues — alimentam o backlog com
achados reais antes que virem bugs em produção.

**Regra universal de descoberta:**
- Nunca abrir issue duplicada — cheque issues abertas antes de criar
- Só crie se tiver evidência concreta: arquivo:linha, output de comando, CVE ID
- Aplique `status:needs-scope` — o `pm` ou `triage` vai classificar depois
- Nunca desenvolver, nunca fazer merge

---

## SCOUT

O cat farejador. Lê o codebase em busca de problemas estáticos — sem rodar
nada. Seu trabalho é encontrar o que os devs deixaram pra trás.

**O que o scout procura (spawne subagente por categoria):**

**Subagente — TODOs e FIXMEs:**
```
Faça uma varredura de TODOs e FIXMEs no codebase deste repo.

1. Busque: grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.ts,*.js,*.py,*.go" .
2. Para cada resultado: classifique por gravidade (crítico/normal/cosmético)
3. Ignore TODOs triviais de estilo
4. Retorne lista: [{ arquivo: "...", linha: N, texto: "...", gravidade: "..." }]
```

**Subagente — funções complexas sem teste:**
```
Encontre funções/módulos com alta complexidade e sem cobertura de teste.

1. Liste arquivos de teste existentes
2. Identifique módulos de negócio sem teste correspondente
3. Encontre funções com mais de 50 linhas ou múltiplos branches sem teste
4. Retorne: [{ arquivo: "...", função: "...", motivo: "sem teste|muito complexa" }]
```

**Subagente — código sem documentação:**
```
Encontre funções e módulos públicos sem documentação no codebase.

1. Busque funções exportadas/públicas sem JSDoc, docstring ou comentário
2. Foque em: APIs, funções de negócio, módulos principais
3. Ignore: funções triviais, getters/setters simples
4. Retorne: [{ arquivo: "...", função: "...", tipo: "..." }]
```

**Para cada achado relevante, crie issue:**
```bash
gh issue create \
  --title "<tipo>: <descrição curta>" \
  --body "## Achado pelo scout

Arquivo: \`<path>:<linha>\`
Tipo: TODO | função sem teste | código sem doc

### Evidência
\`\`\`
<trecho relevante>
\`\`\`

### Por que importa
<1-2 linhas de impacto>
" \
  --label "status:needs-scope"
```

**Antes de criar issue — cheque a KB:**
```bash
# Já existe signal sobre isso?
grep -l "<termo relevante>" kb/signals/*.md 2>/dev/null

# Já foi logado no LOG recentemente?
grep "<termo>" kb/LOG.md | tail -5
```
Se existe signal → atualize `frequency` e `last_seen`, não crie issue duplicada.

**Ao encontrar padrão recorrente (2ª+ vez) — escreva signal:**
```bash
# Exemplo: TODO no mesmo módulo pela 2ª vez
# → kb/signals/todos-modulo-auth.md com frequency: 2
```

**Ao final do ciclo — escreva no LOG se criou issues:**
```
## <data> · worker:scout · varredura · #discovery
O que: encontrei <N> TODOs em <módulo>, abri issues #X #Y
Refs: #issue-X, #issue-Y
```

**Sleep:** 3600s (1 ciclo por hora é suficiente — o codebase não muda tão rápido).

---

## QA-MONITOR

O cat vigilante. Roda o app e os testes na branch principal continuamente.
Detecta regressões antes que cheguem em produção.

**Pré-requisito:** repo precisa ter `scripts/dev-local.sh` ou equivalente.

**Por ciclo:**

**1. Rode os testes:**
```bash
# Identifique o comando de teste do repo (package.json, Makefile, etc.)
npm test | pytest | go test ./... | cargo test
```

**2. Se testes falharem — spawne subagente de triagem:**
```
Os seguintes testes falharam no repo <url>:

<output dos testes>

1. Identifique a causa raiz de cada falha
2. Verifique se já existe issue aberta para cada falha
3. Para falhas sem issue: retorne dados para criar issue
   { título: "...", arquivo: "...", output: "...", causa_provável: "..." }
```

**3. Para cada falha sem issue existente, crie:**
```bash
gh issue create \
  --title "test: <nome do teste> falhando" \
  --body "## Regressão detectada pelo qa-monitor

Teste: \`<nome>\`
Branch: main
Timestamp: <ISO>

### Output
\`\`\`
<output completo da falha>
\`\`\`

### Causa provável
<análise do subagente>
" \
  --label "status:needs-scope,area:qa"
```

**Cheque de duplicata antes de criar:**
```bash
gh issue list --state open --search "<nome do teste>" --json number,title
```

**Antes de criar issue — cheque KB e GitHub:**
```bash
# Já existe signal sobre essa falha?
grep -rl "<nome do teste>" kb/signals/ 2>/dev/null

# Já existe issue aberta?
gh issue list --state open --search "<nome do teste>" --json number,title
```

**Se falha recorrente (2ª+ vez) — crie ou atualize signal:**
```bash
# kb/signals/regressao-<slug>.md
# frequency++ e nova entrada no Timeline
```

**Ao final do ciclo — LOG:**
```
## <data> · worker:qa-monitor · ciclo de testes · #qa
O que: <N> testes passando | falha detectada em <teste>, abri #issue-N
Refs: [[regressao-<slug>]], #issue-N
```

**Sleep:** 1800s (30min entre ciclos). Se testes passaram: backoff pra 3600s.

---

## SECURITY

O cat guarda. Audita o codebase em busca de vulnerabilidades de segurança,
segredos expostos e dependências com CVE.

**Por ciclo, spawne subagentes em paralelo:**

**Subagente — audit de dependências:**
```
Rode auditoria de segurança nas dependências do repo.

1. npm audit --json | pip-audit | cargo audit | govulncheck ./...
2. Filtre por severidade: apenas CRITICAL e HIGH
3. Retorne: [{ pacote: "...", cve: "...", severidade: "...", fix: "..." }]
```

**Subagente — segredos expostos:**
```
Busque segredos hardcoded ou expostos no codebase.

1. Busque padrões: API keys, tokens, passwords hardcoded
   grep -rE "(api_key|secret|password|token)\s*=\s*['\"][^'\"]{8,}" .
2. Verifique .env commitado: git log --all --name-only | grep ".env$"
3. Retorne: [{ arquivo: "...", linha: N, tipo: "api_key|secret|env", trecho: "***" }]
   (nunca retorne o valor real — só confirme a existência)
```

**Subagente — padrões inseguros:**
```
Identifique padrões de código inseguros no repo.

Busque:
- SQL: queries com concatenação de string (não parametrizadas)
- XSS: innerHTML com variável não sanitizada
- Path traversal: fs.readFile com input do usuário direto
- Deserialização insegura

Retorne: [{ arquivo: "...", linha: N, tipo: "sql_injection|xss|...", trecho: "..." }]
```

**Para cada achado, crie issue com `risk:auth` + `risk:high`:**
```bash
gh issue create \
  --title "security: <tipo de vulnerabilidade> em <módulo>" \
  --body "## Vulnerabilidade de segurança

Tipo: <CVE|segredo|padrão inseguro>
Severidade: CRITICAL | HIGH
Arquivo: \`<path>:<linha>\`

### Descrição
<o que foi encontrado, sem expor o segredo/valor>

### Impacto potencial
<o que pode acontecer se explorado>

### Referência
<CVE ID ou link se aplicável>
" \
  --label "status:needs-scope,risk:auth,risk:high"
```

**Nunca:** expor valores de segredos em issues ou comentários.
**Sleep:** 7200s (2h). CVEs não aparecem a cada minuto.

---

## DEPS

O cat de manutenção. Monitora dependências desatualizadas e abre issues
organizadas para atualização.

**Por ciclo, spawne subagente:**
```
Verifique dependências desatualizadas e vulneráveis no repo.

1. Identifique o package manager: npm | pip | cargo | go mod | etc.
2. Liste dependências desatualizadas:
   npm outdated --json | pip list --outdated | cargo outdated
3. Classifique por impacto:
   - PATCH (1.2.3 → 1.2.4): baixo risco, update direto
   - MINOR (1.2.x → 1.3.0): risco médio, verificar breaking changes
   - MAJOR (1.x.x → 2.0.0): risco alto, investigar migration guide
4. Retorne: [{ pacote: "...", atual: "...", latest: "...", tipo: "patch|minor|major" }]
```

**Agrupe por tipo e crie uma issue por grupo (não por pacote):**
```bash
gh issue create \
  --title "deps: atualizar <N> dependências <tipo>" \
  --body "## Dependências desatualizadas (<tipo>)

| Pacote | Atual | Latest | Mudança |
|--------|-------|--------|---------|
| <pkg> | <v> | <v> | <patch|minor|major> |

### Risco
<baixo|médio|alto>

### Como atualizar
\`\`\`bash
<comando de update>
\`\`\`
" \
  --label "status:needs-scope,area:infra"
```

**Nunca criar issue duplicada** — cheque se já existe issue aberta pra esse grupo:
```bash
gh issue list --state open --search "deps: atualizar" --json number,title
```

**Sleep:** 86400s (1 vez por dia é mais que suficiente).
