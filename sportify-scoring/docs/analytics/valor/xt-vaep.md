# xT y VAEP

Frameworks de **valor de posesión** sobre acciones. Antes de modelar, convierten el event stream a **SPADL** (una representación uniforme de acciones: pase, conducción, tiro, etc.). Son modelos de ML, por eso viven en los workers Python.

## xT — Expected Threat

Asigna a cada zona de la cancha un valor de "amenaza": cuánta probabilidad de gol genera tener la pelota ahí. Cada acción se valora por la diferencia de amenaza entre la zona de origen y la de destino: mover la pelota a una zona más peligrosa suma valor.

```
xT_acción = xT(zona_destino) − xT(zona_origen)
```

## VAEP / Atomic-VAEP

*Valuing Actions by Estimating Probabilities.* Valora cada acción por cuánto cambia las probabilidades de marcar y de recibir un gol en las próximas jugadas. Es un modelo de ML sobre features de la acción y su contexto.

```
VAEP_acción = Δ P(marcar) − Δ P(recibir gol)
```

A diferencia de xT, no se limita a pases/conducciones que mueven la pelota: puntúa también acciones defensivas y otros tipos de evento. **Atomic-VAEP** es una variante que descompone las acciones en unidades más atómicas. La elección concreta entre VAEP y Atomic-VAEP en Sportify queda **abierta**.

## Uso en Sportify

Sobre el event stream pasado a SPADL, estos modelos producen un valor por acción que alimenta las features de valor (gold). Por ser modelos de ML entrenados sobre features, corren en los workers Python, no en el pipeline en vivo.

**Fuente:** [../../research/references.md](../../research/references.md)
