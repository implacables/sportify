# Margen (cómo escala el swing)

El **margen** es la pieza que decide cuánto mueve el rating un resultado: no es lo mismo ganar apretado que golear. Acá modelamos cómo ese margen escala el *swing* (el ajuste que se aplica al rating tras el partido).

## Cómo funciona — variante Elo con multiplicador de margen

Partís de la probabilidad esperada de ganar según la diferencia de rating, agregás un multiplicador que crece con el margen de victoria (`MOV`, *margin of victory*), y le sumás una corrección de autocorrelación:

```
E_win = 1 / (1 + 10^(-Δ/400))                      # prob. esperada
mult  = ln(|MOV| + 1)                              # multiplicador por margen
corr  = 2.2 / ((Elo_win − Elo_los)·0.001 + 2.2)    # corrección de autocorrelación
nuevo = viejo + K · mult · corr · (S − E_win)
```

- `E_win`: probabilidad esperada de ganar dada la diferencia de rating `Δ`.
- `mult = ln(|MOV| + 1)`: el margen entra en escala logarítmica, así que un 5-0 mueve más que un 1-0 pero sin disparar linealmente.
- `corr`: la corrección de autocorrelación, la pieza no obvia.

### Por qué la corrección evita inflar el sistema

Sin `corr`, los equipos más fuertes (los que tienen más rating) tienden a ganar por márgenes grandes contra los débiles, y el multiplicador de margen los premiaría de más una y otra vez. Eso retroalimenta: el fuerte sube, golea más fácil, vuelve a subir. La corrección achica el multiplicador justo cuando la diferencia de rating del ganador sobre el perdedor es grande, cortando ese loop y manteniendo el sistema estable.

## Cómo se usa en Sportify

En Sportify el rating elegido es OpenSkill (no esta variante Elo), pero el concepto de margen es el mismo: en vez de alimentar el margen con diferencia de goles —ruidosa en amateur— se lo alimenta con un **score de dominancia** derivado de analytics. Un equipo que mereció ganar sube fuerte aunque sea 1-0; un 3-0 con suerte no infla tanto. La variante Elo de acá queda como referencia conceptual de cómo el margen escala el swing y por qué hace falta frenar la inflación.

**Fuente:** [../../research/references.md](../../research/references.md)
