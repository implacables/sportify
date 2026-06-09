"""Sportify scoring — workers de analytics y rating.

Pipeline organizado por capas del medallón (ver docs/architecture.md §3):

    bronze -> silver -> gold -> rating

- bronze: ingesta cruda (reconstruction.json / Metrica) -> modelo Frame.
- silver: limpieza y conformado (suavizado, IDs, velocidades, equipo).
- gold:   features (métricas espaciales, pitch control, valor, dominancia).
- rating: OpenSkill (update del rating + reparto a jugadores).
"""
