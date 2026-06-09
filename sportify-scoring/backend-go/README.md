# backend-go — API de servicio (Go)

Backend que sirve a la app móvil: auth, identidad, rosters, leaderboard, ciclo de vida del partido, pedir matchmaking y servir reportes. La app habla **solo** con esto. Ver [../docs/architecture.md](../docs/architecture.md) §4, §6.

> **Lenguaje:** Go — binario único, ideal VPS-first ([ADR-004](../docs/decisions/log.md)).

## Estructura (monolito modular por dominio)

```
cmd/server/        # entrypoint del binario
internal/
├── identidad/     # usuarios, equipos, rosters, auth
├── partidos/      # ciclo de vida del partido, orquestación
├── ratings/       # rating + leaderboard (servir)
├── matchmaking/   # emparejamiento on-demand
└── analytics/     # servir reportes de "cómo jugó el equipo"
```

**Disciplina ([ADR-007](../docs/decisions/log.md)):** cada módulo es dueño de sus colecciones y se expone por interfaz; no toca las tripas de otro. Así se puede extraer como microservicio más adelante.

## Entorno (pendiente)

Go no está instalado todavía. Una vez instalado:

```bash
go mod tidy
go run ./cmd/server
```

## Estado

⬜ Esqueleto creado (módulos vacíos). Se construye después de la base de datos y los primeros datos. Ver [../docs/roadmap.md](../docs/roadmap.md) (INFRA1).
