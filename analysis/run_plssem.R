# ============================================================
# TPB PLS-SEM analysis — multi-subgroup runner
# ============================================================
# Estimates a Theory of Planned Behavior model with PLS-SEM
# (R 'seminr') for two survey datasets, across many demographic
# subgroups, under two structural specifications:
#   - baseline : 4 constructs (AT/SN/PBC/BI), 5 structural paths
#   - with_E   : adds a 5th construct E -> AT/SN/PBC/BI
# Each model is bootstrapped (5000 resamples) for significance testing.
#
# Input : synthetic_data/survey_a_clean.csv, survey_b_clean.csv
#         (produced by data_prep/generate_synthetic_data.py + clean_survey_data.py)
# Output: r_results/survey_a_plssem.xlsx, survey_b_plssem.xlsx
#
# Run:  Rscript analysis/run_plssem.R
#   (or open in RStudio, set the working directory to the repo root, and Source)
# ============================================================

# --- 0. packages -------------------------------------------------
required <- c("seminr", "dplyr", "tibble", "openxlsx")
for (pkg in required) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/")
  }
}
suppressPackageStartupMessages({
  library(seminr); library(dplyr); library(tibble); library(openxlsx)
})

set.seed(42)

# --- 1. config ---------------------------------------------------
DATA_DIR <- "synthetic_data"   # folder with *_clean.csv inputs
OUT_DIR  <- "r_results"        # output folder (git-ignored)
N_BOOT   <- 5000               # bootstrap resamples (use 500 for a quick test)
SEED     <- 42
dir.create(OUT_DIR, showWarnings = FALSE)

# --- 2. measurement models --------------------------------------
mm_baseline <- constructs(
  composite("AT",  multi_items("AT",  1:12), weights = mode_A),
  composite("SN",  multi_items("SN",  1:12), weights = mode_A),
  composite("PBC", multi_items("PBC", 1:12), weights = mode_A),
  composite("BI",  multi_items("BI",  1:12), weights = mode_A)
)
mm_with_E <- constructs(
  composite("AT",  multi_items("AT",  1:12), weights = mode_A),
  composite("SN",  multi_items("SN",  1:12), weights = mode_A),
  composite("PBC", multi_items("PBC", 1:12), weights = mode_A),
  composite("BI",  multi_items("BI",  1:12), weights = mode_A),
  composite("E",   multi_items("E",   1:13), weights = mode_A)
)

# --- 3. structural models ---------------------------------------
sm_baseline <- relationships(
  paths(from = c("AT", "SN"),        to = "PBC"),
  paths(from = c("AT", "SN", "PBC"), to = "BI")
)
sm_with_E <- relationships(
  paths(from = c("AT", "SN"),        to = "PBC"),
  paths(from = c("AT", "SN", "PBC"), to = "BI"),
  paths(from = "E",                  to = c("AT", "SN", "PBC", "BI"))
)

# --- 4. extractors: turn seminr objects into tidy data frames ----
extract_quality <- function(model, label) {
  rel <- as.data.frame(summary(model)$reliability)
  rel$Construct <- rownames(rel)
  out <- data.frame(
    Variant = label, Construct = rel$Construct,
    Cronbach_alpha = rel$alpha, CR_rhoC = rel$rhoC,
    AVE = rel$AVE, rhoA = rel$rhoA, stringsAsFactors = FALSE
  )
  r2 <- model$rSquared
  if (!is.null(r2) && length(r2) > 0) {
    r2_df <- data.frame(Construct = colnames(r2),
                        R_squared = as.numeric(r2[1, ]),
                        stringsAsFactors = FALSE)
    out <- merge(out, r2_df, by = "Construct", all.x = TRUE)
  } else {
    out$R_squared <- NA_real_
  }
  out[, c("Variant", "Construct", "Cronbach_alpha",
          "CR_rhoC", "AVE", "rhoA", "R_squared")]
}

extract_paths <- function(boot_model, label) {
  bp <- summary(boot_model)$bootstrapped_paths
  if (is.null(bp)) return(data.frame())
  df <- as.data.frame(bp); df$Path <- rownames(df)
  out <- data.frame(
    Variant = label, Path = df$Path,
    Beta = df[["Original Est."]], Boot_Mean = df[["Bootstrap Mean"]],
    Boot_SD = df[["Bootstrap SD"]], t_value = df[["T Stat."]],
    CI_low = df[["2.5% CI"]], CI_high = df[["97.5% CI"]],
    stringsAsFactors = FALSE
  )
  out$p_value <- 2 * (1 - pnorm(abs(out$t_value)))
  out$Sig <- ifelse(out$p_value < 0.001, "***",
             ifelse(out$p_value < 0.01,  "**",
             ifelse(out$p_value < 0.05,  "*", "ns")))
  out$Supported <- ifelse(abs(out$t_value) > 1.96, "yes", "no")
  out
}

extract_loadings <- function(boot_model, label) {
  bl <- summary(boot_model)$bootstrapped_loadings
  if (is.null(bl)) return(data.frame())
  df <- as.data.frame(bl); df$Path <- rownames(df)
  data.frame(
    Variant = label, Path = df$Path,
    Loading = df[["Original Est."]], Boot_Mean = df[["Bootstrap Mean"]],
    Boot_SD = df[["Bootstrap SD"]], t_value = df[["T Stat."]],
    stringsAsFactors = FALSE
  )
}

