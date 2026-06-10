# Base de datos (MongoDB)

Sportify usa **una sola base NoSQL (MongoDB)** como system-of-record de todo lo servible y operacional: identidad, ratings, partidos, reportes y leaderboard. Es el punto de encuentro entre el backend Go y los workers Python: ninguno llama al otro por red, se coordinan a través del store.

## Qué guarda y qué no

A escala amateur/tesis Mongo solo cubre todo lo que la app necesita leer: leaderboard (`sort` + índice), realtime (change streams) y la cola de jobs (una colección). Redis queda como add-on futuro si la escala lo pide (YAGNI).

Los **frames crudos (bronze)** y el **dato limpio (silver)** del medallón **nunca** entran a la base: viven como archivos **parquet** en el VPS. Solo la capa **gold** (métricas, dominancia, agregados servibles) se persiste en Mongo.

## Modelado por patrón de acceso

Las colecciones se modelan por cómo se leen, no por normalización: se embebe lo que se lee junto y se referencia lo compartido. El rating de un usuario vive en su propio documento `user` para permitir update atómico por documento. Las relaciones many-to-many (usuario × partido × equipo) se modelan con una colección de unión.

| Colección | Guarda |
|-----------|--------|
| `users` | perfil + rating actual |
| `teams` | refs a usuarios |
| `matches` | metadata + estado del partido |
| `match_participations` | user × match × team × stats (el "join") |
| `analytics_reports` | un documento por partido |

## Cómo se usa en Sportify

El backend Go encola el trabajo en una colección de jobs; los workers Python lo consumen, escriben gold a Mongo y crudo/limpio a parquet, sin notificar a Go por red. Go puede observar los cambios de estado vía change streams en vez de hacer polling. La app móvil solo habla con Go: nunca toca los workers ni el store directamente.

El esquema exacto de cada colección (índices, embebido vs ref) queda **abierto**.
