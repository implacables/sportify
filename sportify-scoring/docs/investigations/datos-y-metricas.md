# Investigación — Datos y métricas espaciales

**Estado:** referencia factual. Fundamenta la capa de datos (bronze/silver) y las métricas de gold.
**Papers:** [../research/papers/datos-y-metricas/](../research/papers/datos-y-metricas/) · **Bibliografía:** [../research/references.md](../research/references.md)

---

## Estructura de datos — dos modelos complementarios

| Modelo | Qué es | Para qué |
|--------|--------|----------|
| **Tracking por-frame** [ref: `kloppy`] | `Frame` = `timestamp` + `ball_coordinates` (Point3D) + `players_data` (posición por jugador) | análisis espacial continuo |
| **Acciones on-ball (SPADL)** [ref: `socceraction`] | tupla de 12 atributos `(game_id, period_id, seconds, player, team, start_x, start_y, end_x, end_y, action_type, result, bodypart)`; Atomic-SPADL: 11 (saca `result`, suma `dx, dy`) | valor por acción |

Se **sincronizan** por índice de frame/tiempo compartido → cualquier evento derivado se une al estado posicional completo (22 + pelota) en ese instante. SPADL lo **derivamos** internamente, no lo recibimos.

**Coordenadas canónicas:** metros con dimensiones reales del venue (las canchas amateur varían). Helper a `[0,1]` on-demand. Ver [../spec/datos-medallon.md](../spec/datos-medallon.md).

## Métricas de estructura (direction-agnostic — 🟢 robustas) [ref: `compactness`]

```
centroide      = media(x, y) de los jugadores de campo
stretch_index  = media de la distancia euclídea de cada jugador al centroide
surface_area   = área del convex hull del equipo
team_spread    = media de la matriz de distancias entre todos los pares
length / width = rango sobre el eje largo / corto de la cancha
EPS            = convex hull de AMBOS equipos (espacio efectivo de juego)
```

No requieren saber la dirección de ataque → son las primeras y más confiables con tracking amateur.

## Métricas tácticas (requieren eventos derivados — 🟡)

- **PPDA** (presión) [ref: `ppda-packing`]: `pases_completados_rival / acciones_defensivas_propias`, en el 60% de cancha lejos del arco propio. Interpretación: 4–8 presión alta · 9–12 bloque medio · 13+ bloque bajo.
- **Line-breaking passes** [ref: `line-breaking`]: pase que acerca la pelota ≥10% al arco rival y cruza una línea de defensores (detección por clustering de líneas).
- **Packing**: nº de oponentes superados por pase/conducción.

> Estas dependen de la **capa de eventos derivados** (SPADL) y de la dirección de ataque → se difieren respecto de las de estructura.
