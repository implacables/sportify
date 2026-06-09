# Especificación — Arquitectura

**Estado:** decisiones tomadas (ver [../decisions/log.md](../decisions/log.md)). Esta es la parte normativa; el porqué de cada elección está en los ADR.

Ver también: [contratos.md](contratos.md) (entrada/salida) · [datos-medallon.md](datos-medallon.md) (capas de datos).

---

## Stack

| Pieza | Tecnología | Rol |
|-------|-----------|-----|
| Backend | **Go** | API que sirve a la app móvil. Binario único, VPS-friendly. La app habla solo con esto. |
| Workers | **Python** | analytics (medallón) + update del rating. El ecosistema de football analytics es Python-only. |
| Base | **MongoDB** | única base NoSQL: identidad, ratings, partidos, reportes, leaderboard. |
| Frames crudos | **parquet** (archivos) | bronze/silver — nunca en la base. |

**Go sirve; Python procesa. Se encuentran en el store** (no se hablan directo). El update del rating corre en el worker Python; el emparejamiento on-demand, en Go.

## Arquitectura de código — monolito modular

Monolito ahora, **divisible después** (microservices-ready). No microservicios todavía.

- **Backend Go = un servicio**, modular por dominio: `identidad`, `partidos`, `ratings`, `matchmaking`, `analytics`.
- **Workers Python = un pipeline**, modular por etapa del medallón: `bronze`, `silver`, `gold`, `rating`.

**Disciplina:** cada módulo es dueño de sus datos y se expone por interfaz; no toca las colecciones de otro. Así se puede extraer como servicio más adelante.

## Base de datos — MongoDB

Una sola base NoSQL. A escala amateur/tesis cubre leaderboard (`sort`+índice), realtime (change streams) y jobs (colección). Redis = add-on futuro si la escala lo pide.

**Modelado:** por patrón de acceso, no por normalización. Embeber lo que se lee junto; referenciar lo compartido; updates atómicos por documento (el rating vive en el doc del `user`); many-to-many vía colección de unión.

| Colección | Guarda |
|-----------|--------|
| `users` | perfil + rating actual |
| `teams` | refs a usuarios |
| `matches` | metadata + estado del partido |
| `match_participations` | user × match × team × stats (el "join") |
| `analytics_reports` | un documento por partido |

## Identidad

`user_id` **registrado o invitado**. Registrado → cuenta, perfil, rating, leaderboard. Invitado → slot en el roster sin cuenta; rating "en la sombra" que se activa y reclama al registrarse.
