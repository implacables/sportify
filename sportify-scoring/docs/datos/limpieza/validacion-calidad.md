# Validación de calidad

Cómo nos aseguramos de que la limpieza de silver hace lo que tiene que hacer. El problema de fondo: todavía no tenemos tracking amateur real, así que no hay un dato sucio con su verdad limpia al lado para comparar. La salida: armamos ese par nosotros, degradando tracking pro.

## Cómo funciona

Arrancamos de Metrica: datos abiertos de tracking limpio (2 partidos), que tomamos como **verdad de referencia**. Sobre ese tracking inyectamos artificialmente los defectos típicos de calidad amateur — ruido posicional, huecos por oclusión y missed-detection, e ID-switches — y obtenemos una versión **degradada** que simula lo que saldría de nuestra reconstrucción.

Después corremos el pipeline de silver sobre esa versión degradada y miramos si **recupera** una aproximación de la verdad limpia original. El loop es:

```
tracking limpio (Metrica)
   → degradar (ruido + huecos + ID-switches)   ← simula amateur
   → silver (suavizado, interpolación, re-ID, outliers, velocidades, equipo)
   → comparar silver-recuperado vs verdad limpia
```

El error se mide **por operación** de limpieza (suavizado, interpolación, continuidad de IDs, etc.), no como un único número global, para saber qué etapa funciona y cuál no. Esos umbrales — qué error máximo por operación habilita gold y qué métrica exacta se usa en cada una — quedan **abiertos**.

## Cómo se usa en Sportify

Esta validación es el portón que decide si silver está habilitado para alimentar gold: si la recuperación no llega al umbral, no se computan métricas. Por honestidad de datos, todo lo que sale de acá se **rotula como sintético**: la degradación simula calidad amateur, no es evidencia sobre tracking amateur real, y no se presenta como tal.
