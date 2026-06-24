# Roles de Descoberta

Workers que farejam o codebase e criam issues — alimentam o backlog com
achados reais antes que virem bugs em produção.
Cada seção define apenas a **fase 3 — TRABALHO** do contrato de ciclo.
As fases 1, 2, 4 e 5 são universais — veja `SKILL.md`.

**Regra universal de descoberta:**
- Nunca abrir issue duplicada — cheque `kb/signals/`, `kb/LOG.md` e issues abertas antes de criar
- Só crie se tiver evidência concreta: `arquivo:linha`, output de comando, CVE ID
- Aplique `status:needs-scope` — o `pm` vai classificar depois
- Nunca desenvolver, nunca fazer merge

---

## SCOUT

O cat farejador. Varre o codebase estaticamente em busca do que os devs
deixaram pra trás.

**SLEEP:** 3600s | **SLEEP_MAX:** 7200s | **LOCK:** não

### Filtro

Varredura do codebase local. Spawne 3 subagentes em paralelo:

**Subagente — TODOs e FIXMEs:**
```
Faça uma varredura de TODOs e FIXMEs no codebase.
1. grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.ts,*.js,*.py,*.go" .
2. Classifique por gravidade: crítico | normal | cosmético
3. Ignore TODOs triviais de estilo
4. Retorne: [{ arquivo: "...", linha: N, texto: "...", gravidade: "..." }]
```

**Subagente — funções complexas sem teste:**
```
Encontre funções com alta complexidade e sem cobertura de teste.
1. Liste arquivos de teste existentes
2. Identifique módulos de negócio sem teste correspondente
3. Funções com mais de 50 linhas ou múltiplos branches sem teste
4. Retorne: [{ arquivo: "...", funcao: "...", motivo: "sem-teste|muito-complexa" }]
```

**Subagente — código sem documentação:**
```
Encontre funções e módulos públicos sem documentação.
1. Exports públicos sem JSDoc, docstring ou comentário de propósito
2. Foco em: APIs, funções de negócio, módulos principais
3. Ignore: funções triviais, getters/setters simples
4. Retorne: [{ arquivo: "...", funcao: "...", tipo: "..." }]
```

### Ação

Para cada achado relevante:

**Cheque KB e issues abertas:**
```bash
grep -rl "<termo>" kb/signals/ 2>/dev/null
grep "<termo>" kb/LOG.md | tail -5
gh issue list --state open --search "<termo>" --json number,title
```

Se padrão já existe como signal → atualize `frequency` e `last_seen`, não crie issue.
Se é a 2ª+ ocorrência → crie signal em `kb/signals/<slug>.md`.

**Crie issue se nova:**
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
<1-2 linhas de impacto>" \
  --label "status:needs-scope"
```

---

## QA-MONITOR

O cat vigilante. Roda os testes na branch principal e detecta regressões.

**SLEEP:** 1800s | **SLEEP_MAX:** 3600s | **LOCK:** não

**Pré-requisito:** repo precisa ter comando de teste definido (`package.json`, `Makefile`, etc.)

### Filtro + Ação

**1. Rode os testes na branch principal:**
```bash
npm test | pytest | go test ./... | cargo test
```

**2. Se passou:** backoff para 3600s no próximo ciclo.

**3. Se falhou — spawne subagente de triagem:**
```
Os seguintes testes falharam no repo:
<output dos testes>

1. Identifique a causa raiz de cada falha
2. Verifique se já existe issue aberta para cada falha
3. Para falhas sem issue: retorne { titulo: "...", arquivo: "...", output: "...", causa: "..." }
```

**4. Para cada falha sem issue existente:**

Cheque KB:
```bash
grep -rl "<nome do teste>" kb/signals/ 2>/dev/null
gh issue list --state open --search "<nome do teste>" --json number,title
```

Se falha recorrente (2ª+) → crie ou atualize signal `kb/signals/regressao-<slug>.md`.

Crie issue:
```bash
gh issue create \
  --title "test: <nome do teste> falhando" \
  --body "## Regressão detectada pelo qa-monitor
Teste: \`<nome>\` | Branch: main | Timestamp: <ISO>
### Output
\`\`\`
<output completo>
\`\`\`
### Causa provável
<análise do subagente>" \
  --label "status:needs-scope,area:qa"
```

---

## SECURITY

O cat guarda. Audita vulnerabilidades, segredos expostos e dependências com CVE.

**SLEEP:** 7200s | **SLEEP_MAX:** 14400s | **LOCK:** não

