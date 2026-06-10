# OpenSkill

Motor de rating Bayesiano basado en el modelo **Plackett-Luce**. Es el motor elegido para la rama de rating de Sportify: nativo multi-equipo y multi-jugador, acepta una señal de `margin` que escala el swing del update, y reparte el resultado de equipo a los jugadores individuales.

## Qué es

OpenSkill modela la habilidad de cada jugador como un **rating vector** `(μ, σ)`, no como un número solo:

- **`μ` (mu):** media estimada de la habilidad.
- **`σ` (sigma):** incertidumbre sobre esa media. Alta en jugadores nuevos, baja a medida que se acumula historial.

El valor **servible y ordenable** (leaderboard, balanceo) es el **conservador**, que penaliza la incertidumbre:

```
conservador = μ − 3σ
```

Así, un jugador con μ alta pero σ alta (poco visto) queda por debajo de uno con μ parecida y σ baja (ya consolidado).

## Cómo funciona

Al cerrar un partido, OpenSkill actualiza los `(μ, σ)` de los jugadores según el resultado. Dos piezas lo distinguen de un Elo simple:

- **Margen:** acepta un `margin` por partido que escala cuánto se mueve el rating (el swing). En Sportify ese margen no es la diferencia de goles sino la **dominancia** derivada de analytics (el puente).
- **Reparto a jugadores (partial-play):** el resultado de equipo se reparte a cada jugador ponderando su aporte. Cuando hay analytics, el peso sale de la contribución por jugador; si no, degrada a reparto uniforme.

Para emparejar y predecir, la probabilidad de victoria entre lados se calcula como:

```
P(A gana) = 1 / (1 + Σ exp(μ_B − μ_A))
```

## Por qué se eligió

Frente a un Elo con multiplicador de margen (que necesita una corrección de autocorrelación a mano para que el margen no infle el sistema), OpenSkill trae de fábrica lo que la rama necesita: es nativo multi-equipo/multi-jugador, acepta `margin`, expone el rating como vector `(μ, σ)` con conservador `μ − 3σ`, y reparte a individuos vía partial-play. Glicko-2 queda como referencia para manejar incertidumbre e inactividad, no como motor.

## Cómo se usa en Sportify

- Cada `user_id` guarda su rating `(μ, σ)` y el conservador `μ − 3σ` es lo que ordena el leaderboard y balancea equipos.
- El `margin` del update se alimenta de la **dominancia** de analytics cuando está disponible, y de un margen simple (diferencia de goles) desde el día 1, sin tocar el motor.
- El reparto a jugadores usa partial-play ponderado por contribución, con degradación a uniforme si no hay analytics.
- El emparejamiento on-demand usa `P(A gana)` como criterio de paridad.

La elección concreta de implementación (modelo PL específico, hiperparámetros β/τ, valores iniciales de μ/σ y curva de cold-start) queda **abierta**.

**Fuente:** [openskill.pdf](../../research/papers/rating-matchmaking/openskill.pdf)
