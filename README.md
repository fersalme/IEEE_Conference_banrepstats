# banrepstats: artículo IEEE y material de reproducción

Este repositorio contiene el artículo de conferencia IEEE
**"banrepstats: An R Package for Programmatic Access to Colombian Central
Bank Economic Data"** y todo lo necesario para reproducir sus resultados:
los scripts de validación, los datos congelados y las salidas que aparecen
en las tablas y figuras.

El paquete en sí vive en su propio repositorio:
<https://github.com/fersalme/banrepstats>. Este repositorio es independiente
del paquete. El artículo describe la versión **1.1.0**.

**Autores:** Fernando Salcedo-Mejía (Universidad Tecnológica de Bolívar),
Antonio Perez-Torres (Universidad Politécnica Salesiana) y Cesar
Villoria-Núñez (Universidad Tecnológica de Bolívar).

## De qué trata el artículo

El Banco de la República publica más de 250 series macroeconómicas en su
portal SUAMECA, pero no ofrece una API pública documentada. `banrepstats`
consume la API JSON interna del portal para descubrir el catálogo de
indicadores y descargar cualquiera de ellos como un `data.table` ordenado.
El artículo:

- describe la arquitectura del paquete (`catalogo_banrep()`,
  `search_banrep()`, `banrep_data()`, `series_plot()` y el catálogo
  `banrep_cache`);
- documenta los obstáculos de usar una API no documentada: filtrado
  silencioso de peticiones sin `Referer`, fechas codificadas en hora de
  Bogotá, códigos de indicador no únicos y una cadena de certificados TLS
  incompleta;
- valida la cobertura y la exactitud del paquete contra el portal oficial;
- ilustra la integración con `tsibble`/`fable` pronosticando la tasa de
  desempleo y el crecimiento del PIB con ARIMA, ETS, NNETAR y Prophet.

## Estructura

```
IEEE_Conference_Template/   Fuente LaTeX del artículo, clase IEEEtran, PDF y figuras
suameca_data/               12 CSV exportados a mano desde el portal SUAMECA
validation/
  validate_coverage.R       Descarga todo el catálogo y verifica su integridad
  validate_official.R       Compara banrep_data() con las exportaciones oficiales
  results/                  Resultados de ambas validaciones
paper/
  forecast_eval.R           Reproduce la Tabla III y las Figs. 1–3
  data/                     Datos congelados usados en el artículo
  results/                  Métricas, muestras, versiones de paquetes y sessionInfo
```

## Requisitos

- R ≥ 4.5 (los resultados se obtuvieron con R 4.5.2).
- El paquete `banrepstats`:

  ```r
  remotes::install_github("fersalme/banrepstats")
  ```

- Para los pronósticos: `data.table`, `dplyr`, `tsibble`, `fable`,
  `fabletools`, `fable.prophet` (y `prophet`) y `ggplot2`. Las versiones
  exactas están en [paper/results/versions.csv](paper/results/versions.csv).
- Una distribución de LaTeX para compilar el artículo.

## Cómo reproducir los resultados

Todos los scripts usan rutas relativas y deben ejecutarse desde la raíz de
este repositorio.

### Validación

```sh
Rscript validation/validate_coverage.R
Rscript validation/validate_official.R
```

- `validate_coverage.R` descarga cada indicador del catálogo en vivo y
  registra si la descarga funcionó, cuántas series y observaciones
  devolvió, si hay fechas duplicadas y si todas las fechas son días
  enteros. Termina con error si algún indicador falla, de modo que también
  sirve como monitor programado de la API.
- `validate_official.R` compara, serie por serie y fecha por fecha, la
  salida de `banrep_data()` con los CSV de [suameca_data/](suameca_data/).
  Un valor coincide cuando difiere a lo sumo en el redondeo de la
  exportación (media unidad del último decimal mostrado).

Ambos scripts consultan la API en vivo, así que si se ejecutan hoy pueden
dar cifras distintas a las del artículo: el Banco revisa y amplía sus
series. Los resultados publicados están en
[validation/results/](validation/results/).

### Pronósticos

```sh
Rscript paper/forecast_eval.R            # usa los datos congelados de paper/data/
Rscript paper/forecast_eval.R --refresh  # vuelve a descargar los datos
```

Sin `--refresh`, el script usa los datos de [paper/data/](paper/data/)
(descargados el 2026-10-24) y solo descarga si falta alguno. La semilla
(`20261024`) se fija antes de cada bloque de modelos. El script escribe:

- `paper/results/accuracy.csv` y `accuracy_rows.tex`: métricas fuera de
  muestra (Tabla III);
- `paper/results/samples.csv`: ventanas de entrenamiento y prueba;
- `paper/results/versions.csv` y `sessionInfo.txt`: registro del entorno;
- `IEEE_Conference_Template/banrepstats-*.png`: las figuras del artículo.

### Compilar el artículo

```sh
cd IEEE_Conference_Template
pdflatex conference_101719.tex
pdflatex conference_101719.tex
```

La bibliografía está incluida en el `.tex`, así que no hace falta BibTeX.

## Resultados principales (2026-10-24)

| Validación | Resultado |
|---|---|
| Cobertura | 61 de 61 indicadores descargados: 256 series y 460.461 observaciones en cinco frecuencias, sin fechas duplicadas |
| Exportaciones oficiales | 12 indicadores y 42 series comparados: las 38.858 observaciones coinciden (100 %), con las mismas fechas en ambas fuentes |

Error de pronóstico fuera de muestra con 10 periodos reservados (RMSE en
puntos porcentuales):

| Indicador | ARIMA | ETS | NNETAR | Prophet |
|---|---|---|---|---|
| Desempleo (mensual) | **0,56** | 1,06 | 1,23 | 0,81 |
| Crecimiento del PIB (trimestral) | 2,07 | 1,79 | 4,60 | **1,02** |

Estos pronósticos ilustran el flujo de trabajo; no buscan establecer qué
modelo es mejor. El artículo discute por qué el MAPE no es fiable para el
PIB y el probable sobreajuste de NNETAR.

## Fuentes de datos

Los datos provienen del portal SUAMECA del Banco de la República
(<https://suameca.banrep.gov.co/estadisticas-economicas/>). Los CSV de
[suameca_data/](suameca_data/) se exportaron manualmente desde ese portal:
tienen una columna de fecha (fin de periodo, `AAAA/MM/DD`) y una columna
por serie, usan coma decimal y dejan en blanco los valores faltantes.

## Licencia

`banrepstats` se distribuye bajo la licencia MIT. Los datos son propiedad
del Banco de la República y están sujetos a sus condiciones de uso.
