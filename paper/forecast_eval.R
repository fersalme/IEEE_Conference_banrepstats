# Reproduces the forecasting results of the paper (Table III and
# Figs. 1-3).
#
# Run from the package root:
#   Rscript paper/forecast_eval.R           # use the frozen data snapshot
#   Rscript paper/forecast_eval.R --refresh # download the data again
#
# Banrep revises and extends its series, so the data used in the paper
# are frozen in paper/data/ together with the date they were retrieved.
# Without --refresh the script only downloads when no snapshot exists.

suppressPackageStartupMessages({
  library(banrepstats)
  library(data.table)
  library(dplyr)
  library(tsibble)
  library(fable)
  library(fabletools)
  library(fable.prophet)
  library(ggplot2)
})

invisible(Sys.setlocale("LC_TIME", "en_US.UTF-8"))
# NNETAR fits and forecasts by simulation, and other models draw random
# numbers too, so the seed is reset before every block of models.
semilla <- 20261024

dir.create("paper/data", showWarnings = FALSE, recursive = TRUE)
dir.create("paper/results", showWarnings = FALSE, recursive = TRUE)
fig_dir <- "IEEE_Conference_Template"

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)

codigos <- c(
  inflacion = "inflacion_y_meta",
  desempleo = "mercado_laboral_poblacion_tasa_ocupacion_desempleo",
  pib = "producto_interno_bruto_pib_trimestral_observado_crecimiento_anual_serie_original"
)

snapshot <- function(nombre) {
  archivo <- file.path("paper/data", paste0(nombre, ".csv"))
  if (refresh || !file.exists(archivo)) {
    datos <- banrep_data(codigos[[nombre]], cache = banrep_cache)
    datos[, retrieved := format(Sys.Date())]
    fwrite(datos, archivo)
  }
  fread(
    archivo,
    encoding = "UTF-8",
    colClasses = list(Date = "date", character = "retrieved")
  )
}

inflacion <- snapshot("inflacion")
desempleo_raw <- snapshot("desempleo")
pib_raw <- snapshot("pib")

retrieved <- unique(c(inflacion$retrieved, desempleo_raw$retrieved, pib_raw$retrieved))

# ---- Series ---------------------------------------------------------------

desempleo <- desempleo_raw |>
  filter(id == "Tasa de desempleo - total nacional") |>
  mutate(periodo = yearmonth(date)) |>
  select(periodo, value) |>
  as_tsibble(index = periodo)

pib <- pib_raw |>
  mutate(periodo = yearquarter(date)) |>
  select(periodo, value) |>
  as_tsibble(index = periodo)

h_test <- 10L

# The seasonal settings are spliced into the Prophet formula with !!:
# fable evaluates model formulas with the data columns in scope, so a bare
# variable could be shadowed by a column of the same name.
modelos <- function(datos, s_period, s_order, s_type) {
  datos |>
    model(
      ARIMA = ARIMA(value),
      ETS = ETS(value),
      NNETAR = NNETAR(value),
      Prophet = prophet(
        value ~ season(period = !!s_period, order = !!s_order, type = !!s_type)
      )
    )
}

especificaciones <- list(
  Unemployment = list(datos = desempleo, s_period = 12, s_order = 5, s_type = "multiplicative"),
  `GDP growth` = list(datos = pib, s_period = 4, s_order = 2, s_type = "additive")
)

# ---- Out-of-sample evaluation (Table III) ---------------------------------

evaluar <- function(nombre, spec) {
  set.seed(semilla)
  n <- nrow(spec$datos)
  train <- spec$datos[seq_len(n - h_test), ]
  test <- spec$datos[(n - h_test + 1L):n, ]

  fit <- modelos(train, spec$s_period, spec$s_order, spec$s_type)
  fc <- forecast(fit, new_data = test)

  fuera <- accuracy(fc, spec$datos, measures = list(
    RMSE = RMSE, MAE = MAE, MAPE = MAPE, MASE = MASE
  ))
  dentro <- accuracy(fit, measures = list(RMSE_train = RMSE))

  especificacion <- vapply(
    names(fit),
    \(m) format(fit[[m]][[1]]),
    character(1)
  )

  muestra <- data.table(
    indicator = nombre,
    n_total = n,
    sample_start = format(min(spec$datos$periodo)),
    sample_end = format(max(spec$datos$periodo)),
    n_train = nrow(train),
    train_end = format(max(train$periodo)),
    n_test = nrow(test),
    test_start = format(min(test$periodo)),
    test_end = format(max(test$periodo))
  )

  resultados <- as.data.table(fuera)[, .(model = .model, RMSE, MAE, MAPE, MASE)]
  resultados <- merge(
    resultados,
    as.data.table(dentro)[, .(model = .model, RMSE_train)],
    by = "model"
  )
  resultados[, `:=`(
    indicator = nombre,
    specification = especificacion[model],
    overfit_ratio = RMSE / RMSE_train
  )]
  setcolorder(resultados, c("indicator", "model", "specification"))

  list(muestra = muestra, resultados = resultados)
}

