# =============================================================================
# generate_wcvi_wham.R — WCVI herring (West Coast Vancouver Island)
# ASAP3 format for WHAM
# =============================================================================
# SOURCE DATA: SCA_herring_WCVI_binallages_twovuls.xlsx
#
# MODEL DIMENSIONS:
#   Years:   1951-2022  (n_years = 72)
#   Ages:    2-10+      (n_ages  = 9, age 10 = plus group)
#   Fleets:  1          (commercial fishery)
#   Indices: 1          (obsSSB survey biomass + Nagedt age comp)
#
# DATA:
#   Fleet catch total   — WCVI2022data.xlsx Catch (kt)
#   Fleet catch-at-age  — obsCat sheet (numbers, Neff=100 when catch>0, else 0)
#   Survey aggregate    — obsSSB sheet (kt, CV=0.1 all years)
#   Survey age comp     — Nagedt sheet (numbers, Neff=100 all years)
#   WAA                 — wat sheet (kg, time-varying)
#   Maturity            — pmat sheet (constant across years)
#
# KEY PARAMETERS:
#   M           = 0.37 (constant all ages and years)
#   fracyr_SSB  = 0.2885 (~April, herring spawn timing)
#   Fleet sel   = logistic a50=3, slope=1.5 (estimated)
#   Survey sel  = logistic a50=3, slope=1.5 (estimated)
#   q_survey    = 0.717612589
#   Neff fleet  = 100 (years with catch > 0), 0 (zero-catch years)
#   Neff survey = 100 all years
#   Survey CV   = 0.1 all years
#
# USAGE:
#   source("generate_wcvi_wham.R")
#   library(wham)
#   asap3 <- read_asap3_dat("wcvi_wham.dat")
#   input <- prepare_wham_input(asap3)
#   fit   <- fit_wham(input, do.retro=FALSE, do.osa=FALSE, do.sdrep=FALSE)
# =============================================================================

library(readxl)
setwd("P:/pCloud Sync/_wham")
data_file  <- "SCA_herring_WCVI binallages twovuls.xlsx"
catch_file <- "WCVI2022data_VPA_template6_RTMB.xlsx"

# ── Read source data ──────────────────────────────────────────────────────────
obs_cat  <- as.matrix(read_excel(data_file, sheet = "obsCat",  col_names = FALSE))
nagedt   <- as.matrix(read_excel(data_file, sheet = "Nagedt",  col_names = FALSE))
obs_ssb  <- as.matrix(read_excel(data_file, sheet = "obsSSB",  col_names = FALSE))
wat      <- as.matrix(read_excel(data_file, sheet = "wat",     col_names = FALSE))
pmat     <- as.matrix(read_excel(data_file, sheet = "pmat",    col_names = FALSE))

# Total catch from WCVI2022data (kt)
wcvi     <- read_excel(catch_file, sheet = "WCVI2022data")
catch_kt <- wcvi$Catch

out_file <- "wcvi_wham.dat"
con  <- file(out_file, "w")
wl   <- function(...) cat(paste(...), "\n", file = con, sep = "")
wr   <- function(x)   cat(paste(x, collapse = "  "), "\n", file = con, sep = "")

# =============================================================================
# DIMENSIONS
# =============================================================================
first_yr <- 1951
last_yr  <- 2022
years    <- first_yr:last_yr
n_years  <- length(years)   # 72
n_ages   <- 9               # ages 2-10 (10 = plus group)
n_fleets <- 1
n_sel    <- 1
n_idx    <- 1

# Fleet Neff: 100 when catch > 0, 0 for zero-catch years
has_catch  <- catch_kt > 0
neff_fleet <- ifelse(has_catch, 100, 0)