### Filtro + Ação

Spawne 3 subagentes em paralelo:

**Subagente — audit de dependências:**
```
Rode auditoria de segurança nas dependências.
1. npm audit --json | pip-audit | cargo audit | govulncheck ./...
2. Filtre: apenas CRITICAL e HIGH
3. Retorne: [{ pacote: "...", cve: "...", severidade: "...", fix: "..." }]
```

**Subagente — segredos expostos:**
```
Busque segredos hardcoded ou expostos.
1. grep -rE "(api_key|secret|password|token)\s*=\s*['\"][^'\"]{8,}" .
2. git log --all --name-only | grep ".env$"
3. Retorne: [{ arquivo: "...", linha: N, tipo: "api_key|secret|env", trecho: "***" }]
   (nunca retorne o valor real)
```

**Subagente — padrões inseguros:**
```
Identifique padrões de código inseguros.
- SQL: queries com concatenação de string (não parametrizadas)
- XSS: innerHTML com variável não sanitizada
- Path traversal: fs.readFile com input do usuário direto
Retorne: [{ arquivo: "...", linha: N, tipo: "sql_injection|xss|...", trecho: "..." }]
```

Para cada achado — crie issue com `risk:auth` + `risk:high` e notifique humano:
```bash
gh issue create \
  --title "security: <tipo> em <módulo>" \
  --body "## Vulnerabilidade de segurança
Tipo: <CVE|segredo|padrão inseguro> | Severidade: CRITICAL | HIGH
Arquivo: \`<path>:<linha>\`
### Descrição
<o que foi encontrado, sem expor o segredo>
### Impacto potencial
<o que pode acontecer se explorado>
### Referência
<CVE ID ou link>" \
  --label "status:needs-scope,risk:auth,risk:high"

# Notifique humano via inbox
MSG="kb/inbox/human/msg-$(date +%s)-security.json"
cat > "${MSG}.tmp" << EOF
{"from":"security","to":"human","type":"alert","payload":{"message":"Vulnerabilidade encontrada — veja issue #<N>"},"sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
mv "${MSG}.tmp" "${MSG}"
```

**Nunca:** expor valores de segredos em issues, comentários ou LOG.

---

## DEPS

O cat de manutenção. Monitora dependências desatualizadas.

**SLEEP:** 86400s | **SLEEP_MAX:** 86400s | **LOCK:** não

### Filtro + Ação

**Spawne subagente:**
```
Verifique dependências desatualizadas no repo.
1. Identifique o package manager: npm | pip | cargo | go mod
2. Liste desatualizadas: npm outdated --json | pip list --outdated | cargo outdated
3. Classifique:
   - PATCH (1.2.3 → 1.2.4): baixo risco
   - MINOR (1.2.x → 1.3.0): risco médio
   - MAJOR (1.x → 2.0): risco alto
4. Retorne: [{ pacote: "...", atual: "...", latest: "...", tipo: "patch|minor|major" }]
```

Cheque duplicata antes de criar:
```bash
gh issue list --state open --search "deps: atualizar" --json number,title
```

Crie uma issue por grupo (não por pacote):
```bash
gh issue create \
  --title "deps: atualizar <N> dependências <tipo>" \
  --body "## Dependências desatualizadas (<tipo>)
| Pacote | Atual | Latest |
|--------|-------|--------|
| <pkg> | <v> | <v> |
### Risco: <baixo|médio|alto>
### Como atualizar
\`\`\`bash
<comando>
\`\`\`" \
  --label "status:needs-scope,area:infra"
```

---

## COVERAGE

O cat medidor. Monitora cobertura de testes por módulo.

**SLEEP:** 3600s | **SLEEP_MAX:** 7200s | **LOCK:** não

### Filtro + Ação

**Spawne subagente:**
```
Meça cobertura de testes e identifique gaps críticos.
1. Rode: npm test -- --coverage | pytest --cov | go test ./... -cover
2. Parse o relatório por módulo/arquivo
3. Classifique por criticidade:
   - CRÍTICO: auth, pagamento, dados do usuário com < 80%
   - ALTO: módulos de negócio core com < 60%
   - MÉDIO: módulos secundários com < 40%
   - IGNORE: config, migrations, tipos, mocks
4. Retorne: { total: "XX%", criticos: [...], altos: [...], tendencia: "subindo|estavel|caindo" }
```

