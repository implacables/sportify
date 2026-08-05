# Emparejamiento on-demand

Armar dos equipos parejos a pedido, a partir de un pool de jugadores y sus ratings. Vive en el backend Go: se dispara cuando el usuario lo pide, se resuelve en el momento y no corre como worker batch ni toca el worker Python de rating.

## Qué es

Dado un pool de `user_id` (registrados e invitados mezclados), el emparejamiento reparte a los jugadores en `team_a` y `team_b` buscando que el partido sea parejo. La señal que usa es el rating de cada jugador; el invitado entra con su rating "en la sombra", igual que un registrado.

## Cómo funciona

Cada jugador trae un rating OpenSkill `(μ, σ)`. Para balancear no se usa `μ` crudo sino el **valor conservador** `μ − 3σ`, el mismo que ordena el leaderboard: penaliza la incertidumbre, así un jugador nuevo con σ alta no infla un equipo.

La partición se evalúa con la predicción de victoria que da el motor entre los dos lados armados:

```
P(A gana) = 1 / (1 + Σ exp(μ_B − μ_A))
```

El objetivo es repartir el pool minimizando la diferencia esperada de skill entre lados, o sea acercando `P(A gana)` a 0.5. Un pool parejo debería devolver una partición con `P(A gana)` cerca de 0.5.

## Cómo se usa en Sportify

La app le pide al backend Go un emparejamiento sobre un pool. Go lee los ratings vigentes de `users`, arma la partición y devuelve los dos equipos con su `P(A gana)` por lado:

```json
{
  "teams": {
    "team_a": ["usr_abc123", "usr_jkl012"],
    "team_b": ["usr_def456", "usr_ghi789"]
  },
  "predicted_win_prob": { "team_a": 0.52, "team_b": 0.48 }
}
```

Debería responder en tiempo interactivo para un pool de tamaño amateur; el umbral exacto de latencia queda abierto.

El objetivo y el algoritmo concretos de partición quedan **abiertos**: la función de balance exacta (min Δrating contra `P(A gana)`≈0.5), el tamaño de equipo según el formato (fútbol 5/7/11), el balance de roles o posiciones y el algoritmo de partición todavía no están fijados.
