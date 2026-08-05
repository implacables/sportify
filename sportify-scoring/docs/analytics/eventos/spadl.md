# SPADL (acciones)

SPADL (Soccer Player Action Description Language) es un formato unificado para describir las **acciones on-ball** de un partido: pases, conducciones, tiros, despejes, etc. Cada acción es una tupla de **12 atributos** que la ubica en tiempo, espacio y autor.

```
(game_id, period_id, seconds, player, team,
 start_x, start_y, end_x, end_y,
 action_type, result, bodypart)
```

La variante **Atomic-SPADL** usa **11 atributos**: saca `result` y agrega el desplazamiento `(dx, dy)`. En lugar de marcar éxito/fracaso por acción, modela el movimiento de la pelota como una secuencia atómica.

En Sportify SPADL no lo recibimos como dato de entrada: lo **derivamos** internamente desde el tracking por-frame. Cada acción se sincroniza por índice de frame/tiempo compartido, así que cualquier acción se une al estado posicional completo (22 jugadores + pelota) en ese instante.

Es la **capa de eventos derivados** sobre la que se apoyan las métricas tácticas (las de estructura/espaciales no la necesitan). Habilita, entre otras:

- **PPDA** (presión): `pases_completados_rival / acciones_defensivas_propias`.
- Valoración de acciones (valor por acción) y métricas como line-breaking passes y packing.

Como depende de la dirección de ataque y de la calidad del tracking amateur, su disponibilidad se **difiere** respecto de las métricas de estructura, que son las primeras y más confiables.

**Fuente:** [../../research/references.md](../../research/references.md)
