# =============================================================================
# wcvi_wham_exercise.R — WCVI herring WHAM model
# Model 1: recruitment RE only, multinomial age comp
# =============================================================================

library(wham)
cat("WHAM version:", as.character(packageVersion("wham")), "\n\n")

# ---- 0. Setup ----------------------------------------------------------------
# write.dir <- "wcvi_output"
# if (!dir.exists(write.dir)) dir.create(write.dir)

setwd("P:/pCloud Sync/_wham/Wham_models/herring")
# ---- 1. Read dat file --------------------------------------------------------
asap3 <- read_asap3_dat("wcvi_wham.dat")

# ---- 2. Selectivity ----------------------------------------------------------
# 2 components: fleet block 1, survey index 1
# Both logistic, both estimated
sel_spec <- list(
  model        = c("logistic", "logistic"),
  re           = c("none",     "none"),
  initial_pars = list(
    c(3, 1.5),   # Fleet  — a50=3, slope=1.5
    c(3, 1.5)    # Survey — a50=3, slope=1.5
  ),
  fix_pars = list(
    NULL,   # Fleet  — estimate both
    NULL    # Survey — estimate both
  )
)

# ---- 3. Prepare input --------------------------------------------------------
# input1 <- prepare_wham_input(
#   asap3,
#   recruit_model = 2,
#   model_name    = "wcvi: rec RE, multinomial",
#   selectivity   = sel_spec,
#   NAA_re        = list(sigma = "rec", cor = "iid")
# )

# input1$par$log_q[] <- log(0.817612589)
# # Set the value (on log scale internally)
# input1$map$log_q <- factor(rep(NA, length(input1$par$log_q)))


input1 <- prepare_wham_input(
  asap3,
  recruit_model = 2,
  model_name    = "wcvi: rec RE, dirichlet-miss0",
  selectivity   = sel_spec,
  NAA_re        = list(sigma = "rec", cor = "iid"),
  age_comp      = "dirichlet-miss0"    # add this line
)

# ---- 4. Fit model ------------------------------------------------------------
## this model estimates q
m1 <- fit_wham(input1, do.osa = FALSE, do.retro = F)

# ---- 5. Check convergence ----------------------------------------------------
cat("\n=== Convergence ===\n")
cat("opt$convergence :", m1$opt$convergence, "(0 = converged)\n")
cat("max |gradient|  :", max(abs(m1$final_gradient)), "\n")
cat("NLL             :", round(m1$opt$objective, 2), "\n")
stop()
# ---- 6. If converged, get SD report ------------------------------------------
# if (m1$opt$convergence == 0 & max(abs(m1$final_gradient)) < 1e-3) {
#   cat("\nRunning sdrep...\n")
#   m1 <- fit_wham(input1, do.retro = FALSE, do.osa = FALSE, do.sdrep = TRUE)
#   cat("sdrep done\n")
# }

m1$opt$par
sdrep_fixed <- as.data.frame(summary(m1$sdrep, select = "fixed"))
plogis(sdrep_fixed["logit_q", "Estimate"])
print(round(sdrep_fixed, 4))
names(m1$opt$par)

# # Derived/reported quantities
# sdrep_report <- as.data.frame(summary(m1$sdrep, select = "report"))
# print(round(sdrep_report, 4))
# plogis(m1$par$log_q) 

cat("\n=== Catchability ===\n")
print(m1$rep$q)

# Selectivity (a50 and slope, natural scale)
m1$rep$selpars

# Selectivity at age
m1$rep$selAA[[1]][1, ]   # fleet, year 1
m1$rep$selAA[[2]][1, ]   # survey, year 1


# ---- 8. Save and plot --------------------------------------------------------
# setwd(write.dir)
# save(m1, file = "wcvi_m1.RData")
# cat("\nModel saved to wcvi_output/wcvi_m1.RData\n")

# plot_wham_output(mod = m1)
# cat("Plots saved to:", getwd(), "\n")
# setwd("..")


# Quick manual plot avoiding the issue
years <- 1951:2022

x11()
par(mfrow = c(2,2))
plot(years, m1$rep$SSB, type="b", xlab="Year", ylab="SSB (kt)")

# Check F across all years
Fbar <- m1$rep$Fbar
plot(1951:2022, Fbar[,1], type="b",
     xlab="Year", ylab="Fbar",
     main="Annual F — should be ~0 for zero-catch years")
abline(h=0, col="red", lty=2)

# Identify zero-catch years
zero_catch_yrs <- c(1968:1971, 2001:2022)
points(zero_catch_yrs, Fbar[zero_catch_yrs - 1950],
       col="red", pch=16)

# Dimension check
dim(m1$rep$all_NAA)
# [1]  2  1  1 72  9
# dim1=2 (predicted vs RE), dim2=1 (stock), dim3=1 (region), dim4=72 (years), dim5=9 (ages)

