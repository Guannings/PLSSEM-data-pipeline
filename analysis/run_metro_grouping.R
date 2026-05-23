# ============================================================
# PLS-SEM for a single urban-stratification grouping
# ============================================================
# Splits each dataset into two groups by an urban-stratification rule and
# re-runs the PLS-SEM analysis for that split only:
#
#   high-urbanization group = primary city (all districts)
#                           + selected high-urbanization districts of the
#                             secondary city (codes in METRO_DISTRICTS)
#   lower-urbanization group = the remaining secondary-city districts
#
# Exports tidy per-variant CSVs (quality, paths, loadings) rather than a
# workbook, so the results are easy to diff or merge.
#
# Input : synthetic_data/survey_a_clean.csv, survey_b_clean.csv
# Output: r_results/<prefix>_metro_quality.csv / _paths.csv / _loadings.csv
#
# Run:  Rscript analysis/run_metro_grouping.R   (from the repo root)
# ============================================================

required <- c("seminr", "dplyr")
for (pkg in required) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/")
  }
}
suppressPackageStartupMessages({ library(seminr); library(dplyr) })

set.seed(42)
N_BOOT   <- 5000
SEED     <- 42
DATA_DIR <- "synthetic_data"
OUT_DIR  <- "r_results"
dir.create(OUT_DIR, showWarnings = FALSE)

# District codes folded into the high-urbanization group (study-specific).
METRO_DISTRICTS <- c(1, 2, 3, 4, 5, 18)

# --- measurement + structural models (same as run_plssem.R) -----
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
sm_baseline <- relationships(
  paths(from = c("AT", "SN"),        to = "PBC"),
  paths(from = c("AT", "SN", "PBC"), to = "BI")
)
sm_with_E <- relationships(
  paths(from = c("AT", "SN"),        to = "PBC"),
  paths(from = c("AT", "SN", "PBC"), to = "BI"),
  paths(from = "E",                  to = c("AT", "SN", "PBC", "BI"))
)

run_one <- function(data, label) {
  cat("=== Running:", label, "(N =", nrow(data), ") ===\n")
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
  out
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

process <- function(csv_path, prefix) {
  cat("\n###############", toupper(prefix), "###############\n")
  df <- read.csv(csv_path, fileEncoding = "UTF-8-BOM")
  cat("Loaded:", csv_path, "N =", nrow(df), "\n")

  in_metro <- (df$City == 1) | (df$City == 2 & df$District %in% METRO_DISTRICTS)
  metro_grp <- df[in_metro, ]
  ntp_grp   <- df[!in_metro, ]
  cat("High-urbanization group :", nrow(metro_grp), "rows\n")
  cat("Lower-urbanization group:", nrow(ntp_grp),  "rows\n")

  res_metro <- run_one(metro_grp, paste0(prefix, "_metro"))
  res_ntp   <- run_one(ntp_grp,   paste0(prefix, "_ntpless"))

  qs <- rbind(
    extract_quality(res_metro$base_model, paste0(prefix, "_metro_baseline")),
    extract_quality(res_metro$ext_model,  paste0(prefix, "_metro_withE")),
    extract_quality(res_ntp$base_model,   paste0(prefix, "_ntpless_baseline")),
    extract_quality(res_ntp$ext_model,    paste0(prefix, "_ntpless_withE")))
  ps <- rbind(
    extract_paths(res_metro$base_boot, paste0(prefix, "_metro_baseline")),
    extract_paths(res_metro$ext_boot,  paste0(prefix, "_metro_withE")),
    extract_paths(res_ntp$base_boot,   paste0(prefix, "_ntpless_baseline")),
    extract_paths(res_ntp$ext_boot,    paste0(prefix, "_ntpless_withE")))
  ol <- rbind(
    extract_loadings(res_metro$base_boot, paste0(prefix, "_metro_baseline")),
    extract_loadings(res_metro$ext_boot,  paste0(prefix, "_metro_withE")),
    extract_loadings(res_ntp$base_boot,   paste0(prefix, "_ntpless_baseline")),
    extract_loadings(res_ntp$ext_boot,    paste0(prefix, "_ntpless_withE")))

  write.csv(qs, file.path(OUT_DIR, paste0(prefix, "_metro_quality.csv")),  row.names = FALSE)
  write.csv(ps, file.path(OUT_DIR, paste0(prefix, "_metro_paths.csv")),    row.names = FALSE)
  write.csv(ol, file.path(OUT_DIR, paste0(prefix, "_metro_loadings.csv")), row.names = FALSE)
  cat("Wrote 3 CSVs to", OUT_DIR, "\n")
}

process(file.path(DATA_DIR, "survey_a_clean.csv"), "survey_a")
process(file.path(DATA_DIR, "survey_b_clean.csv"), "survey_b")
cat("\n############### DONE ###############\n")
