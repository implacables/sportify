# Derivación de velocidades

La velocidad de cada jugador no viene en los datos crudos: la reconstrucción entrega
posiciones por frame, no velocidades. Silver la **deriva** y la guarda como `velocity`
(un `Point2D` en m/s) por jugador en cada frame. Es una de las operaciones de limpieza,
posterior al suavizado, la interpolación de huecos y la normalización a metros del venue.

## Qué es

`velocity` es el vector `(vx, vy)` en m/s que describe hacia dónde y a qué rapidez se mueve
un jugador en ese instante. Se calcula sobre las posiciones ya en metros del venue, así que
el resultado está en unidades físicas y no depende de la resolución del video.

## Cómo funciona

La velocidad se estima por **diferencias finitas**: el desplazamiento entre posiciones
consecutivas dividido por el tiempo transcurrido entre ellas. Como las posiciones tienen
jitter cuadro a cuadro, derivar crudo amplifica el ruido; por eso la derivación apoya en el
suavizado de trayectorias previo (reducir ese jitter antes de diferenciar).

```
v(t) = ( pos(t + Δt) − pos(t − Δt) ) / (2 · Δt)
```

donde `Δt` es el intervalo de tiempo entre muestras, leído del índice temporal del frame
(no se asume 25 fps ni un `frame_stride` fijo). El esquema concreto de suavizado y la ventana
de diferenciación quedan **abiertos**: la implementación de las operaciones de limpieza no
está fijada en esta etapa.

## Cómo se usa en Sportify

La velocidad es insumo de las superficies de valor de gold, en particular **pitch control**:
ahí cada jugador se modela como un proceso de Poisson cuyo alcance en el tiempo depende de su
posición **y** su velocidad —no basta con dónde está, sino hacia dónde va y a qué rapidez.
Sin `velocity` derivada en silver, el campo de control de cancha no se puede computar.

Como Sportify todavía no tiene tracking amateur real, la calidad de esta derivación se valida
degradando tracking limpio de Metrica (ruido, huecos, ID-switches) y midiendo cuánto recupera
silver frente a la verdad limpia.