# =============================================================================
# SECTION 1: HEADER
# =============================================================================
wl("# wcvi_wham.dat — WCVI herring")
wl("# ASAP3 format for WHAM")
wl("# Years: 1951-2022 | Ages: 2-10+ | Fleet: 1 | Index: 1 (survey SSB + age comp)")
wl("# Number of Years");             wl(n_years)
wl("# First year");                  wl(first_yr)
wl("# Number of ages");              wl(n_ages)
wl("# Number of fleets");            wl(n_fleets)
wl("# Number of selectivity blocks");wl(n_sel)
wl("# Number of available indices"); wl(n_idx)

# =============================================================================
# SECTION 2: NATURAL MORTALITY (M = 0.37, constant)
# =============================================================================
M_row <- rep(0.37, n_ages)
wl("# M matrix (M=0.37 constant all ages and years)")
for (i in 1:n_years) wr(M_row)

# =============================================================================
# SECTION 3: FECUNDITY + MATURITY
# =============================================================================
wl("# Fecundity option (0 = maturity x WAA)")
wl(0)
wl("# Fraction of year before SSB (tanasMsl=0.2885, ~April spawn)")
wl(0.2885)
wl("# MATURITY matrix (from pmat sheet, constant across years)")
for (i in 1:n_years) wr(round(pmat[i, ], 6))

# =============================================================================
# SECTION 4: WEIGHT AT AGE (time-varying, from wat sheet)
# =============================================================================
wl("# Number of WAA matrices"); wl(3)
wl("# WAA matrix-1 (fleet catch WAA, kg, time-varying)")
for (i in 1:n_years) wr(round(wat[i, ], 4))
wl("# WAA matrix-2 (discards — not used)")
for (i in 1:n_years) wr(round(wat[i, ], 4))
wl("# WAA matrix-3 (SSB / Jan-1 WAA)")
for (i in 1:n_years) wr(round(wat[i, ], 4))

# =============================================================================
# SECTION 5: WAA POINTERS
# =============================================================================
wl("# WEIGHT AT AGE POINTERS")
wl("1 # fleet 1 catch")
wl("2 # fleet 1 discards (not used)")
wl("1 # total catch")
wl("2 # total discards (not used)")
wl("3 # SSB")
wl("3 # Jan 1")

# =============================================================================
# SECTION 6: FLEET SELECTIVITY
# =============================================================================
logi_sel  <- function(ages, a50, slope) 1 / (1 + exp(-slope * (ages - a50)))
ages_vec  <- 2:10
sel_fleet  <- logi_sel(ages_vec, a50 = 3, slope = 1.5)
sel_survey <- logi_sel(ages_vec, a50 = 3, slope = 1.5)

# Fleet selectivity block assignment — block 1 all years
wl("# Selectivity block assignment — Fleet 1 (block 1 all years)")
for (i in 1:n_years) wl(1)

# Selectivity option: 2 = logistic
wl("# Selectivity Options (2=logistic)")
wl(2)

# Fleet sel block: n_ages x 2 rows (ascending + descending)
wl("# Selectivity Block 1 — Fishery logistic (a50=3, slope=1.5)")
for (a in 1:n_ages) {
  wl(round(sel_fleet[a], 4), "1  0  1")   # ascending: phase=1 (estimated)
  wl("1.0  -1  0  1")                     # descending: fixed (no dome)
}

wl("# Selectivity start age by fleet"); wl(2)
wl("# Selectivity end age by fleet");   wl(10)
wl("# Age range for average F");        wl(4, 8)
wl("# Average F report option");        wl(1)
wl("# Use likelihood constants?");      wl(0)
wl("# Release Mortality by fleet");     wl(0)

# =============================================================================
# SECTION 7: CATCH DATA
# =============================================================================
wl("# Catch Data — Fleet 1")
wl("# Format: age2 age3 ... age10  total_catch_kt")
wl("# Zero-catch years: all zeros, Neff=0 in lambdas section")
for (i in 1:n_years) {
  if (has_catch[i]) {
    wr(c(round(obs_cat[i, ], 4), round(catch_kt[i], 4)))
  } else {
    wr(rep(0, n_ages + 1))
  }
}

