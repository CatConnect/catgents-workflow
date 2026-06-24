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
| `scout` | Fareja TODOs, funções sem teste, código sem doc |
| `qa-monitor` | Roda testes na main, detecta regressões |
| `security` | Audita vulnerabilidades, CVEs e segredos expostos |
| `deps` | Monitora dependências desatualizadas |
| `coverage` | Mede cobertura por módulo, alerta quando cai abaixo do threshold |
| `debt` | Detecta complexidade, duplicação e god objects |
| `docs` | Audita README, docstrings, CHANGELOG e `.env.example` |

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

Abra um terminal Claude Code por worker que quiser rodar:

```bash
# Terminal 1 — classifica o que chega
/worker triage

# Terminal 2 — escreve specs das ideias
/worker pm

# Terminal 3 — implementa localmente
/worker dev

# Terminal 4 — ou delega pro Jules
/worker dev-jules

# Terminal 5 — revisa a experiência e saúde de frontend
/worker ui-ux

# Terminal 6 — testa PRs
/worker qa

# Terminal 7 — mergeia
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

### GitHub — estado do trabalho
Labels definem o pipeline. Workers leem e escrevem labels a cada ciclo:

```
status:needs-scope → pm escreve spec → status:ready
status:ready       → dev implementa  → status:needs-review
status:needs-review → ui-ux revisa   → status:ux-approved
status:ux-approved → qa testa        → status:qa-approved
status:qa-approved → reviewer mergeia
```

### Knowledge base — memória persistente
```
kb/
  LOG.md          # registro cross-worker (o que aconteceu e quando)
  signals/        # padrões recorrentes detectados (frequency, last_seen)
  presence/       # heartbeat de cada worker (quem está online agora)
  inbox/          # mensagens diretas entre workers
```

Workers leem `kb/LOG.md` e `kb/signals/` antes de agir — evita duplicatas e
propaga contexto entre sessões e terminais. `kb/presence/` resolve o problema
de coordenação dinâmica: o `reviewer` verifica se o `ui-ux` está rodando antes
de decidir se espera a revisão ou mergeia sem ela.

### Por que subagentes?

Cada worker roda em loop longo — depois de muitos ciclos, um agente que fez
tudo sozinho acumula histórico irrelevante e toma decisões piores (contexto sujo).

A solução: o worker é um **orquestrador leve**. Trabalho pesado vai para
**subagentes** que nascem com contexto vazio, executam uma tarefa e morrem.
O orquestrador recebe apenas o resultado — contexto permanece limpo
independente de quantos ciclos passou.

```
worker (orquestrador — loop longo, contexto mínimo)
  └── subagente "dev #42" (nasce aqui, contexto focado)
      └── implementa → retorna resultado
          (morre — não contamina o worker)
```

---

## License

MIT
