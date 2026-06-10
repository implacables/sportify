# Asignación de equipo

Una de las operaciones de limpieza de silver: a cada jugador de un `Frame` se le asigna un `team`, codificado como enum `a` | `b`. Es paso obligatorio antes de habilitar gold, porque las métricas de estructura (centroide, stretch index, surface area, team spread) necesitan saber qué jugadores forman cada equipo.

## Cómo funciona

El enfoque de base es **clustering por color de camiseta**: agrupar los jugadores detectados en dos clusters según el color dominante de su camiseta, y rotular cada cluster como `a` o `b`. Esto sale de la visión y no depende de identificar a cada jugador individualmente, así que sirve incluso cuando no se resolvió el `user_id` de un dorsal.

El resultado queda persistido en el frame silver:

```json
{ "id": "usr_abc123", "team": "a", "position": { "x": 34.2, "y": 12.8, "z": 0.0 } }
```

## Cómo se usa en Sportify

`team` es lo que permite que gold compute las métricas espaciales por equipo: separás los 11 de cada lado y recién ahí calculás centroide, spread y demás. Por eso la asignación corre en silver, antes de cualquier métrica, y debe cubrir también a los jugadores sin `user_id` (alcanza con que la métrica de equipo cuente con los 11).

## Abierto

El **método concreto está abierto**. Las opciones en juego son: clustering por color de camiseta, usar el roster real del upstream, u otro enfoque. El problema central es la **reconciliación con el roster real**: el cluster `a` | `b` de visión es solo "estos van juntos / aquellos van juntos", no te dice qué equipo del partido real es cada uno ni qué `user_id` corresponde a cada track. Cómo conciliar el rótulo de cluster con la identidad del roster (y con la política de identidad del upstream para jugadores no-identificados) queda sin resolver en esta versión.
