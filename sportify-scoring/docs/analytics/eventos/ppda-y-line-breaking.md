# PPDA y line-breaking

Dos métricas tácticas que miden cómo un equipo presiona y cómo progresa la pelota. Ambas dependen de la capa de eventos derivados (SPADL) y de conocer la dirección de ataque, así que en Sportify quedan diferidas respecto de las métricas de estructura (que son direction-agnostic y arrancan primero).

## PPDA — presión

PPDA (*passes per defensive action*) estima cuán alto y agresivo presiona un equipo: cuántos pases deja completar al rival antes de hacer una acción defensiva. Se mide en el 60% de cancha más lejano al arco propio (la zona donde tiene sentido contar presión, no defensa de último recurso).

```
PPDA = pases_completados_rival / acciones_defensivas_propias
       (ambos contados en el 60% de cancha lejos del arco propio)
```

Cuanto más bajo el número, más presión. Interpretación de referencia:

- **4–8** → presión alta
- **9–12** → bloque medio
- **13+** → bloque bajo

## Line-breaking passes

Un line-breaking pass es un pase que progresa hacia el arco rival y atraviesa una línea de defensores. En las fuentes se define como un pase que acerca la pelota **≥10% al arco rival** y **cruza una línea de defensores**, donde la línea se detecta por clustering de las posiciones de los rivales. No hay fórmula cerrada: es una condición geométrica sobre el pase más el estado posicional del rival en ese instante.

## Cómo se usa en Sportify

Las dos se calculan sobre la capa de eventos on-ball (SPADL), que Sportify deriva internamente a partir del tracking sincronizado, no la recibe. Necesitan además resolver la dirección de ataque del equipo, cosa que las métricas de estructura no requieren. Por eso son 🟡: llegan después de las direction-agnostic, una vez que la capa de eventos derivados y la detección de dirección estén estables.

Queda abierto el detalle de la detección de líneas por clustering aplicada a tracking amateur (cómo se agrupan los defensores y qué tan robusto es con datos ruidosos).

**Fuente:** [../../research/papers/datos-y-metricas/line-breaking-passes.pdf](../../research/papers/datos-y-metricas/line-breaking-passes.pdf)
