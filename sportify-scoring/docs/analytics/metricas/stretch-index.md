# Stretch index

El **stretch index** mide qué tan estirado o compacto está un equipo en un instante dado. Es la media de la distancia de cada jugador de campo al centroide del equipo. Un valor alto indica un equipo desplegado/estirado; uno bajo, un equipo compacto y junto.

Es una métrica de estructura *direction-agnostic*: no necesita saber hacia qué arco ataca el equipo, así que es de las primeras y más confiables de calcular con tracking amateur.

## Cómo funciona

Primero se calcula el **centroide** del equipo (la media de las posiciones `x, y` de los jugadores de campo). Después se promedia la distancia euclídea de cada jugador a ese centroide.

```
centroide     = media(x, y) de los jugadores de campo
stretch_index = media de la distancia euclídea de cada jugador al centroide
```

## Uso en Sportify

Se calcula por frame sobre el modelo de tracking por-frame (cada `Frame` trae la posición de cada jugador), usando coordenadas en metros con las dimensiones reales del venue. Al ser direction-agnostic, entra en la capa de métricas de estructura de gold, que son las primeras y más robustas con tracking amateur.

Queda **abierto** cómo se agrega el valor por-frame a nivel de partido (media, percentiles, evolución temporal) y qué umbrales de interpretación aplican para fútbol amateur.

**Fuente:** [compactness-review-pmc.pdf](../../research/papers/datos-y-metricas/compactness-review-pmc.pdf)
