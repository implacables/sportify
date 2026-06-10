# Continuidad de IDs

Operación de limpieza de silver que reconstruye un **track continuo** por jugador ante dos problemas del tracking crudo: los **ID-switches** (un mismo jugador cambia de id, o dos jugadores se intercambian la id tras un cruce/oclusión) y los **cortes** (breaks) en los que el track se interrumpe y reaparece con otra id.

En bronze los IDs llegan **parciales y ruidosos**: hay jugadores sin `user_id` resuelto y tracks que se parten. El objetivo es que, en silver, cada `players[].id` sea estable a lo largo del partido para que las velocidades derivadas y los agregados por jugador apunten siempre a la misma persona.

## Cómo funciona

La operación enlaza fragmentos de track que corresponden al mismo jugador y les asigna una id única y continua. Donde existe `user_id` del roster, ese id ancla la continuidad; donde no, se mantiene un id de track provisional preservando la `position` para que las métricas de equipo cuenten con los 11.

No hay fórmula: es una operación de re-identificación / asociación de tracks. El **algoritmo concreto está abierto** (suavizado, interpolación y re-ID quedan sin especificar en el spec de datos).

## Cómo se usa en Sportify

- Es una de las ocho operaciones de silver y corre **antes** de cualquier métrica de gold; ningún cómputo consume bronze directo.
- Se valida por **degradación sintética**: se inyectan ID-switches (más ruido y huecos) sobre tracking limpio de Metrica, se corre silver sobre la versión degradada y se mide el error contra la verdad limpia.
- Habilita que `velocity` y los agregados por jugador/equipo se calculen sobre identidades consistentes.

**Abierto:** algoritmo concreto de re-ID y umbral de error que valida la operación antes de exponer a gold.
