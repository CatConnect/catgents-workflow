# CatAgents

> *"Um cat não precisa de ordem pra caçar."*

Um ecossistema de workers autônomos para desenvolvimento de software via GitHub.
Você escreve ideias. O resto acontece.

---

## Como funciona

**GitHub é o único canal de comunicação.** Sem disco local, sem arquivos de estado.
Labels, assignees e comentários são o estado canônico — qualquer worker pode morrer
e reiniciar sem perder contexto.

```
team-manager lê o estado completo do repo
  ↓
  classifica issues → atribui dev
  dev implementa → abre PR
  team-manager detecta PR → atribui qa
  qa revisa → aprova ou bloqueia
  team-manager detecta resultado → atribui reviewer ou dev (para corrigir)
  reviewer mergeia → issue fechada
  ↑___________________________|
```

O `team-manager` é o único que toma decisões. Os outros só executam o que está
assignado a eles.

---

## Workers

### Orquestradores
| Worker | O que faz |
|--------|-----------|
| `team-manager` | Lê estado completo, classifica issues, escreve specs, atribui trabalho, detecta e corrige estados inválidos |

### Executores
| Worker | O que faz |
|--------|-----------|
| `dev` | Implementa issues assignadas, corrige PRs qa-blocked assignadas |
| `reviewer` | Mergeia PRs qa-approved assignadas |

### Analistas
| Worker | O que faz |
|--------|-----------|
| `qa` | Revisa PRs assignadas — roda typecheck, testes, analisa diff, emite veredicto |
| `scout` | Varredura passiva — limpa branches órfãs, alerta issues estagnadas, reporta backlog alto |

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

Instala globalmente em `~/.claude/skills/worker/`.

**Requisitos:** Claude Code CLI + `gh` (GitHub CLI) autenticado.

---

## Uso

Cada worker roda em loop contínuo em sua própria sessão. Comece pelo `team-manager`
— ele é quem organiza o trabalho para os outros.

```bash
# Sessão 1 — orquestrador (obrigatório)
/worker team-manager

# Sessão 2 — implementa
/worker dev

# Sessão 3 — revisa PRs
/worker qa

# Sessão 4 — mergeia
/worker reviewer

# Sessão 5 — varredura passiva (rode à noite ou esporadicamente)
/worker scout
```

Quando não há trabalho, cada worker faz backoff automático e aguarda.
Nunca encerram sozinhos — só param quando você fechar o terminal.

---

## Composições prontas

| Equipe | Terminais | Quando usar |
|--------|-----------|-------------|
| **Mínimo** | 2 | `team-manager` + `dev` |
| **Padrão** | 4 | `team-manager` + `dev` + `qa` + `reviewer` |
| **Completo** | 5 | `team-manager` + `dev` + `qa` + `reviewer` + `scout` |

---

## Pipeline de estados

### Issue
```
(sem status)     → team-manager classifica
status:needs-scope → team-manager escreve spec → status:ready
status:ready       → team-manager atribui dev  → status:in-progress
status:in-progress → dev abre PR               → issue fechada no merge
```

### PR
```
(sem status)      → team-manager aplica status:needs-review + atribui qa
status:needs-review → qa revisa → status:qa-approved ou status:qa-blocked
status:qa-blocked   → team-manager atribui dev para corrigir
status:qa-approved  → team-manager atribui reviewer
reviewer mergeia    → PR fechada
```

---

## Arquitetura

### Por que orquestrador + executores?

Na arquitetura anterior, cada worker decidia sozinho o que fazer — o que gerava
race conditions, PR stacking e filtros complexos que os modelos ignoravam.

Na arquitetura atual, **só o `team-manager` decide**. Executores e analistas
consultam apenas `gh ... --assignee @me` — sem filtros, sem gates, sem lógica
de priorização.

### Por que subagentes?

Workers rodam em loop longo. Um agente que faz tudo acumula histórico e piora
com o tempo (contexto sujo). O worker é um orquestrador leve: trabalho pesado
vai para subagentes que nascem com contexto vazio, executam uma tarefa e morrem.

```
worker (loop longo, contexto mínimo)
  └── subagente (contexto vazio, nasce aqui)
      └── implementa / revisa / escreve spec → retorna resultado
          (morre — não contamina o worker)
```

---

## License

MIT
