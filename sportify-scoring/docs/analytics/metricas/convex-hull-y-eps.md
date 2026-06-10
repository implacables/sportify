# Convex hull, surface area y EPS

El **convex hull** (envolvente convexa) es el polígono más chico que encierra a un conjunto de puntos. En tracking, los puntos son las posiciones de los jugadores en un frame. A partir de él salen dos métricas espaciales.

## Surface area

Es el área del convex hull de **un** equipo: el polígono que envuelve a sus jugadores de campo. Mide cuánto espacio ocupa el equipo en ese instante. Un área grande indica un equipo estirado/abierto; un área chica, un equipo compacto.

## EPS — espacio efectivo de juego

El **EPS** (effective playing space) es el convex hull de **ambos** equipos juntos: el polígono que envuelve a los 22 jugadores de campo. Representa el espacio efectivo donde se está jugando en ese frame.

## Cómo se calcula

```
surface_area = área del convex hull del equipo
EPS          = área del convex hull de AMBOS equipos
```

Ambas son **direction-agnostic**: no necesitan saber hacia qué arco ataca cada equipo, así que son de las métricas más robustas y de las primeras que se pueden computar con tracking amateur. Solo dependen de las posiciones por frame que ya entrega la capa de tracking.

## Uso en Sportify

Surface area y EPS forman parte de las métricas de estructura que se derivan directo del tracking por-frame, sin depender de eventos ni de la dirección de ataque. Sirven como base confiable del análisis espacial.

> **Fuente a confirmar:** el documento de origen (compactness review) respalda surface area y EPS como convex hull de equipo / de ambos equipos, pero la atribución exacta de `team_spread` y de la definición precisa de EPS a esa fuente queda **abierta** y pendiente de verificar.

**Fuente:** [compactness review](../../research/papers/datos-y-metricas/compactness-review-pmc.pdf)
