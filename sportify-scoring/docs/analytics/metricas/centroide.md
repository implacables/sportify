# Centroide

El **centroide** de un equipo es el "centro de gravedad" posicional: el punto promedio de los jugadores de campo en un instante dado. Es la métrica de estructura más básica y, como no necesita saber hacia qué arco ataca el equipo (es *direction-agnostic*), es de las primeras y más confiables que se pueden calcular con tracking amateur.

## Cómo se calcula

Se toma la posición `(x, y)` de cada jugador de campo en un frame y se promedia. Quedan afuera los arqueros, que distorsionarían la media al estar pegados al arco.

```
centroide = media(x, y) de los jugadores de campo
```

Es un valor por frame: a lo largo del partido el centroide se mueve, y esa trayectoria describe cómo el equipo sube, baja y se desplaza lateralmente en bloque.

## Qué dice tácticamente

- **Posición del bloque:** un centroide adelantado indica un equipo que juega alto (presión/dominio de campo); uno retrasado, un equipo metido atrás.
- **Movimiento colectivo:** seguir el centroide en el tiempo muestra las subidas y repliegues del equipo como unidad.
- **Base de otras métricas:** el centroide es el ancla del `stretch_index`, que mide la dispersión promediando la distancia euclídea de cada jugador a este punto. Sin centroide no hay stretch index.

## Uso en Sportify

Se computa por frame a partir del tracking posicional (modelo `Frame` con la posición de cada jugador), usando coordenadas canónicas en metros con las dimensiones reales del venue. Al ser direction-agnostic, entra en la capa de métricas de estructura que Sportify prioriza por ser robustas con datos amateur, sin depender de la dirección de ataque ni de eventos derivados.

**Fuente:** [compactness-review-pmc.pdf](../../research/papers/datos-y-metricas/compactness-review-pmc.pdf)