# Extract NAA — use first slice (predicted)
NAA <- m1$rep$all_NAA[1, 1, 1, , ]   # n_years x n_ages matrix
dim(NAA)   # should be 72 x 9

# Recruitment = age 2 = first age column
Recruitment <- NAA[, 1]

plot(years, Recruitment, type="b", pch=16,
     xlab="Year", ylab="Numbers (age 2)", main="Recruitment")




## this model fixed q
# =============================================================
# STEP 1 — Build input
# =============================================================
input1 <- prepare_wham_input(
  asap3,
  recruit_model = 2,
  model_name    = "wcvi: rec RE, dirichlet-miss0",
  selectivity   = sel_spec,
  NAA_re        = list(sigma = "rec", cor = "iid"),
  age_comp      = "dirichlet-miss0"
)

# =============================================================
# STEP 2 — Check what is being estimated
# =============================================================
cat("=== Parameters being estimated ===\n")
est_pars <- names(input1$par)[sapply(names(input1$par), function(nm) {
  !all(is.na(input1$map[[nm]]))
})]
print(est_pars)

cat("\n=== Check q ===\n")
print(input1$map$logit_q)           # NA = fixed, number = estimated
print(plogis(input1$par$logit_q))   # current starting value

cat("\n=== Check F year 1 ===\n")
print(input1$map$F_pars)
print(exp(input1$par$F_pars[1]))

# =============================================================
# STEP 3 — Apply fixes
# =============================================================

# Fix q at VPA value
input1$par$logit_q[] <- qlogis(0.8)
input1$map$logit_q   <- factor(rep(NA, length(input1$par$logit_q)))

# Fix q random effects if present
input1$map$q_prior_re <- factor(rep(NA, length(input1$par$q_prior_re)))
input1$map$q_repars   <- factor(rep(NA, length(input1$par$q_repars)))

# Fix F year 1 at 0.05
input1$par$F_pars[1] <- log(0.05)
n_F <- length(input1$par$F_pars)
input1$map$F_pars    <- factor(c(NA, 1:(n_F - 1)))

# =============================================================
# STEP 4 — Verify fixes before fitting
# =============================================================
cat("\n=== Verification before fitting ===\n")
cat("logit_q map    :", as.character(input1$map$logit_q), "\n")
cat("q value        :", round(plogis(input1$par$logit_q), 6), "\n")
cat("F_pars map     :", as.character(input1$map$F_pars[1]), "\n")
cat("F year 1 value :", round(exp(input1$par$F_pars[1]), 4), "\n")
cat("n pars estimated:", sum(sapply(names(input1$map), function(nm) {
  m <- input1$map[[nm]]
  if (is.null(m)) return(length(input1$par[[nm]]))
  sum(!is.na(as.integer(levels(m)[m])))
})), "\n")

# =============================================================
# STEP 5 — Fit
# =============================================================
m1 <- fit_wham(input1, do.retro=FALSE, do.osa=FALSE, do.sdrep=T)

# =============================================================
# STEP 6 — Check after fitting
# =============================================================
cat("\n=== Post-fit checks ===\n")
cat("convergence :", m1$opt$convergence, "\n")
cat("max gradient:", max(abs(m1$final_gradient)), "\n")
cat("q           :", round(plogis(m1$par$logit_q), 6), "\n")  # should be 0.7176
cat("F year 1    :", round(exp(m1$par$F_pars[1]), 4), "\n")   # should be 0.05
cat("Parameters estimated:\n")
print(names(m1$opt$par))



# Quick manual plot avoiding the issue
years <- 1951:2022

x11()
par(mfrow = c(2,2))
plot(years, m1$rep$SSB, type="b", xlab="Year", ylab="SSB (kt)")

# Check F across all years
Fbar <- m1$rep$Fbar
plot(1951:2022, Fbar[,1], type="b",
     xlab="Year", ylab="Fbar",
     main="Annual F — should be ~0 for zero-catch years")
abline(h=0, col="red", lty=2)

# Identify zero-catch years
zero_catch_yrs <- c(1968:1971, 2001:2022)
points(zero_catch_yrs, Fbar[zero_catch_yrs - 1950],
       col="red", pch=16)

# Dimension check
dim(m1$rep$all_NAA)
# [1]  2  1  1 72  9
# dim1=2 (predicted vs RE), dim2=1 (stock), dim3=1 (region), dim4=72 (years), dim5=9 (ages)

# Extract NAA — use first slice (predicted)
NAA <- m1$rep$all_NAA[1, 1, 1, , ]   # n_years x n_ages matrix
dim(NAA)   # should be 72 x 9

# Recruitment = age 2 = first age column
Recruitment <- NAA[, 1]

plot(years, Recruitment, type="b", pch=16,
     xlab="Year", ylab="Numbers (age 2)", main="Recruitment")




