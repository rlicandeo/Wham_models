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

# Then fix it

input1 <- prepare_wham_input(
  asap3,
  recruit_model = 2,
  model_name    = "wcvi: rec RE, dirichlet-miss0",
  selectivity   = sel_spec,
  NAA_re        = list(sigma = "rec", cor = "iid"),
  age_comp      = "dirichlet-miss0"    # add this line
)

# ---- 4. Fit model ------------------------------------------------------------
m1 <- fit_wham(input1, do.osa = FALSE, do.retro = F)

# ---- 5. Check convergence ----------------------------------------------------
cat("\n=== Convergence ===\n")
cat("opt$convergence :", m1$opt$convergence, "(0 = converged)\n")
cat("max |gradient|  :", max(abs(m1$final_gradient)), "\n")
cat("NLL             :", round(m1$opt$objective, 2), "\n")

# ---- 6. If converged, get SD report ------------------------------------------
# if (m1$opt$convergence == 0 & max(abs(m1$final_gradient)) < 1e-3) {
#   cat("\nRunning sdrep...\n")
#   m1 <- fit_wham(input1, do.retro = FALSE, do.osa = FALSE, do.sdrep = TRUE)
#   cat("sdrep done\n")
# }

# ---- 7. Quick look at key estimates ------------------------------------------
cat("\n=== Selectivity parameters ===\n")
print(m1$rep$selpars)

cat("\n=== Catchability ===\n")
print(m1$rep$q)

# ---- 8. Save and plot --------------------------------------------------------
# setwd(write.dir)
# save(m1, file = "wcvi_m1.RData")
# cat("\nModel saved to wcvi_output/wcvi_m1.RData\n")

plot_wham_output(mod = m1)
cat("Plots saved to:", getwd(), "\n")
setwd("..")


# Catchability
exp(m1$par$log_q)

# Selectivity (a50 and slope, natural scale)
m1$rep$selpars

# Selectivity at age
m1$rep$selAA[[1]][1, ]   # fleet, year 1
m1$rep$selAA[[2]][1, ]   # survey, year 1

# Recruitment sigma
exp(m1$par$log_NAA_sigma)

# Mean recruitment (recruit_model=2)
exp(m1$par$mean_rec_pars)







