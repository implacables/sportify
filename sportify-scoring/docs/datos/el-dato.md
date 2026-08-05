# El dato que recibimos

La reconstrucción nos entrega **una sola cosa**: posiciones per-frame del partido (jugadores y pelota sobre la cancha). No nos importa acá cómo las saca del video; ese es otro sistema. Lo que importa es la forma del dato que cae de ese lado.

## El modelo `Frame`

Sobre ese stream per-frame definimos un modelo canónico, vendor-independiente: el **`Frame`**. Cada `Frame` es una muestra del estado del juego en un instante, con tres cosas:

- `timestamp` — índice temporal de la muestra (segundos o `frame_index`). Sirve para sincronizar con cualquier evento derivado más adelante.
- `ball` — posición de la pelota como `Point3D` `(x, y, z)`.
- `players[]` — un entry por jugador en cancha, cada uno con su `position` como `Point3D`.

La clave: **todo está en metros del venue**. No en píxeles, no en `[0,1]`, no en una cancha estándar. Metros reales, con las dimensiones físicas de esa cancha (las amateur varían). Si en algún punto necesitamos normalizar a `[0,1]`, lo hacemos on-demand desde las dimensiones del venue; no lo persistimos como forma canónica.

La otra clave: el `Frame` es **agnóstico al `frame_stride`**. No asume 25 fps ni ninguna cadencia fija. El `frame_stride` (cada cuántos frames de video se emite una muestra) vive río arriba; nada de nuestro lado debe asumir un valor. Por eso el índice temporal es lo que une las muestras, no un fps implícito.

## Cómo se usa en Sportify

El `Frame` es la unidad sobre la que corre todo lo de scoring: a partir de la serie de `Frame`s salen las métricas de estructura (centroide, spread, surface area) y, con la pelota, el valor on-ball. Que sea metros-del-venue y stride-agnóstico es lo que hace que esas métricas no dependan ni de la cancha ni de la cadencia del video.

## Abierto

- Cómo se representa un jugador **no-identificado** (sin `user_id`) preservando su `position` para que cuente en las métricas de equipo.
- El **origen de coordenadas** del venue (centro vs esquina), que debe alinearse con la convención de río arriba.
