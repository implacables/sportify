# Length y width

**Length** y **width** miden cuánto se estira un equipo sobre cada eje de la cancha: el *length* es el rango que ocupan los jugadores sobre el eje largo, y el *width* el rango sobre el eje corto. Son una forma simple de describir qué tan compacto o desparramado está el bloque en cada dirección.

## Cómo funciona

Tomás las posiciones de los jugadores de campo en un frame y proyectás sus coordenadas sobre cada eje del venue. El length es la diferencia entre el jugador más adelantado y el más atrasado sobre el eje largo; el width, lo mismo sobre el eje corto.

```
length = max(x) - min(x)   # rango sobre el eje largo
width  = max(y) - min(y)   # rango sobre el eje corto
```

donde `x` es la coordenada sobre el eje largo de la cancha e `y` sobre el corto, en metros (dimensiones reales del venue).

## Por qué se pueden calcular sin saber la dirección de ataque

Length y width son geométricos: solo dependen de los ejes de la cancha (largo y corto), que son fijos y conocidos, no de hacia qué arco ataca cada equipo. El rango sobre un eje es el mismo sin importar para qué lado se juega. Por eso entran en el grupo de métricas de estructura *direction-agnostic*: no necesitan eventos derivados ni la dirección de ataque, así que son de las primeras y más confiables que se pueden sacar con tracking amateur.

Lo que sí queda **abierto** es cualquier lectura que dependa de la dirección (por ejemplo distinguir "largo defensivo" de "largo ofensivo"): eso requiere saber a qué arco ataca el equipo y se difiere a la capa de eventos derivados.

## Cómo se usa en Sportify

Se calcula por frame sobre el tracking sincronizado (22 + pelota), como parte de las métricas de estructura junto con centroide, stretch index, surface area, team spread y EPS. Sirve para describir la forma del bloque a lo largo del partido y es de las métricas robustas que arrancan la capa de gold.

**Fuente:** [compactness-review-pmc.pdf](../../research/papers/datos-y-metricas/compactness-review-pmc.pdf)
