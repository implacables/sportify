# Backend (Go)

El backend es el servicio en Go que le da la cara a la app móvil. Es la **única superficie pública** de la plataforma: la app habla solo con esto, nunca con los workers de Python ni con el store directamente.

## Qué hace

Sirve todo lo que la app necesita pedir o leer:

- **Auth e identidad** — cuentas, login, y el modelo de invitado (un `user_id` con slot en el roster, sin cuenta, con un rating "en la sombra" reclamable cuando esa persona se registra).
- **Perfiles** — perfil del usuario con su rating actual.
- **Leaderboard** — ranking ordenado (Mongo lo resuelve con `sort` + índice).
- **Pedir matchmaking** — el emparejamiento se resuelve acá, en Go, on-demand. (El que sí corre en el worker Python es el *update* del rating, no el armado del partido.)
- **Servir reportes** — entrega el reporte de analytics por partido desde el store.

## Cómo funciona

Es un **binario único** que corre en el VPS, sin runtime externo y sin egress a cloud. Por dentro es un monolito modular: dominios separados (`identidad`, `partidos`, `ratings`, `matchmaking`, `analytics`), cada uno dueño de sus datos, con las fronteras limpias para poder extraer un módulo como servicio más adelante sin reescribir su contrato.

No llama a los workers por red. La coordinación pasa **a través del store** (MongoDB): Go encola el trabajo a procesar (p. ej. una colección de jobs), los workers lo consumen de ahí, y escriben los resultados servibles de vuelta en Mongo. Go puede enterarse de los cambios de estado observando change streams en vez de hacer polling.

```text
app_movil  --> backend_go            # única superficie pública
backend_go --> mongo.jobs            # encola trabajo
backend_go <-- mongo (change streams) # observa estado
```

## En Sportify

Es el punto donde se cierra el círculo: los workers procesan el tracking del partido y dejan el dato servible (gold) en Mongo; el backend lo lee y se lo muestra a la app como leaderboard, perfil o reporte. El rating vive en el documento `user` de cada uno, lo que permite updates atómicos por documento.

**Abierto:** el mecanismo exacto de coordinación de jobs (colección de jobs vs. change streams vs. ambos, y la forma del descriptor de job) está sin cerrar.
