# CatAgents

> *"Um cat não precisa de ordem pra caçar."*

Um ecossistema de trabalhadores autônomos para desenvolvimento de software.
Cada worker acorda, encontra seu trabalho no GitHub, executa, verifica e dorme
— sem ser prompatado manualmente. Você escreve ideias e toma decisões. O resto
acontece.

---

## Como funciona

Os workers se coordenam através de três canais compartilhados:

- **GitHub** → estado do código (issues, PRs, labels)
- **Knowledge base** → memória do que o sistema aprendeu (`kb/signals/`, `kb/LOG.md`)
- **Canal de presença e inbox** → quem está online e mensagens diretas entre workers (`kb/presence/`, `kb/inbox/`)

Eles nunca se falam diretamente via API. Um worker escreve no GitHub ou na KB;
outro lê e age. O canal de presença resolve o único gap: saber quem está rodando
agora para decidir se deve esperar ou prosseguir.

```
pm escreve spec → triage classifica → dev implementa → ui-ux revisa → qa testa → reviewer mergeia
     ↑                                                                                    |
scout/debt/docs/coverage abrem issues ←← qa-monitor detecta regressões ←←←←←←←←←←←←←←←←
```

---

## Workers disponíveis

### Código — coordenam via GitHub labels
| Worker | O que faz |
|--------|-----------|
| `triage` | Classifica issues sem área ou status — alimenta a fila do dev |
| `dev` | Implementa issues localmente, abre PRs |
| `dev-jules` | Delega issues pro Jules (Google AI), monitora PRs async |
| `qa` | Testa PRs com verifier subagente independente |
| `reviewer` | Mergeia PRs com QA aprovado |

### Descoberta — criam issues, alimentam o backlog
| Worker | O que faz |
|--------|-----------|
| `scout` | Fareja TODOs e funções sem teste |
| `qa-monitor` | Roda testes na main, detecta regressões |
| `security` | Audita vulnerabilidades, CVEs e segredos expostos |
| `deps` | Monitora dependências desatualizadas |
| `coverage` | Mede cobertura por módulo, alerta quando cai abaixo do threshold |
| `debt` | Detecta complexidade, duplicação e god objects |
| `docs` | Audita README, docstrings, CHANGELOG, `.env.example` e docs avulsas desatualizadas |
| `analyst` | Lê o que foi entregue e propõe melhorias de produto — fluxos incompletos, UX gaps |
| `bug-hunter` | Varre o codebase em busca de padrões bug-prone antes de virarem incidentes |

### Produto — pensam antes de caçar
| Worker | O que faz |
|--------|-----------|
| `pm` | Transforma ideias vagas em specs com critérios de aceitação |
| `ui-ux` | Revisa PRs de frontend (UX + a11y + qualidade) e varre saúde de UI proativamente |
| `prioritizer` | Reordena o backlog por impacto vs esforço semanalmente |

### Operações — mantêm o território limpo
| Worker | O que faz |
|--------|-----------|
| `stale` | Fecha issues e PRs abandonadas |
| `release` | Gera changelog, bump de versão, abre PR de release |

---

## Instalação

**Linux / macOS:**
```bash
git clone https://github.com/CatConnect/catgents-workflow.git
./catgents-workflow/install.sh
```

**Windows:**
```powershell
git clone https://github.com/CatConnect/catgents-workflow.git
.\catgents-workflow\install.ps1
```

Instala globalmente em `~/.claude/skills/`:
- `worker` — todos os workers via `/worker <papel>`
- `pr` — verificação antes de abrir PR via `/pr`

**Requisitos:** Claude Code CLI + `gh` (GitHub CLI) autenticado.

---

## Uso

Cada worker roda em loop contínuo em sua própria sessão do Claude Code.
Abra uma sessão por worker e rode o comando — ele fica rodando até você fechar o terminal.
Quando não há trabalho, faz backoff automático e aguarda indefinidamente.

```bash
# Sessão 1 — classifica o que chega
/worker triage

# Sessão 2 — escreve specs das ideias
/worker pm

# Sessão 3 — implementa localmente
/worker dev

# Sessão 4 — ou delega pro Jules
/worker dev-jules

# Sessão 5 — revisa a experiência e saúde de frontend
/worker ui-ux

# Sessão 6 — testa PRs
/worker qa

# Sessão 7 — mergeia
/worker reviewer
```

Para abrir uma PR com verificação:
```bash
/pr
```

---

