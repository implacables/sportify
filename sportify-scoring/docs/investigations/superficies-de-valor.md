# Investigación — Superficies de valor

**Estado:** referencia factual. Fundamenta las features de valor (gold) y el score de dominancia.
**Papers:** [../research/papers/superficies-de-valor/](../research/papers/superficies-de-valor/) · **Bibliografía:** [../research/references.md](../research/references.md)

---

Clave: **superficies de valor continuas** sobre toda la cancha, en cada instante.

## Pitch Control [ref: `pitch-control`]

Campo de probabilidad `[0,1]` de qué equipo controla cada zona. Cada jugador = proceso de Poisson con tasa `λ` (inverso del tiempo medio para un toque controlado), integrado en el tiempo. **Usa posición + velocidad** → la velocidad se deriva en silver. Implementación de referencia: Friends of Tracking (modelo de Spearman).

## Wide Open Spaces [ref: `wide-open-spaces`]

Valor de espacio creado/ocupado, a nivel equipo y jugador individual, con y sin pelota. Basado en pitch control desde un modelo de probabilidad de recepción.

## OBSO — Off-Ball Scoring Opportunity [ref: `obso`]

Probabilidad posterior de marcar en el próximo evento on-ball en cada zona. Descomposición:

```
OBSO = control × transición × score
     (pitch control × dónde va la pelota × prob. de gol desde esa zona)
```

Mide el peligro del espacio ocupado **sin** la pelota.

## Valor de posesión [ref: `socceraction`]

**xT** (Expected Threat), **VAEP / Atomic-VAEP** — convierten event streams a SPADL primero. Son modelos de ML (sobre features), por eso viven en los workers Python.

## Patrón EPV [ref: `epv`]

*Expected Possession Value* — opera sobre el estado espacio-temporal completo (22 + pelota), **descompone** en modelos componentes (pase/conducción/tiro/pérdida) interpretables y los fusiona. Lección de arquitectura: **modular, descompuesto, interpretable**.
