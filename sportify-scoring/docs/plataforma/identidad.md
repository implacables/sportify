# Identidad

Quién es cada jugador del partido. Una detección del video se asocia a un `user_id`, que puede estar **registrado** o ser **invitado**.

## Cómo funciona

- **Registrado** → tiene cuenta, perfil, rating y aparece en el leaderboard.
- **Invitado** → jugador detectado sin cuenta; ocupa un slot en el roster y se le guarda un rating "en la sombra".

Cuando un invitado se registra, **reclama** ese historial: el rating en la sombra se activa y pasa a ser el suyo.

## Cómo se usa en Sportify

El `user_id` es lo que ata el video con las personas: el rating, el leaderboard y la contribución por jugador se cuelgan de ahí. En amateur no todos tienen cuenta, así que el modelo registrado/invitado permite empezar a medir a alguien antes de que se sume a la plataforma.

Queda **abierto** cómo se reconcilia el equipo del cluster de visión (`a|b`) con el equipo real del roster, y cómo arranca el rating de un invitado (ver [cold-start](../matchmaking/cold-start.md)).
