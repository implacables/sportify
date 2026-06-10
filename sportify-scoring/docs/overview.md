# Overview — Scoring & Matchmaking

**Stage:** thesis — designing. Sistema **separado** del POC de reconstrucción; consume su contrato per-frame.

Mide el skill de los jugadores desde el tracking del partido (analytics) y los empareja parejo (matchmaking). El aporte original: emparejar con **visión por computadora** en vez de evaluación subjetiva.

## Dos ramas + un puente

```
🎥 video ─→ [reconstrucción] ─→ reconstruction.json
                    │
                    ▼
🌳 RAMA B — ANALYTICS (medallón: 🥉bronze → 🥈silver → 🥇gold)
   produce: SCORE DE DOMINANCIA + contribución por jugador
                    │
       (dominancia) │──🌉──→ 🌳 RAMA A — MATCHMAKING
                    │          rating OpenSkill + margen → leaderboard
                    ▼                │
        📦 STORE (MongoDB) ◄─────────┘
                    │
                    ▼
        📱 APP MÓVIL  (leaderboard · perfil · cómo jugó el equipo)
```

- **Rama A — Matchmaking** (la base): rating + emparejamiento. Funciona sola, con una señal simple.
- **Rama B — Analytics** (el medallón): produce el score de dominancia.
- **🌉 El puente** = meter la dominancia derivada de analytics en el margen del rating (no la diferencia de goles). **Es la contribución de la tesis.**

## Cómo seguir

| Para… | Ver |
|-------|-----|
| la arquitectura técnica | [spec/overview.md](spec/overview.md) |
| los contratos de datos | [spec/contratos.md](spec/contratos.md) |
| las capas de datos | [spec/datos-medallon.md](spec/datos-medallon.md) |
| la rama de analytics | [spec/analytics.md](spec/analytics.md) |
| la rama de matchmaking | [spec/matchmaking.md](spec/matchmaking.md) |
| la ciencia detrás | [investigations/](investigations/) · [research/](research/) |
| el porqué de cada decisión | [decisions/log.md](decisions/log.md) |
| el plan y el estado | [roadmap.md](roadmap.md) |

## Estado

| | Estado |
|---|---|
| Arquitectura y stack | ✅ decidido |
| Research consolidada | ✅ |
| Alcance analítico / validación | 🟦 en definición |
| Código | ⬜ no empezado |
