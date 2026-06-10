# EPV

**Expected Possession Value** es el valor esperado de una posesión: cuánto vale, en términos de gol esperado, el estado actual del juego. Opera sobre el estado espacio-temporal completo (los 22 jugadores + la pelota) en cada instante, no sobre eventos sueltos.

La idea central es la **descomposición**: en vez de modelar el valor con una caja negra, EPV se parte en modelos componentes interpretables —pase, conducción, tiro, pérdida— y los fusiona. Cada componente responde una pregunta acotada (¿qué pasa si se patea?, ¿qué pasa si se conduce?, ¿qué pasa si se pierde la pelota?) y el valor total surge de combinarlos según su probabilidad.

La fórmula conceptual de la descomposición:

```
EPV = P(pase)·V(pase) + P(conducción)·V(conducción) + P(tiro)·V(tiro) - P(pérdida)·V(pérdida)
```

donde cada `P(·)` es la probabilidad de esa acción desde el estado actual y cada `V(·)` su valor esperado en goles. (La forma exacta de cada componente y su calibración queda **abierta** acá; la fuente desarrolla la formulación completa.)

La lección de arquitectura que tomamos para Sportify es justamente esa: **modular, descompuesto, interpretable**. En lugar de un único modelo monolítico de valor, se construyen componentes chicos y entendibles que se pueden inspeccionar, validar y reemplazar por separado. Esto encaja con las superficies de valor continuas (pitch control, OBSO) que ya alimentan las features gold y el score de dominancia: EPV es el patrón que las orquesta sobre el estado completo del juego.

**Fuente:** [epv-decomposing-immeasurable-sport.pdf](../../research/papers/superficies-de-valor/epv-decomposing-immeasurable-sport.pdf)
