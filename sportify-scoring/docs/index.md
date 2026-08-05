# Sportify — Scoring & Matchmaking

Mide el skill de los jugadores desde el tracking del partido (**analytics**) y los empareja parejo (**matchmaking**). Es la parte de tesis, separada del POC de reconstrucción; consume su contrato per-frame. El aporte original: emparejar con **visión por computadora** en vez de evaluación subjetiva.

## El mapa

```
🎥 video ─→ [reconstrucción] ─→ reconstruction.json
                    │
                    ▼
🌳 ANALYTICS (medallón: 🥉bronze → 🥈silver → 🥇gold)
   produce: SCORE DE DOMINANCIA + contribución por jugador
                    │
       (dominancia) │──🌉──→ 🌳 MATCHMAKING
                    │          rating OpenSkill + margen → leaderboard
                    ▼                │
        📦 STORE (MongoDB) ◄─────────┘
                    │
                    ▼
        📱 APP MÓVIL  (leaderboard · perfil · cómo jugó el equipo)
```

**El puente** (meter la dominancia derivada de analytics en el margen del rating, no la diferencia de goles) es la **contribución de la tesis**.

## Recorrido

| Área | Qué cubre |
|------|-----------|
| [Datos](datos/index.md) | qué recibimos, el Frame y la limpieza (silver) |
| [Analytics](analytics/index.md) | métricas espaciales, superficies de valor, dominancia |
| [Matchmaking](matchmaking/index.md) | rating, el puente, emparejamiento |
| [Plataforma](plataforma/index.md) | backend Go, workers, base de datos, identidad |

Además: [decisiones (ADR)](decisions/log.md) · [research + papers](research/README.md) · [glosario](glosario.md) · [roadmap](roadmap.md)
