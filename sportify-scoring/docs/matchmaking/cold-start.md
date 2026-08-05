# Cold-start

Cómo arranca el rating de un jugador sin historial —nuevo registrado o invitado— y cómo converge con pocos partidos.

## Qué es

El rating de OpenSkill es un par `(μ, σ)`: `μ` es la media estimada de habilidad y `σ` la incertidumbre sobre esa media. Un jugador sin historial no tiene evidencia, así que arranca con `μ` por defecto y `σ` **alta** (máxima incertidumbre). El valor servible/ordenable es el conservador `μ − 3σ`, que penaliza esa incertidumbre: hasta que junte partidos, el jugador se ordena bajo en el leaderboard aunque su `μ` sea la del promedio.

## Cómo converge

Con `σ` alta, el motor mueve mucho el rating en cada update: los primeros partidos pesan fuerte y `σ` baja a medida que se acumula evidencia. Por eso un jugador nuevo arranca volátil y se estabiliza con pocos partidos, mientras que uno consolidado (σ baja) casi no se mueve por un solo resultado.

```
rating servible = μ − 3σ
nuevo:        σ alta  → swing grande, ordena bajo (mucha penalización)
consolidado:  σ baja  → swing chico, ordena cerca de μ
```

La inversa: si un jugador para mucho tiempo, conviene **inflar `σ`** por inactividad para reflejar que ya no estamos tan seguros de su nivel (referencia: el RD de Glicko-2). El mecanismo y el umbral temporal están **abiertos**.

## Cómo se usa en Sportify

Un **invitado** (slot en el roster sin cuenta) acumula rating "en la sombra" sobre su `user_id` desde el primer partido, con el mismo motor y el mismo cold-start que un registrado. Al reclamar el invitado (registro), ese rating e historial se transfieren sin recomputar. El matchmaking puede armar equipos con un pool mixto de registrados e invitados usando el rating en la sombra.

Los valores concretos del cold-start (μ y σ iniciales) y la curva de inactividad quedan **abiertos**: dependen del modelo Plackett-Luce específico de OpenSkill y de sus hiperparámetros, todavía sin fijar.
