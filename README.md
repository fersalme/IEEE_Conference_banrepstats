# banrepstats: An R Package for Programmatic Access to Colombian Central Bank Economic Data

Artículo de conferencia IEEE y materiales de replicación. Este repositorio es
independiente del paquete, que está en
<https://github.com/fersalme/banrepstats> (versión 1.1.0, licencia MIT).

**Autores:** Fernando Salcedo-Mejía (Universidad Tecnológica de Bolívar),
Antonio Perez-Torres (Universidad Politécnica Salesiana) y Cesar
Villoria-Núñez (Universidad Tecnológica de Bolívar).

## Resumen

El Banco de la República publica 61 indicadores (256 series) en su portal
SUAMECA, pero no ofrece una API pública documentada. `banrepstats` consume
la API JSON interna del portal para buscar en el catálogo y descargar
cualquier indicador como un `data.table` ordenado, listo para `tsibble` y
`fable`. El artículo:

- describe el diseño del paquete: `catalogo_banrep()`, `search_banrep()`,
  `banrep_data()`, `series_plot()` y el catálogo incluido `banrep_cache`;
- documenta cuatro problemas de usar una API no documentada: el filtrado
  silencioso de peticiones sin `Referer`, las fechas en hora de Bogotá, los
  códigos de indicador no únicos y una cadena de certificados TLS
  incompleta;
- valida la cobertura del paquete y su concordancia con las exportaciones
  oficiales del portal;
- muestra la integración con herramientas de pronóstico usando la tasa de
  desempleo y el crecimiento del PIB.

## Resultados principales (24 de octubre de 2026)

- **Cobertura:** se descargaron los 61 indicadores del catálogo, con
  256 series y 460.461 observaciones en cinco frecuencias. No hay fechas
  duplicadas.
- **Concordancia con SUAMECA:** se compararon 42 series de 12 indicadores
  con los CSV exportados del portal, y coinciden en el 100 % de las
  38.858 observaciones, con las mismas fechas en ambas fuentes.
- **Pruebas del paquete:** 32 tests (26 offline y 6 contra el servicio en
  vivo) que cubren el 94 % del código.
- **Pronóstico fuera de muestra** (RMSE en puntos porcentuales; los últimos
  10 periodos se reservan para la prueba):

  | Indicador | ARIMA | ETS | NNETAR | Prophet |
  |---|---|---|---|---|
  | Desempleo (mensual) | **0,56** | 1,06 | 1,23 | 0,81 |
  | Crecimiento del PIB (trimestral) | 2,07 | 1,79 | 4,60 | **1,02** |

  El ejercicio ilustra el flujo de trabajo y no pretende elegir el mejor
  modelo.

## Contenido

| Ruta | Contenido |
|---|---|
| [IEEE_Conference_Template/](IEEE_Conference_Template/) | Fuente LaTeX, PDF y figuras del artículo |
| [validation/](validation/) | Scripts de cobertura y de concordancia, con sus resultados |
| [suameca_data/](suameca_data/) | 12 CSV exportados a mano desde el portal SUAMECA |
| [paper/](paper/) | Script de pronósticos (Tabla III y Figs. 1–3), datos congelados y resultados |

## Reproducción

Requiere R ≥ 4.5 y `remotes::install_github("fersalme/banrepstats")`. Los
pronósticos necesitan además `tsibble`, `fable`, `fabletools`,
`fable.prophet`, `dplyr` y `ggplot2`. Los scripts se ejecutan desde la raíz
del repositorio:

```sh
Rscript validation/validate_coverage.R   # descarga todo el catálogo
Rscript validation/validate_official.R   # compara con suameca_data/
Rscript paper/forecast_eval.R            # usa los datos congelados (--refresh los vuelve a descargar)
```

Los scripts de validación consultan la API en vivo, así que sus cifras
pueden cambiar a medida que el Banco revisa sus series. Los pronósticos
usan los datos congelados el 24 de octubre de 2026 y la semilla 20261024.
Los resultados se generaron con R 4.5.2 y banrepstats 0.1.1, cuyo código no
cambia en la 1.1.0. Las versiones de todos los paquetes usados están en
[paper/results/versions.csv](paper/results/versions.csv).

Para compilar el artículo, ejecuta `pdflatex conference_101719.tex` dos
veces dentro de `IEEE_Conference_Template/`.

Los datos son del Banco de la República
(<https://suameca.banrep.gov.co/estadisticas-economicas/>) y están sujetos
a sus condiciones de uso.