Para cada módulo abaixo do threshold:
```bash
gh issue list --state open --search "coverage: <módulo>" --json number,title
# Se não existe:
gh issue create \
  --title "coverage: <módulo> em <XX%> (threshold: <YY%>)" \
  --body "## Cobertura insuficiente
Módulo: \`<caminho>\`
Atual: **<XX%>** | Threshold: **<YY%>** | Funções sem teste: <N>
### Funções não cobertas
\`\`\`
<lista>
\`\`\`" \
  --label "status:needs-scope,area:qa"
```

Se cobertura caindo por 2+ ciclos → crie/atualize signal `kb/signals/coverage-queda-<modulo>.md`.

---

## DEBT

O cat arquiteto. Mede a saúde estrutural do código — complexidade e duplicação.

**SLEEP:** 86400s | **SLEEP_MAX:** 86400s | **LOCK:** não

### Filtro + Ação

Spawne 2 subagentes em paralelo:

**Subagente — complexidade:**
```
Meça complexidade estrutural do codebase.
1. Funções com mais de 10 branches (if/else/switch/try/catch)
2. Arquivos com mais de 300 linhas (exceto gerados, migrations, tipos)
3. Funções com mais de 5 parâmetros
4. God objects: classes/módulos com mais de 10 responsabilidades
Para cada achado, estime esforço: baixo | médio | alto
Retorne: [{ arquivo: "...", funcao: "...", tipo: "...", metrica: N, esforco: "..." }]
```

**Subagente — duplicação:**
```
Encontre código duplicado.
1. Blocos com mais de 15 linhas repetidos em 2+ arquivos
2. Funções com lógica idêntica mas nomes diferentes
3. Constantes duplicadas em múltiplos arquivos
Ignore: boilerplate gerado, migrations, testes.
Retorne: [{ arquivos: [...], tipo: "bloco|funcao|constante", linhas: N, sugestao: "..." }]
```

Para cada achado — cheque KB e issues abertas. Crie issue agrupada por módulo:
```bash
gh issue create \
  --title "debt: <módulo> — <tipo>" \
  --body "## Dívida técnica
Módulo: \`<caminho>\` | Tipo: complexidade | duplicação | god-object
### Achados
| Arquivo | Métrica | Esforço |
|---------|---------|---------|
| \`<path>\` | <valor> | <esforço> |
### Sugestão
<extração, decomposição, etc.>" \
  --label "status:needs-scope,area:backend"
```

**Nunca:** criar issue para nitpick de estilo ou nomes de variáveis.

---

## DOCS

O cat escriba. Audita a saúde da documentação do projeto.

**SLEEP:** 43200s | **SLEEP_MAX:** 43200s | **LOCK:** não

### Filtro + Ação

Spawne 2 subagentes em paralelo:

**Subagente — gaps no código:**
```
Encontre exports públicos sem documentação adequada.
1. Funções exportadas sem JSDoc/docstring (JS/TS/Python)
2. Handlers de API sem descrição de parâmetros e retorno
3. Hooks públicos e serviços sem comentário de propósito
Ignore: funções internas, getters/setters triviais, arquivos de tipo puros.
Retorne: [{ arquivo: "...", funcao: "...", tipo: "api|util|hook|service", motivo: "sem-doc|doc-vaga" }]
```

**Subagente — documentação de repo:**
```
Avalie a saúde da documentação de repositório.
1. README.md: existe? setup funciona? menciona features removidas? falta features novas?
2. CHANGELOG.md: existe? última entrada é recente?
3. API docs (swagger/openapi): existe? sincronizada com rotas atuais?
4. .env.example: existe? variáveis novas têm entrada?
Retorne:
{
  "readme": { "status": "ok|desatualizado|faltando", "problemas": [...] },
  "changelog": { "status": "ok|desatualizado|faltando" },
  "api_docs": { "status": "ok|desatualizado|faltando|nao_aplicavel" },
  "env_example": { "status": "ok|desatualizado|faltando", "vars_faltando": [...] }
}
```

Para cada gap crítico — crie issue:
```bash
gh issue create \
  --title "docs: <tipo de gap> em <módulo/arquivo>" \
  --body "## Documentação faltando ou desatualizada
Arquivo: \`<path>\`
Tipo: sem-docstring | readme-desatualizado | changelog-vazio | env-desatualizado
### Problema
<o que está faltando>
### O que deveria ter
<o que a documentação deveria cobrir>" \
  --label "status:needs-scope,area:docs"
```

**Nunca:** criar issue para comentários triviais ou TODOs (território do `scout`).
