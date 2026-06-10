# Score de dominancia

El score de dominancia mide **cuánto mereció ganar** un equipo, derivado de analytics y no de la diferencia de goles. Un equipo que dominó el espacio y el peligro sube fuerte aunque haya ganado 1-0; un 3-0 con suerte no infla tanto. Es la salida de la capa de analytics (gold) y el insumo del **puente**: alimenta el `margin` del rating en vez de la diferencia de goles, que en el fútbol amateur es demasiado ruidosa.

## Cómo funciona

Es una combinación lineal ponderada de **deltas** entre equipos (la diferencia A−B de cada término, agregada al nivel de partido). Cada término aporta una dimensión distinta del mérito:

- **ΔxG** — diferencia de peligro generado.
- **Δpitch_control** — diferencia de control del espacio.
- **ΔEPV** — diferencia de valor de posesión.
- **Δfield_tilt** — diferencia de presencia/peligro en el tercio rival.

```text
dominancia = w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + w4·Δfield_tilt
```

Los pesos `w1..w4` se calibran empíricamente, no se fijan a priori. La composición, normalización y calibración del score quedan **abiertas**.

El score se computa sobre los términos **disponibles**: cuando a un término le falta el insumo, se omite y se deja registro de cuáles entraron. Hoy `Δfield_tilt` queda **parkeado** porque requiere dirección de ataque, que está fuera del contrato de entrada (`w4 = 0`); `ΔxG` y `ΔEPV` dependen de pelota/SPADL y se difieren con ellos. Con tracking amateur de día 1, la dominancia puede sostenerse sobre `Δpitch_control` (disponible sin pelota ni dirección) más las métricas de estructura. Cada término y su peso se reportan por separado, para que el score sea interpretable.

## Cómo se usa en Sportify

La dominancia por equipo es el **puente**, la contribución original de la tesis: en lugar de alimentar el rating con la diferencia de goles, lo alimenta con este score. El módulo de rating lo consume como `margin` (OpenSkill, multi-equipo/multi-jugador), y de ahí el resultado de equipo se reparte a jugadores afinado con la contribución derivada del tracking (VAEP/EPV por jugador). El método exacto de reparto a jugadores queda **abierto**.
