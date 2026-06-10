# Interpolación de oclusiones

Cuando un jugador desaparece unos frames —porque otro lo tapa (oclusión) o porque la detección lo perdió (missed-detection)— su track queda con un hueco. Interpolar es **rellenar ese hueco** estimando dónde estaba el jugador en los frames faltantes a partir de las posiciones conocidas antes y después. Es una de las operaciones de limpieza de silver (FR-S2), anterior a cualquier métrica.

## Cómo funciona

Se toma la última posición conocida antes del hueco y la primera después, y se rellenan los frames intermedios siguiendo el camino entre ambas. La forma más simple es la interpolación lineal: el jugador se mueve en línea recta a velocidad constante entre los dos extremos.

```
# hueco entre frame t0 (conocido) y t1 (conocido), para t0 < t < t1
α = (t - t0) / (t1 - t0)
position(t) = (1 - α) · position(t0) + α · position(t1)
```

El parámetro `α` va de 0 a 1 a medida que avanza el hueco: en `t0` reproduce la posición inicial, en `t1` la final, y en el medio promedia ambas según la distancia temporal.

## Cuándo interpolar y cuándo no

Tiene sentido sobre **huecos cortos**, donde asumir movimiento continuo es razonable: el jugador no se teletransporta en una oclusión de unos frames. En huecos largos la línea recta deja de ser creíble (el jugador pudo cambiar de dirección o velocidad), y rellenar ahí inventa trayectoria. El límite exacto de cuántos frames de hueco se rellenan queda **abierto** (forma parte de los algoritmos concretos de silver, no especificados todavía).

La interpolación tampoco resuelve un cambio de identidad: si el hueco aparece porque el track se rompió y se reasignó a otro id, eso lo trata la continuidad de IDs (FR-S3), no esta operación.

## Cómo se usa en Sportify

Es un paso de la etapa silver del medallón, junto con suavizado, remoción de outliers y derivación de velocidades. Como no hay tracking amateur real todavía, se valida con la degradación sintética de Metrica: se inyectan huecos sobre tracking limpio, se corre silver para recuperarlo, y se mide el error de la versión interpolada contra la verdad limpia. Los umbrales de error que habilitan gold quedan **abiertos**.
