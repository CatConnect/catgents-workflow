---
name: pr
description: >
  Prove que a feature funciona antes de abrir a PR — um subagente verificador
  independente dirige o app real e julga o resultado. Use quando uma mudança
  está pronta para ship: "abrir PR", "fazer PR", "enviar PR", "/pr", "ship
  isso", "verificar antes de mergear". Nunca abre PR sem verificação.
---

# /pr — prove que funciona, depois abre a PR

> *"Um cat não traz presa duvidosa pra dentro de casa."*

Você é o **orquestrador + corretor**. A verificação se divide em duas partes:

- **"A feature faz o que deveria fazer?"** → subagente **verificador independente**
  que dirige o app real. Ele não escreveu o código — portanto pode julgá-lo.
- **"Os checks objetivos passam?"** → você mesmo roda (type-check, lint, testes
  existentes). Erro passa diretamente pra você corrigir — delegar não agrega nada.

---

## Pré-condições

- Você está numa branch (não na main/master)
- Mudanças estão commitadas
- Você sabe qual feature foi implementada e o que ela deveria fazer

---

## Passo 1 — Subir a stack

Use o launcher do repo se existir:
```bash
bash scripts/dev-local.sh up   # se configurado com dev-local
# ou o comando de dev do projeto
```

A stack deve estar rodando antes de spawnar o verificador. Você é dono dela
— o verificador reutiliza, não sobe outra.

---

## Passo 2 — Verificar a feature (subagente independente)

Spawne um verificador que **não leu o código** — ele só dirige o app:

```
Você é um verificador independente. NÃO edite código. NÃO pergunte.

FEATURE que deve funcionar (o que o usuário deve conseguir fazer agora):
<descreva o comportamento esperado — user story ou acceptance criteria>

COMO EXERCITAR:
<URL ou comando de entrada + passos específicos>

AUTH (se necessário):
<como criar sessão de teste ou credenciais de dev>

Sua tarefa:
1. Acesse o app rodando localmente
2. Execute os passos acima exatamente
3. Capture evidência do resultado (screenshot, output, log)
4. Julgue: o comportamento observado bate com o esperado?

Retorne APENAS:

FEATURE: funcionando | quebrada
  esperado: <critério>
  observado: <o que aconteceu de fato>
  evidência: <onde está a prova>
```

**Se quebrada:**
- Corrija a implementação
- Spawne um **novo** verificador (fresco, sem memória da tentativa anterior)
- Limite: 3 rodadas. Se ainda quebrada após 3, escale pro humano com o relatório

**Você nunca declara que a feature funciona — apenas o verificador independente pode.**

---

## Passo 3 — Checks objetivos (você mesmo roda)

Após verificação aprovada:

```bash
# Type-check
npx tsc --noEmit | mypy . | go vet ./...

# Lint
npm run lint | ruff check . | golangci-lint run

# Testes existentes (regressão)
npm test | pytest | go test ./... | cargo test
```

Se algum falhar:
- **Bug real** → corrija o código, re-verifique feature se afetada
- **Teste stale** (o contrato mudou intencionalmente) → atualize o teste
- **Nunca enfraqueça assertion só pra ficar verde**

---

## Passo 4 — Abrir a PR com prova

```bash
gh pr create \
  --title "<título conciso da feature>" \
  --body "$(cat <<'EOF'
## O que mudou
<1-3 linhas do que foi implementado>

## Feature verificada ✅
- <critério de aceitação> — observado funcionando
- Verificador independente confirmou o comportamento

## Regressão
- [x] type-check
- [x] lint
- [x] testes existentes

## Como reproduzir
\`\`\`bash
<comando pra subir a stack>
\`\`\`
<passos pra exercitar a feature>

Closes #<N>
EOF
)"
```

---

## Regras

- Feature verificada vem antes de qualquer check objetivo — um suite verde com
  feature quebrada não é done
- O verificador deve ser independente: não leu o código, não faz parte desta sessão
- Nunca abra PR sem verificação aprovada
- Prova, não afirmação — o PR deve mostrar evidência, não apenas declarar que funciona
