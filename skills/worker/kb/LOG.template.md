# LOG

Registro cross-worker de atividade. Workers leem as últimas 10 entradas
antes de agir e appendam após concluir trabalho relevante.

Formato de entrada:
```
## YYYY-MM-DD · <worker> · <ação resumida> · #tags
O que: <uma linha do que foi feito ou encontrado>
Refs: [[signal-slug]], #issue-N, #pr-N
```

---

<!-- entradas abaixo, mais recente primeiro -->
