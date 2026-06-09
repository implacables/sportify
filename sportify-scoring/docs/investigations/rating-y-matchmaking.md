# Investigación — Rating y matchmaking

**Estado:** referencia factual. Fundamenta la rama de matchmaking y el puente de dominancia.
**Papers:** [../research/papers/rating-matchmaking/](../research/papers/rating-matchmaking/) · **Bibliografía:** [../research/references.md](../research/references.md)

---

## Tres sub-problemas encadenados

1. **Señal de dominancia** del partido (¿goles? ¿analytics?).
2. **Update del rating** de equipo (cómo el margen escala el swing).
3. **Reparto a jugadores** individuales.

## Margen escalando el swing

**Opción A — Elo con multiplicador de margen** [ref: `elo-mov`]:

```
E_win = 1 / (1 + 10^(-Δ/400))                      # prob. esperada
mult  = ln(|MOV| + 1)                              # multiplicador por margen
corr  = 2.2 / ((Elo_win − Elo_los)·0.001 + 2.2)    # corrección de autocorrelación
nuevo = viejo + K · mult · corr · (S − E_win)
```

`corr` es la pieza no obvia: sin ella el margen infla el sistema.

**Opción B — OpenSkill (Plackett-Luce)** [ref: `openskill`] — **elegido**: nativo multi-equipo/multi-jugador, acepta `margin`, rating vector multidimensional, reparto vía partial-play. Conservador = `μ − 3σ`; `P(A gana) = 1/(1 + Σ exp(μ_B − μ_A))`. Glicko-2 [ref: `glicko2`] como referencia para incertidumbre/inactividad.

## El puente — contribución original de la tesis

En vez de alimentar el margen con **diferencia de goles** (ruidosa en amateur), se alimenta con un **score de dominancia derivado de analytics**:

```
dominancia = w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + w4·Δfield_tilt
```

Un equipo que **mereció** ganar (dominó espacio/peligro) sube fuerte aunque sea 1-0; un 3-0 con suerte no infla tanto. Los pesos `w1..w4` se calibran empíricamente.

## Reparto a jugadores

OpenSkill reparte el resultado de equipo a individuos. Se afina con **partial-play weighting** ponderado por **contribución derivada del tracking** (VAEP/EPV por jugador) [ref: `epv`]: un crack en un equipo que pierde, pierde menos; un pasajero en uno que gana, gana menos.
