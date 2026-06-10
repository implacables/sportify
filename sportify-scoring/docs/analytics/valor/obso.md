# OBSO

**OBSO (Off-Ball Scoring Opportunity)** mide el peligro de un espacio ocupado **sin** la pelota: la probabilidad posterior de marcar en el próximo evento on-ball desde cada zona de la cancha. En vez de mirar al que tiene la pelota, mira a dónde están parados los demás y cuánto valdría que la pelota llegue ahí.

## Cómo funciona

Es una superficie de valor continua sobre toda la cancha, evaluada en cada instante. Se construye descomponiendo el peligro en tres factores que se multiplican zona por zona:

- **control** — pitch control: probabilidad de que el equipo controle esa zona.
- **transición** — a dónde va a ir la pelota (probabilidad de que el próximo evento ocurra en esa zona).
- **score** — probabilidad de gol si se tira desde esa zona.

## Fórmula

```
OBSO = control × transición × score
     (pitch control × dónde va la pelota × prob. de gol desde esa zona)
```

## Cómo se usa en Sportify

OBSO es una de las superficies de valor que alimenta las features de valor (gold) y el score de dominancia. Apoyado en pitch control, permite valorar el posicionamiento ofensivo sin pelota: un jugador que ocupa una zona de OBSO alto está generando peligro aunque no toque la pelota. La calibración fina del factor `score` y la integración con el resto de superficies queda **abierta**.

**Fuente:** [../../research/references.md](../../research/references.md)
