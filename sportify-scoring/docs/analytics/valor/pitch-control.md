# Pitch control

Campo de probabilidad `[0,1]` que dice, para cada zona de la cancha y en cada instante, qué tan probable es que un equipo controle esa zona. Es una superficie continua: no mira solo dónde está la pelota, sino quién domina cada metro del campo.

## Cómo funciona

Cada jugador se modela como un proceso de Poisson con una tasa `λ` (el inverso del tiempo medio que le toma llegar a hacer un toque controlado en esa zona). La idea: cuanto más rápido puede un jugador llegar y controlar la pelota en un punto, más "control" aporta su equipo sobre ese punto. Se integra en el tiempo y se combinan los aportes de todos los jugadores para obtener la probabilidad por zona.

Para estimar el tiempo de llegada usa **posición + velocidad** de cada jugador (en Sportify la velocidad se deriva en la capa silver). La implementación de referencia es el modelo de **Spearman** (Friends of Tracking).

```
control(zona) = f( Σ_jugador  Poisson(λ_jugador) )
λ_jugador = 1 / tiempo_medio_hasta_toque_controlado(posición, velocidad)
```

La forma exacta de la integral temporal y de la combinación entre jugadores queda **abierta**: depende del detalle del modelo de Spearman, que no está transcripto en las fuentes.

## Cómo se usa en Sportify

Es la superficie base sobre la que se apoyan otras features de valor: alimenta Wide Open Spaces (valor de espacio creado/ocupado) y es el factor `control` dentro de OBSO. Por eso conviene calcularla bien una vez y reutilizarla.

**Fuente:** [../../research/references.md](../../research/references.md)
