# Wide Open Spaces

Mide el **valor del espacio creado u ocupado** sobre la cancha, tanto a nivel de equipo como de jugador individual, y sirve con pelota y sin pelota. La idea es ponerle número a algo que normalmente se ve "a ojo": cuánto espacio peligroso genera un jugador al desmarcarse o cuánto ocupa el equipo al abrir la cancha.

## Cómo funciona

Se apoya en **pitch control**: la superficie continua de probabilidad `[0,1]` de qué equipo controla cada zona en cada instante. Sobre esa base, Wide Open Spaces pondera el espacio según un **modelo de probabilidad de recepción** — no todo el espacio controlado vale igual, vale más el que efectivamente podría recibir un pase.

Así, el valor de un jugador no es solo el espacio que pisa, sino el espacio que habilita: el que abre para que un compañero reciba.

## Fórmula

Cómo se combina exactamente el pitch control con la probabilidad de recepción para arrojar el valor final queda **abierto** en la fuente disponible (la investigación describe el concepto, no la ecuación cerrada).

## Cómo se usa en Sportify

- Alimenta las **features de valor** y el score de dominancia: cuánto espacio peligroso domina cada equipo a lo largo del partido.
- Permite atribuir valor **a nivel jugador**, incluyendo el aporte sin pelota (desmarques, arrastres, apertura de cancha) que el conteo de eventos no captura.
- Al derivarse de pitch control, depende de posición y velocidad de los jugadores, igual que las demás superficies de valor.

**Fuente:** [../../research/papers/superficies-de-valor/wide-open-spaces.pdf](../../research/papers/superficies-de-valor/wide-open-spaces.pdf)
