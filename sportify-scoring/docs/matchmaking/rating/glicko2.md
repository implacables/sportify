# Glicko-2 (referencia)

Glicko-2 es un sistema de rating que, además del número de skill, modela cuánta confianza hay en ese número. A cada jugador le asigna tres cantidades:

- **Rating** — la estimación de habilidad.
- **RD (Rating Deviation)** — la incertidumbre sobre ese rating. RD bajo = sabemos bastante; RD alto = poca información o mucho tiempo sin jugar.
- **Volatilidad (σ)** — qué tan erráticos vienen siendo los resultados del jugador. Una racha inconsistente sube σ, lo que permite que el rating se mueva más rápido.

## Cómo funciona

Se trabaja sobre una escala interna (μ, φ) y se traduce a rating/RD para mostrar. La idea central:

```
# escala interna
μ  = (rating − 1500) / 173.7178
φ  = RD / 173.7178

# la incertidumbre crece con el tiempo de inactividad
φ* = sqrt(φ² + σ²)        # RD se infla entre periodos sin jugar

# tras los partidos del periodo, μ y φ se actualizan hacia los
# resultados observados; φ baja al jugar (más información)
```

Lo clave para Sportify: **el RD se infla con la inactividad** (vía σ entre periodos). Un jugador que estuvo meses sin jugar vuelve con más incertidumbre, así que su rating se ajusta más rápido cuando reaparece, en vez de quedar congelado en un valor viejo.

## Cómo se usa en Sportify

Glicko-2 es **1v1** y no es el sistema elegido (va OpenSkill, que es nativo multi-equipo/multi-jugador). Se toma como **referencia conceptual**: el par incertidumbre + manejo de inactividad. En el fútbol amateur la asistencia es irregular —gente que juega esporádico, equipos que se arman distinto cada fecha—, así que la noción de "qué tan seguros estamos del rating de este jugador" y de inflar esa incertidumbre con el tiempo es lo que se quiere trasladar al modelo de OpenSkill (donde σ cumple un rol análogo).

Queda **abierto** cómo se mapea exactamente el manejo de inactividad de Glicko-2 a la σ de OpenSkill en la implementación de Sportify.

**Fuente:** [glicko2.pdf](../../research/papers/rating-matchmaking/glicko2.pdf)