evaluacion <- Map(evaluar, names(especificaciones), especificaciones)
muestras <- rbindlist(lapply(evaluacion, `[[`, "muestra"))
accuracy_tbl <- rbindlist(lapply(evaluacion, `[[`, "resultados"))
accuracy_tbl[, model := factor(model, c("ARIMA", "ETS", "NNETAR", "Prophet"))]
setorder(accuracy_tbl, -indicator, model)
accuracy_tbl[, `:=`(
  rank_RMSE = frank(RMSE),
  rank_MASE = frank(MASE)
), by = indicator]

# Share of near-zero quarters in the GDP test window, which inflate MAPE.
pib_test <- tail(pib$value, h_test)

fwrite(muestras, "paper/results/samples.csv")
fwrite(accuracy_tbl, "paper/results/accuracy.csv")
fwrite(
  data.table(indicator = "GDP growth", min_abs_test_value = min(abs(pib_test))),
  "paper/results/gdp_test_min_abs.csv"
)

# LaTeX rows for Table III.
filas <- accuracy_tbl[, sprintf(
  "%s & %s & %.2f & %.2f & %.1f & %.2f \\\\",
  indicator, model, RMSE, MAE, MAPE, MASE
)]
writeLines(filas, "paper/results/accuracy_rows.tex")

# ---- Figures --------------------------------------------------------------

tema <- theme_minimal(base_size = 11) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank()
  )
colores <- c(
  ARIMA = "#003E6C", ETS = "#C9A227", NNETAR = "#830C0C", Prophet = "#2E6B4F"
)

grafico_pronostico <- function(datos, h, desde, ylab, xlab) {
  set.seed(semilla)
  fit <- modelos(datos$datos, datos$s_period, datos$s_order, datos$s_type)
  fc <- forecast(fit, h = h)
  historia <- datos$datos |> filter(periodo >= desde)
  autoplot(fc, historia, level = 80, alpha = 0.6) +
    scale_colour_manual(values = colores) +
    scale_fill_manual(values = colores) +
    labs(x = xlab, y = ylab, colour = "Model", fill = "Model") +
    # The single 80% interval needs no legend of its own; the caption says it.
    guides(fill_ramp = "none") +
    tema
}

fig_desempleo <- grafico_pronostico(
  especificaciones$Unemployment,
  h = "18 months",
  desde = yearmonth("2015 Jan"),
  ylab = "Unemployment rate (%)",
  xlab = "Month"
)
ggsave(file.path(fig_dir, "banrepstats-forecast.png"), fig_desempleo,
       width = 7, height = 4, dpi = 300, bg = "white")

fig_pib <- grafico_pronostico(
  especificaciones$`GDP growth`,
  h = "2 years",
  desde = yearquarter("2006 Q1"),
  ylab = "Real GDP growth, year-on-year (%)",
  xlab = "Quarter"
)
ggsave(file.path(fig_dir, "banrepstats-pib.png"), fig_pib,
       width = 7, height = 4, dpi = 300, bg = "white")

fig_inflacion <- series_plot(as.data.table(inflacion)) +
  labs(y = "Percent", color = "Series")
ggsave(file.path(fig_dir, "banrepstats-precios.png"), fig_inflacion,
       width = 7, height = 4, dpi = 300, bg = "white")

# ---- Reproducibility record -----------------------------------------------

paquetes <- c(
  "banrepstats", "data.table", "httr2", "tsibble", "fable", "fabletools",
  "fable.prophet", "prophet", "ggplot2"
)
versiones <- data.table(
  package = c("R", paquetes),
  version = c(
    paste(R.version$major, R.version$minor, sep = "."),
    vapply(paquetes, \(p) as.character(packageVersion(p)), character(1))
  )
)
fwrite(versiones, "paper/results/versions.csv")
writeLines(
  c(paste("Data retrieved:", paste(retrieved, collapse = ", ")),
    paste("Seed:", semilla), "", capture.output(sessionInfo())),
  "paper/results/sessionInfo.txt"
)

print(muestras)
print(accuracy_tbl[, .(indicator, model, specification, RMSE, MAE, MAPE, MASE,
                       RMSE_train, overfit_ratio)])
print(versiones)
cat("Data retrieved:", retrieved, "\n")