## Composições prontas

Você não precisa rodar todos. Comece pequeno:

| Equipe | Terminais | Quando usar |
|--------|-----------|-------------|
| **Solo** | 1 | Você mesmo + 1 worker de dev |
| **Mínimo** | 2 | `pm` + `dev` |
| **Padrão** | 3 | `triage` + `dev` + `qa` |
| **Completo** | 5 | `triage` + `pm` + `dev` + `qa` + `reviewer` |
| **Com Jules** | 3 | `pm` + `dev-jules` + `reviewer` |
| **Com Jules + UX** | 4 | `pm` + `dev-jules` + `ui-ux` + `reviewer` |
| **Descoberta** | 4 | `scout` + `qa-monitor` + `coverage` + `docs` (rode à noite) |
| **Vigilância** | 3 | `security` + `deps` + `debt` |

---

## Um dia de trabalho com CatAgents

**Manhã — você abre 3 terminais e vai tomar café:**
```
/worker scout
/worker pm
/worker dev
```

`scout` varre o codebase — abre 3 issues com TODOs críticos e gaps de teste.
`pm` lê as issues vagas que você escreveu ontem e escreve specs com critérios.
`dev` pega a primeira issue scopada e começa a implementar.

**Você volta do café.** No GitHub: issues novas, specs escritos, 1 PR aberta.

**Durante o dia**, você trabalha na sua feature complexa. Noutra aba:
```
/worker ui-ux
/worker qa
/worker reviewer
```

`ui-ux` revisa a PR de frontend — verifica fluxo, acessibilidade e qualidade de componentes.
Aprova e notifica o `reviewer` via inbox. `qa` testa com subagente independente que dirige
o app real. `reviewer` vê `status:qa-approved` + `status:ux-approved` e mergeia.

**Ao final do dia**, `scout` e `qa-monitor` continuam rodando. `qa-monitor`
detectou que uma PR anterior quebrou o login no Safari — abriu issue com output
completo antes que chegasse em produção. `coverage` percebeu que o módulo de
auth caiu para 62% e abriu issue automaticamente.

**Você dormiu. O trabalho não parou.**

---

## Como os workers se coordenam

### Contrato de ciclo

Todo worker executa as mesmas 5 fases a cada ciclo — o que muda entre eles
é apenas o filtro e a ação (fase 3):

```
1. PRESENÇA   — escreve heartbeat (outros workers sabem que está online)
2. INBOX      — lê mensagens diretas de outros workers
3. TRABALHO   — busca trabalho no GitHub e age  ← único ponto de variação
4. KB-WRITE   — registra no LOG se houve ação relevante
5. SLEEP      — dorme (backoff se não houver trabalho, nunca encerra)
```

### GitHub — estado do trabalho

Labels definem o pipeline. Workers leem e escrevem labels a cada ciclo:

```
status:needs-scope → pm escreve spec    → status:ready
status:ready       → dev implementa     → status:needs-review (na PR)
status:needs-review → ui-ux revisa      → status:ux-approved (na PR)
status:needs-review → qa testa          → status:qa-approved (na PR)
status:qa-approved → reviewer mergeia   → issue fechada
```

Se QA ou UX bloqueiam → `dev` corrige → volta para `status:needs-review`.
Se `reviewer` mergeia → verifica issues com `risk:conflict` e desbloqueia automaticamente.

### Knowledge base — memória persistente

```
kb/
  LOG.md       # registro cross-worker (o que aconteceu e quando)
  signals/     # padrões recorrentes (frequency, last_seen)
  presence/    # heartbeat de cada worker (quem está online agora)
  inbox/       # mensagens diretas entre workers (consumo único)
```

`kb/presence/` permite coordenação dinâmica: o `reviewer` verifica se o
`ui-ux` está online antes de decidir se espera revisão ou mergeia sem ela.

### Por que subagentes?

Workers rodam em loop longo — um agente que faz tudo sozinho acumula
histórico e toma decisões piores ao longo do tempo (contexto sujo).

O worker é um **orquestrador leve**: trabalho pesado vai para subagentes
que nascem com contexto vazio, executam uma tarefa e morrem. O orquestrador
recebe apenas o resultado — contexto permanece limpo indefinidamente.

```
worker (loop longo, contexto mínimo)
  └── subagente "dev #42" (contexto vazio, nasce aqui)
      └── implementa → retorna resultado
          (morre — não contamina o worker)
```

---

## License

MIT