# --- 5. estimate one subgroup (baseline + with_E) ----------------
run_one <- function(data, label) {
  cat("  estimating:", label, "(N =", nrow(data), ")\n")
  m_base <- estimate_pls(data = data, measurement_model = mm_baseline,
                         structural_model = sm_baseline,
                         missing_value = NA, missing = mean_replacement)
  b_base <- bootstrap_model(seminr_model = m_base, nboot = N_BOOT,
                            cores = parallel::detectCores() - 1, seed = SEED)
  m_ext <- estimate_pls(data = data, measurement_model = mm_with_E,
                        structural_model = sm_with_E,
                        missing_value = NA, missing = mean_replacement)
  b_ext <- bootstrap_model(seminr_model = m_ext, nboot = N_BOOT,
                           cores = parallel::detectCores() - 1, seed = SEED)
  list(base_model = m_base, base_boot = b_base,
       ext_model = m_ext, ext_boot = b_ext)
}

# --- 6. subgroup definitions ------------------------------------
# Each entry: label suffix + a filter function returning a logical vector.
groupings <- function(prefix) list(
  list(label = paste0(prefix, "_full"),       filter = function(d) rep(TRUE, nrow(d))),
  list(label = paste0(prefix, "_city1"),      filter = function(d) d$City == 1),
  list(label = paste0(prefix, "_city2"),      filter = function(d) d$City == 2),
  list(label = paste0(prefix, "_mem12yes"),   filter = function(d) d$Member_12 == 1),
  list(label = paste0(prefix, "_mem12no"),    filter = function(d) d$Member_12 == 2),
  list(label = paste0(prefix, "_mem65yes"),   filter = function(d) d$Member_65 == 1),
  list(label = paste0(prefix, "_mem65no"),    filter = function(d) d$Member_65 == 2),
  list(label = paste0(prefix, "_male"),       filter = function(d) d$Gender == 1),
  list(label = paste0(prefix, "_female"),     filter = function(d) d$Gender == 2),
  list(label = paste0(prefix, "_edulo"),      filter = function(d) d$Education %in% c(1, 2)),
  list(label = paste0(prefix, "_eduhi"),      filter = function(d) d$Education %in% c(3, 4)),
  list(label = paste0(prefix, "_agelo"),      filter = function(d) d$Age %in% c(1, 2, 3)),
  list(label = paste0(prefix, "_agehi"),      filter = function(d) d$Age %in% c(4, 5, 6)),
  list(label = paste0(prefix, "_inclo"),      filter = function(d) !is.na(d$Income) & d$Income %in% c(1, 2, 3)),
  list(label = paste0(prefix, "_inchi"),      filter = function(d) !is.na(d$Income) & d$Income %in% c(4, 5, 6)),
  list(label = paste0(prefix, "_residshort"), filter = function(d) d$Res_Year %in% c(1, 2)),
  list(label = paste0(prefix, "_residlong"),  filter = function(d) d$Res_Year %in% c(3, 4, 5))
)

run_all_groupings <- function(df, prefix) {
  out <- list()
  for (cfg in groupings(prefix)) {
    sub <- df[cfg$filter(df), , drop = FALSE]
    if (nrow(sub) < 50) {
      cat("  SKIP", cfg$label, "(only", nrow(sub), "rows)\n"); next
    }
    out[[cfg$label]] <- run_one(sub, cfg$label)
  }
  out
}

# --- 7. compile every variant into one Excel workbook -----------
compile_results <- function(results_list, out_path) {
  qual_all <- list(); paths_all <- list(); load_all <- list()
  for (label in names(results_list)) {
    r <- results_list[[label]]
    qual_all[[paste0(label, "_baseline")]] <- extract_quality(r$base_model, paste0(label, "_baseline"))
    qual_all[[paste0(label, "_withE")]]    <- extract_quality(r$ext_model,  paste0(label, "_withE"))
    paths_all[[paste0(label, "_baseline")]] <- extract_paths(r$base_boot, paste0(label, "_baseline"))
    paths_all[[paste0(label, "_withE")]]    <- extract_paths(r$ext_boot,  paste0(label, "_withE"))
    load_all[[paste0(label, "_baseline")]]  <- extract_loadings(r$base_boot, paste0(label, "_baseline"))
    load_all[[paste0(label, "_withE")]]     <- extract_loadings(r$ext_boot,  paste0(label, "_withE"))
  }
  wb <- createWorkbook()
  addWorksheet(wb, "Quality_Summary"); writeData(wb, "Quality_Summary", bind_rows(qual_all))
  addWorksheet(wb, "Path_Summary");    writeData(wb, "Path_Summary",    bind_rows(paths_all))
  addWorksheet(wb, "Outer_Loadings");  writeData(wb, "Outer_Loadings",  bind_rows(load_all))
  saveWorkbook(wb, out_path, overwrite = TRUE)
  cat("saved:", out_path, "\n")
}

# --- 8. run ------------------------------------------------------
for (prefix in c("survey_a", "survey_b")) {
  cat("\n###############", toupper(prefix), "###############\n")
  csv <- file.path(DATA_DIR, paste0(prefix, "_clean.csv"))
  df <- read.csv(csv, fileEncoding = "UTF-8-BOM")
  cat("loaded", csv, "- N =", nrow(df), "\n")
  results <- run_all_groupings(df, prefix)
  compile_results(results, file.path(OUT_DIR, paste0(prefix, "_plssem.xlsx")))
}
cat("\n############### DONE ###############\n")