# =============================================================================
# SECTION 8: FLEET-1 DISCARDS (all zeros)
# =============================================================================
wl("# Fleet-1 Discards (all zeros — no discards)")
for (i in 1:n_years) wr(rep(0, n_ages + 1))

# =============================================================================
# SECTION 9: FLEET-1 RELEASE DATA (all zeros — required by parser)
# =============================================================================
wl("# Fleet-1 Release Data (all zeros)")
for (i in 1:n_years) wr(rep(0, n_ages + 1))

# =============================================================================
# SECTION 10: SURVEY INDEX
# =============================================================================
wl("# Survey Index Data")

# ── Index header (10 lines, 1 value per index) ────────────────────────────────
wl("# Aggregate Index Units (1=biomass, 2=numbers)")
wl("1")        # biomass (kt)
wl("# Age Proportion Index Units (1=biomass, 2=numbers)")
wl("2")        # numbers
wl("# Weight at Age Matrix pointer")
wl("3")
wl("# Index Month (April = 4)")
wl("4")
wl("# Index Selectivity Link to Fleet (-1 = independent)")
wl("-1")
wl("# Index Selectivity Options (2=logistic)")
wl("2")
wl("# Index Start Age")
wl("2")
wl("# Index End Age")
wl("10")
wl("# Estimate Proportion (1=yes)")
wl("1")
wl("# Use Index (1=yes)")
wl("1")

# ── Survey selectivity block ──────────────────────────────────────────────────
wl("# Survey Selectivity (logistic a50=3, slope=1.5, estimated)")
for (a in 1:n_ages) {
  wl(round(sel_survey[a], 4), "1  0  1")   # ascending: phase=1 (estimated)
  wl("1.0  -1  0  1")                      # descending: fixed
}

# ── Survey data rows (all n_years) ───────────────────────────────────────────
wl("# Survey Data (obsSSB aggregate + Nagedt age comp)")
wl("# Format: year  obs  cv  age2_prop...age10_prop  Neff")
for (i in 1:n_years) {
  yr       <- years[i]
  obs      <- round(obs_ssb[i, 1], 4)
  cv       <- 0.1
  paa      <- nagedt[i, ]
  paa_norm <- round(paa / sum(paa), 6)
  wr(c(yr, obs, cv, paa_norm, 100))
}

# =============================================================================
# SECTION 11: PHASE DATA
# =============================================================================
wl("#########################################")
wl("# Phase data")
wl("# Phase for Fmult in 1st year");          wl(-1)   # fixed at 0.05
wl("# Phase for Fmult deviations");           wl(3)
wl("# Phase for recruitment deviations");     wl(3)
wl("# Phase for N in 1st year");              wl(2)
wl("# Phase for catchability in 1st year");   wl(1)
wl("# Phase for catchability deviations");    wl(-1)
wl("# Phase for stock recruit relationship"); wl(1)
wl("# Phase for steepness");                  wl(-2)

# =============================================================================
# SECTION 12: LAMBDAS AND CVs
# =============================================================================
wl("#########################################")
wl("# Lambdas and CVs")
wl("# Recruitment CV by year (0.5 all years)")
for (i in 1:n_years) wl(0.5)
wl("# Lambda for each index"); wl(1)
wl("# Lambda for total catch in weight by fleet"); wl(1)
wl("# Lambda for total discards by fleet"); wl(0)
wl("# Catch total CV by year and fleet (0.05 all years)")
for (i in 1:n_years) wl(0.05)
wl("# Discard total CV by year and fleet")
for (i in 1:n_years) wl(0)
wl("# Input effective sample size catch at age (100 when catch>0, else 0)")
for (i in 1:n_years) wl(neff_fleet[i])
wl("# Input effective sample size discards at age")
for (i in 1:n_years) wl(0)
wl("# Lambda for Fmult in first year");         wl(0)
wl("# CV for Fmult in first year");             wl(1)
wl("# Lambda for Fmult deviations");            wl(0)
wl("# CV for Fmult deviations");               wl(1)
wl("# Lambda for N in 1st year deviations");    wl(0)
wl("# CV for N in 1st year deviations");        wl(1)
wl("# Lambda for recruitment deviations");      wl(1)
wl("# Lambda for catchability in first year");  wl(0)
wl("# CV for catchability in first year");      wl(1)
wl("# Lambda for catchability deviations");     wl(0)
wl("# CV for catchability deviations");         wl(1)
wl("# Lambda for deviation from initial steepness"); wl(0)
wl("# CV for deviation from initial steepness");     wl(1)
wl("# Lambda for deviation from initial SSB0");      wl(0)
wl("# CV for deviation from initial SSB0");          wl(1)
wl("# NAA Deviations flag");                         wl(1)

