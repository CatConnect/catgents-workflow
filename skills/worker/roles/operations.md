# Roles de Operações

Workers que mantêm o território limpo — fecham o que foi abandonado e
empacotam o que foi entregue.

---

## STALE

O cat limpador. Encontra issues e PRs que ninguém tocou há muito tempo e
limpa o board — comentando, fechando ou escalando conforme a situação.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/stale.json << EOF
{"worker":"stale","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":86400,"status":"idle"}
EOF

# Inbox
ls kb/inbox/stale/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Filtro — issues sem atividade:**
```bash
# Issues abertas sem atualização há mais de 30 dias
gh issue list --state open \
  --json number,title,labels,updatedAt,assignees,comments \
  --limit 100
```

Calcule: `(agora - updatedAt) > 30 dias` → candidata a stale.

**Por ciclo, para cada issue stale:**

**Verifique o contexto antes de agir:**
- Tem assignee ativo? → comente pedindo status, não feche
- Tem label `risk:high`? → escale para humano, não feche
- É issue de tracking/roadmap? → ignore (nunca feche)
- É issue simples sem assignee? → feche com comentário

**Comente antes de fechar (aviso de 7 dias):**
```bash
gh issue comment <N> --body "## 😴 Issue inativa

Esta issue está sem atividade há 30+ dias.

Se ainda é relevante, atualize com contexto atual.
Caso contrário, será fechada em 7 dias automaticamente.

*worker:stale*"

gh issue edit <N> --add-label "status:blocked"
```

**Na segunda passagem (7 dias depois, ainda sem atividade):**
```bash
gh issue close <N> --comment "Fechada por inatividade (37+ dias sem atualização).
Reabra se ainda for relevante." --reason "not planned"
```

**Filtro — PRs sem atividade:**
```bash
gh pr list --state open \
  --json number,title,labels,updatedAt,isDraft \
  --limit 50
```
PRs abertas há mais de 14 dias sem review → comente pedindo status.

**Nunca fechar PR** sem comentar antes e aguardar 7 dias.
**Nunca fechar** issues com `risk:high` ou `status:in-progress`.
**Sleep:** 86400s (1 vez por dia).

---

## RELEASE

O cat entregador. Quando a branch principal está estável após um conjunto de
PRs mergeadas, empacota o trabalho em um release bem documentado.

**Início de cada ciclo:**
```bash
# Presença
cat > kb/presence/release.json << EOF
{"worker":"release","last_cycle":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","sleep_interval":3600,"status":"idle"}
EOF

# Inbox
ls kb/inbox/release/*.json 2>/dev/null | sort | while read msg; do cat "$msg"; rm "$msg"; done
```

**Trigger manual** (você chama quando quer fazer release):
`/worker release`

Ou roda autonomamente checando se há PRs suficientes desde o último release:
```bash
# Encontrar última tag de release
gh release list --limit 1 --json tagName

# Contar PRs mergeadas desde então
gh pr list --state merged --search "merged:>$(gh release list --limit 1 --json publishedAt -q '.[0].publishedAt')" --json number | jq length
```
Se ≥ 5 PRs mergeadas desde o último release → inicie o ciclo de release.

**Passo 1 — Spawne subagente changelog:**
```
Gere um changelog para o release do repo <url>.

PRs mergeadas desde o último release (<tag anterior>):
<lista de PRs: número, título, corpo>

Agrupe por categoria:
- ✨ Novas funcionalidades
- 🐛 Correções
- 🔒 Segurança
- 🏗️ Infraestrutura
- 📚 Documentação

Para cada item: uma linha clara no formato "- <o que mudou> (#<PR>)"
Foco no impacto pro usuário, não no detalhe técnico.

Retorne o changelog completo em markdown.
```

**Passo 2 — Determinar versão (semver):**
- Tem breaking change? → MAJOR (x+1.0.0)
- Tem feature nova? → MINOR (x.y+1.0)
- Só fixes/ajustes? → PATCH (x.y.z+1)

**Passo 3 — Criar PR de release:**
```bash
git checkout -b release/<versão>

# Atualize version nos arquivos do projeto
# (package.json, pyproject.toml, Cargo.toml — conforme o stack)

git commit -m "chore: release <versão>"
git push origin release/<versão>

gh pr create \
  --title "🚀 Release <versão>" \
  --body "## Release <versão>

<changelog gerado>

---
### Checklist de release
- [ ] Changelog revisado
- [ ] Versão bumped corretamente
- [ ] Testes passando
- [ ] Deploy validado após merge
" \
  --label "area:infra"
```

**Passo 4 — Após merge da PR de release:**
```bash
gh release create <versão> \
  --title "Release <versão>" \
  --notes "<changelog>" \
  --latest
```

**Nunca:** fazer release sem PR revisada. O merge da PR de release é sempre
humano ou pelo `reviewer` — nunca automático.
**Sleep:** após criar PR de release, dorme até próxima vez que threshold for atingido.