# =============================================================================
# SECTION 13: INITIAL GUESSES
# =============================================================================
# NAA: exponential decline from R0=500 with M=0.37, ages 2-10+
M_init   <- 0.37
R0_init  <- 500
naa_init <- R0_init * exp(-M_init * (0:(n_ages - 2)))
naa_init <- c(naa_init,
              naa_init[n_ages - 1] * exp(-M_init) / (1 - exp(-M_init)))

wl("#########################################")
wl("### Initial Guesses")
wl("# NAA for year 1 (1951) — exponential decline R0=500, M=0.37")
wr(round(naa_init, 1))
wl("# Fmult in 1st year (fixed at 0.05, phase=-1)"); wl(0.05)
wl("# Catchability in 1st year (q_survey=0.717612589)")
wl(0.717612589)
wl("# S-R Unexploited (1=Beverton-Holt)");   wl(1)
wl("# Unexploited initial guess");            wl(1e+06)
wl("# Steepness initial guess (fixed)");      wl(0.85)
wl("# Maximum F");                            wl(3)
wl("# Ignore guesses");                       wl(0)

wl("#########################################")
wl("### Projection Control data")
wl("# Do projections"); wl(0)
wl("# Fleet directed flag"); wl(1)
wl("# Final year of projections"); wl(2024)
wl("# Year, projected recruits, what projected, target, non-directed Fmult")
wl("2023  -1  3  -99  0")
wl("2024  -1  3  -99  0")

wl("#########################################")
wl("### MCMC Control data")
wl("# do mcmc");                         wl(0)
wl("# MCMC nyear option");               wl(0)
wl("# MCMC number of saved iterations"); wl(1000)
wl("# MCMC thinning rate");              wl(200)
wl("# MCMC random number seed");         wl(5230547)

wl("#########################################")
wl("### AGEPRO specs")
wl("# R in agepro.bsn file");               wl(0)
wl("# Starting year for calculation of R"); wl(2010)
wl("# Ending year for calculation of R");   wl(2022)
wl("# Export to R flag");                   wl(1)
wl("# test value");                         wl(-23456)
wl("#########################################")
wl("###### FINIS ######")
wl("# Fleet Names");  wl("fishery_wcvi")
wl("# Survey Names"); wl("survey_ssb")

# =============================================================================
close(con)
n_lines <- length(readLines(out_file))
cat("=============================================\n")
cat("COMPLETE: wcvi_wham.dat written\n")
cat("File  :", out_file, "\n")
cat("Lines :", n_lines, "\n")
cat("=============================================\n")
cat("Model structure:\n")
cat("  Years  :", first_yr, "-", last_yr, "(", n_years, ")\n")
cat("  Ages   : 2-10+ (", n_ages, ")\n")
cat("  Fleet  : 1 (commercial, Neff=100 when catch>0)\n")
cat("  Index  : 1 (obsSSB + Nagedt, CV=0.1, Neff=100)\n")
cat("  M      : 0.37 constant\n")
cat("  fracSSB: 0.2885\n\n")
cat("Next steps:\n")
cat("  library(wham)\n")
cat("  asap3 <- read_asap3_dat('wcvi_wham.dat')\n")
cat("  input <- prepare_wham_input(asap3)\n")
cat("  fit   <- fit_wham(input, do.retro=FALSE, do.osa=FALSE, do.sdrep=FALSE)\n")
