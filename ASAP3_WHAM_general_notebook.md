# ASAP3 dat File Construction Guide for WHAM
## General Reference — How to Fill Each Section

---

## DIMENSION SUMMARY

Every section must be consistent with these 6 numbers declared in the header.
Check these first if anything goes wrong.

| Symbol | Meaning | Example |
|---|---|---|
| `n_years` | Total years in model | 46 |
| `first_yr` | First calendar year | 1978 |
| `n_ages` | Number of age classes including plus group | 24 |
| `n_fleets` | Number of fishing fleets | 1 |
| `n_sel` | Number of **fleet** selectivity blocks | 1 |
| `n_idx` | Number of survey/CPUE indices | 2 |

---

## 1. Header

**Size: 6 single values (one per line)**

```
# Number of Years
46                 ← n_years
# First year
1978               ← first_yr
# Number of ages
24                 ← n_ages (includes plus group)
# Number of fleets
1                  ← n_fleets
# Number of selectivity blocks
1                  ← n_sel (fleet blocks only — do NOT count index sel blocks here)
# Number of available indices
2                  ← n_idx
```

---

## 2. Natural Mortality Matrix

**Size: n_years rows × n_ages columns**

```
# M matrix
0.18  0.18  ...  0.18    ← row 1 (year 1): n_ages values
0.18  0.18  ...  0.18    ← row 2 (year 2): n_ages values
...                       ← one row per year: n_years rows total
0.18  0.18  ...  0.18    ← row n_years (last year)
```

**Rules:**
- Constant M: copy the same row `n_years` times
- Age-varying but time-constant M: copy the same age vector `n_years` times
- Fully time-varying M: enter the actual `n_years × n_ages` matrix
- This is the **starting value** — WHAM can estimate M via `prepare_wham_input(M=list(...))`

---

## 3. Fecundity and Maturity

**Size: 1 + 1 + (n_years rows × n_ages columns)**

```
# Fecundity option (1 value)
0                        ← 0 = SSB = maturity × WAA
                            1 = use maturity values directly as eggs per individual

# Fraction of year before SSB calculation (1 value)
0.4167                   ← spawn_month / 12
                            Jan=0.083  Apr=0.333  May=0.417  Jul=0.583

# Maturity matrix (n_years rows × n_ages columns)
0  0.10  0.28  0.53  ...    ← row 1 (year 1): n_ages values, range 0–1
0  0.10  0.28  0.53  ...    ← row 2 (year 2)
...                          ← n_years rows total
```

**Rules:**
- Constant maturity: copy the same row `n_years` times
- Time-varying maturity: enter the full matrix

---

## 4. Weight at Age Matrices

**Size: 1 value (n_matrices) + n_matrices × (n_years rows × n_ages columns)**

```
# Number of WAA matrices (1 value)
3                            ← minimum 2, standard is 3

# WAA matrix-1  (fleet catch WAA)
0.18  0.24  0.29  ...        ← row 1 (year 1): n_ages values, in kg
0.18  0.24  0.29  ...        ← row 2 (year 2)
...                           ← n_years rows total

# WAA matrix-2  (discards WAA)
...                           ← n_years rows × n_ages columns
                                 (all zeros if no discards)

# WAA matrix-3  (SSB / Jan-1 WAA)
...                           ← n_years rows × n_ages columns
```

**Rules:**
- Each matrix is exactly `n_years × n_ages`
- Constant WAA: copy the same row `n_years` times
- Time-varying WAA: enter the actual time series
- Units must match catch units (kg WAA + catch in tonnes → population in thousands)

---

## 5. WAA Pointers

**Size: always exactly 6 lines, one integer per line**

```
# WAA pointers
1    ← fleet 1 catch WAA        (integer: which matrix from Section 4)
2    ← fleet 1 discards WAA
1    ← total catch WAA (all fleets)
2    ← total discards WAA
3    ← SSB WAA
3    ← Jan-1 biomass WAA
```

**Rules:**
- Always exactly 6 lines regardless of n_fleets
- Integer must be ≤ number of WAA matrices declared in Section 4
- If all WAA identical: use `1` for all 6 lines

---

## 6. Fleet Selectivity Block Assignments

**Size: n_years rows × n_fleets columns**

```
# Fleet selectivity block assignments
1    ← year 1: fleet 1 uses block 1   (1 value if n_fleets=1)
1    ← year 2
1    ← year 3
...  ← one row per year
1    ← year n_years
```

For **n_fleets = 2**, each row has 2 space-separated values:
```
1  1    ← year 1: fleet 1 uses block 1, fleet 2 uses block 1
1  2    ← year 2: fleet 1 uses block 1, fleet 2 uses block 2
...
```

**Rules:**
- Total rows = `n_years` (one per year, no exceptions)
- Constant selectivity: write the same block number every year
- Time-varying selectivity blocks: the block number changes across years
- Block numbers must be integers between 1 and `n_sel`

---

## 7. Selectivity Options

**Size: 1 row with n_sel space-separated values**

```
# Selectivity options (1 value per block)
2              ← if n_sel=1: single value
2  2  1        ← if n_sel=3: one value per block
```

| Code | Form | n_ages × 2 rows per block |
|---|---|---|
| 1 | Age-specific | 1 parameter per age |
| 2 | Single logistic | a50 + slope |
| 3 | Double logistic | a50_asc + slope_asc + a50_desc + slope_desc |

---

## 8. Selectivity Block Data

**Size per block: n_ages × 2 rows, 4 columns each**
**Total rows for all fleet blocks: n_sel × n_ages × 2**

Each age contributes exactly 2 rows — ascending then descending:

```
# Block 1 — logistic (option 2)
# n_ages × 2 = 24 × 2 = 48 rows for n_ages=24

0.0100  1   0   1    ← age 1 ascending:  sel_value | phase | lower | upper
1.0000  -1  0   1    ← age 1 descending: fixed at 1.0 (no dome)
0.0270  1   0   1    ← age 2 ascending
1.0000  -1  0   1    ← age 2 descending
0.0707  1   0   1    ← age 3 ascending
1.0000  -1  0   1    ← age 3 descending
...                  ← continue for all n_ages (48 rows total for n_ages=24)
```

**Column meanings:**

| Column | Meaning | Typical values |
|---|---|---|
| 1 | Initial sel value (0–1) | Computed from logistic formula |
| 2 | Phase: `1`=estimate, `−1`=fix | 1 for ascending, −1 for descending |
| 3 | Lower bound | 0 |
| 4 | Upper bound | 1 |

**Computing initial logistic values in R:**
```r
# slope = log(19) / width95
# where width95 = age spread from 5% to 95% selectivity
logi_sel <- function(ages, a50, slope) 1 / (1 + exp(-slope * (ages - a50)))
sel_vals  <- round(logi_sel(1:n_ages, a50 = 5.55, slope = 1.01), 4)
```

**For n_sel > 1** — write each block sequentially:
```
# Block 1 (n_ages × 2 rows)
...
# Block 2 (n_ages × 2 rows)
...
```

**Age-specific format (option 1):**
```
# Block 1 — age-specific (option 1)
# n_ages × 2 = 48 rows for n_ages=24

0.10  1   0   1    ← age 1 ascending (estimated)
1.00  -1  0   1    ← age 1 descending (fixed)
0.50  1   0   1    ← age 2 ascending (estimated)
1.00  -1  0   1    ← age 2 descending (fixed)
1.00  -1  0   1    ← age at full sel — MUST FIX at least one age to 1.0
1.00  -1  0   1    ← same
...
```

---

## 9. Fleet Metadata

**Size: 6 lines, n_fleets values per line**

```
# Selectivity start age by fleet (n_fleets values)
1              ← age 1 (youngest age in sel comparison)

# Selectivity end age by fleet (n_fleets values)
24             ← n_ages (oldest age)

# Age range for average F: start age  end age (2 values)
5  15          ← ages used to compute Fbar output

# Average F report option (1 value)
1              ← 1=unweighted  2=N-weighted  3=B-weighted

# Use likelihood constants? (1 value)
0              ← 0=no (faster, use for development)  1=yes (use for final runs)

# Release mortality by fleet (n_fleets values)
0              ← fraction of released fish that die (0 if no discards)
```

---

## 10. Catch Data

**Size: n_years rows × (n_ages + 1) columns**

Last column = total catch in weight. First n_ages columns = catch at age in numbers.

```
# Catch Data — Fleet 1
# n_years rows, each row has n_ages + 1 values

0  0  0  ...  0   3621     ← year 1: no age comp (zeros) | total catch = 3621 t
0  0  0  ...  0   2602     ← year 2: no age comp | total = 2602 t
...
7240  59973  196090  ...  0   26217   ← year 13 (1990): age comp present | total = 26217 t
...
0  0  0  ...  0   10047    ← last year: no age comp | total = 10047 t
```

**Rules:**
- Exactly `n_years` rows, exactly `n_ages + 1` values per row
- Age comp = raw **numbers** (not proportions) — WHAM normalises internally
- Years without age comp: write `0` for all `n_ages` age columns, keep correct total
- Total catch column is always in weight (kg or tonnes, consistent with WAA)
- For **n_fleets > 1**: write fleet 1 block (n_years rows), then fleet 2 block (n_years rows), etc.

---

## 11. Fleet Discards Data

**Size: n_fleets × (n_years rows × (n_ages + 1) columns)**

```
# Fleet-1 Discards
# n_years rows, n_ages + 1 values per row

0  0  0  ...  0  0     ← year 1: all zeros (no discards)
0  0  0  ...  0  0     ← year 2
...                     ← n_years rows total
```

All zeros if no discards are included in the model.

---

## 12. Fleet Release Data

**Size: n_fleets × (n_years rows × (n_ages + 1) columns)**
**REQUIRED by the parser even if all zeros. Omitting this causes a silent desync.**

```
# Fleet-1 Release Data
# n_years rows, n_ages + 1 values per row

0  0  0  ...  0  0     ← year 1: all zeros
0  0  0  ...  0  0     ← year 2
...                     ← n_years rows total
```

---

## 13. Index Header Block

**Size: exactly 10 lines, each with n_idx space-separated values**

Written once, before any index sel blocks or data rows.
Values are in index order (index 1 first, index 2 second, etc.).

```
# Aggregate Index Units (n_idx values)
2  1
```
| Code | Predicted index computed as |
|---|---|
| 1 | Biomass: sum(N × WAA × sel) |
| 2 | Numbers: sum(N × sel) |

```
# Age Proportion Index Units (n_idx values)
2  1
```
Same codes as above, applied to the age comp predictions.

```
# Weight at Age Matrix pointer (n_idx values)
3  3                   ← which WAA matrix to use for each index (integer from Section 4)
```

```
# Index Month (n_idx values)
7  7                   ← survey month: 1=Jan  4=Apr  7=Jul  10=Oct
                          used to apply fraction of annual Z before the survey
```

```
# Index Selectivity Link to Fleet (n_idx values)
-1  -1                 ← −1 = index has own sel block (Section 14)
                          1, 2, ... = index uses fleet 1, 2, ... selectivity
```

```
# Index Selectivity Options (n_idx values)
2  2                   ← same codes as Section 7: 1=age-specific  2=logistic  3=double-logistic
                          only matters when sel_link = −1
```

```
# Index Start Age (n_idx values)
1  1                   ← youngest age in index (usually 1 or first age in model)

# Index End Age (n_idx values)
24  24                 ← oldest age in index (usually n_ages)
```

```
# Estimate Proportion at Age (n_idx values)
1  0                   ← 1 = index has age comp, include PAA likelihood
                          0 = aggregate index only, no age comp
```

```
# Use Index (n_idx values)
1  1                   ← 1 = use this index  0 = exclude from this run
```

---

## 14. Index Selectivity Blocks

**Size: n_idx blocks, each n_ages × 2 rows, 4 columns**
**Total rows: n_idx × n_ages × 2**

Written in index order. Same row format as fleet sel blocks (Section 8).
Must be written for **every** index including those with sel_link > 0 (the parser expects them even if the values are unused).

```
# Index-1 Selectivity
# n_ages × 2 rows (e.g. 24 × 2 = 48 rows)

0.0100  1   0   1    ← age 1 ascending: phase=1 (estimated)
1.0000  -1  0   1    ← age 1 descending: fixed
0.0270  1   0   1    ← age 2 ascending
1.0000  -1  0   1    ← age 2 descending
...                  ← n_ages × 2 rows total

# Index-2 Selectivity
# n_ages × 2 rows

0.0285  -1  0   1    ← age 1 ascending: phase=−1 (fixed — no age comp)
1.0000  -1  0   1    ← age 1 descending: fixed
...                  ← n_ages × 2 rows total
```

**Rules:**
- Fix phases (−1) for indices with no age comp (e.g. CPUE)
- Estimate phases (1) for indices with age comp (e.g. scientific survey)
- If sel_link > 0: write the block anyway but all phases = −1 (values are ignored)

---

## 15. Index Data Rows

**Size: n_idx blocks, each n_years rows × (n_ages + 3) columns**
**Column order: year | obs | cv | age_1_prop | age_2_prop | ... | age_n_prop | Neff**

Written as `n_idx` sequential blocks, each covering all `n_years`.

```
# Index-1 Data
# n_years rows, columns: year  obs  cv  age1...age_n  Neff

1978  -999  -999  -999  -999  ...  -999  -999    ← completely missing year: ALL values = −999
...
1997   1.000  0.2   0  0  0  ...  0   0          ← aggregate only: ages=0, Neff=0
1998   0.707  0.2   0  0  0  ...  0   0
...
2001  199980  0.1  0.001  0.006  ...  0.000  30  ← full data: real obs, cv, paa, Neff>0
2002  179600  0.1  0.000  0.002  ...  0.000  30
...
2004    -999  -999  0.000  0.008  ...  0.000  30  ← age comp only: obs/cv=−999, real paa, Neff>0
...
2010    -999  -999  -999  -999  ...  -999  -999   ← completely missing: ALL −999
...
2023    -999  -999  -999  -999  ...  -999  -999   ← last year if missing

# Index-2 Data
# n_years rows, same column structure

1978  -999  -999  -999  -999  ...  -999  -999
...
```

**Four data row types:**

| Row type | obs | cv | age props | Neff | Effect |
|---|---|---|---|---|---|
| Full data | real | real | real (normalised) | > 0 | Both aggregate and age comp in likelihood |
| Aggregate only | real | real | 0...0 | 0 | Only aggregate in likelihood |
| Age comp only | −999 | −999 | real (normalised) | > 0 | Only age comp in likelihood |
| Completely missing | −999 | −999 | −999...−999 | −999 | Excluded entirely |

**Rules:**
- Exactly `n_years` rows per index block — every year must appear, no skipping
- `n_idx` blocks written in sequence, each with all `n_years` rows
- Age proportions: write raw numbers and WHAM normalises, OR write proportions directly (must sum to 1)
- Neff = 0 (not −999) when the index has aggregate data but no age comp for that year
- Neff = −999 only when the **entire** year is missing

---

## 16. Phase Data

**Size: exactly 8 single values**

```
# Phase for Fmult in 1st year (1 value)
-1         ← −1 = fixed at initial guess  |  1 = estimated
              Fix if early years have no age comp (F poorly identified)

# Phase for Fmult deviations (1 value)
3          ← estimate late (after F and N are roughly identified)

# Phase for recruitment deviations (1 value)
3

# Phase for N in 1st year (1 value)
2          ← estimate in second phase

# Phase for catchability in 1st year (1 value)
1          ← estimate early

# Phase for catchability deviations (1 value)
-1         ← −1 = q constant  |  1 = q time-varying

# Phase for stock-recruit relationship (1 value)
1

# Phase for steepness (1 value)
-2         ← almost always fix; estimate only with strong SSB contrast
```

---

## 17. Lambdas and CVs

Each line controls one data component. Dimensions are noted on each line.

```
# Recruitment CV by year
0.5         ← repeated n_years times (one value per line)
0.5
...         ← n_years values total

# Lambda for each index (n_idx values on one line)
1  1        ← one value per index

# Lambda for total catch in weight by fleet (n_fleets values on one line)
1

# Lambda for total discards by fleet (n_fleets values on one line)
0           ← 0 if no discards

# Catch total CV by year and fleet (n_years values, one per line)
0.05
0.05
...         ← n_years values total

# Discard total CV by year and fleet (n_years values, one per line)
0
...         ← n_years values total

# Input effective sample size — catch at age (n_years values, one per line)
15          ← Neff > 0 for years with age comp
0           ← 0 for years without age comp
...         ← n_years values total

# Input effective sample size — discards at age (n_years values, one per line)
0
...         ← n_years values total
```

**Remaining lines — all single values or n_idx values:**
```
# Lambda for Fmult in first year (n_fleets values)
0
# CV for Fmult in first year (n_fleets values)
1
# Lambda for Fmult deviations (n_fleets values)
0
# CV for Fmult deviations (n_fleets values)
1
# Lambda for N in 1st year deviations (1 value)
0
# CV for N in 1st year deviations (1 value)
1
# Lambda for recruitment deviations (1 value)
1
# Lambda for catchability in first year (n_idx values)
0  0
# CV for catchability in first year (n_idx values)
1  1
# Lambda for catchability deviations (n_idx values)
0  0
# CV for catchability deviations (n_idx values)
1  1
# Lambda for deviation from initial steepness (1 value)
0
# CV for deviation from initial steepness (1 value)
1
# Lambda for deviation from initial SSB0 (1 value)
0
# CV for deviation from initial SSB0 (1 value)
1
# NAA Deviations flag (1 value)
1
```

**Lambda rules:**
- Lambda = 0: component excluded from objective function
- Lambda = 1: component included with standard weight
- CV controls tightness of fit — smaller CV = model must fit more tightly

---

## 18. Initial Guesses

```
# NAA for year 1 (1 row of n_ages values)
241556  199612  164952  ...  17309   ← one value per age

# Fmult in 1st year by fleet (n_fleets values)
0.05

# Catchability in 1st year by index (n_idx values)
0.000419  0.7490    ← one value per index, in index order

# S-R Unexploited specification (1 value)
1              ← 1 = Beverton-Holt  2 = Ricker

# Unexploited initial guess (1 value)
1e+07          ← R0 or SSB0 (large starting value, estimated)

# Steepness initial guess (1 value)
0.6

# Maximum F (1 value)
5

# Ignore guesses (1 value)
0              ← 0 = use values above  1 = ignore (use internal defaults)
```

**Computing initial NAA in R:**
```r
# Exponential decline from R0 with natural mortality M
naa_init      <- R0 * exp(-M * (0:(n_ages - 2)))
naa_init[n_ages] <- naa_init[n_ages-1] * exp(-M) / (1 - exp(-M))  # plus group
```

---

## 19. Projection, MCMC, AGEPRO Boilerplate

Standard block — change projection years and rules if running projections.

```
### Projection Control data
# Do projections (1 value)
0              ← 0=no  1=yes
# Fleet directed flag (n_fleets values)
1
# Final year of projections (1 value)
2025
# Projection rows: year  rec  rule  target  bycatch_mult
# One row per projection year
2024  -1  3  -99  0    ← year | −1=SR rec | 3=Fmsy | target (ignored) | bycatch
2025  -1  3  -99  0

### MCMC Control data
# do mcmc (1 value)
0
# MCMC nyear option (1 value)
0
# MCMC number of saved iterations (1 value)
1000
# MCMC thinning rate (1 value)
200
# MCMC random number seed (1 value)
5230547

### AGEPRO specs
# R in agepro.bsn file (1 value)
0
# Starting year for calculation of R (1 value)
2010
# Ending year for calculation of R (1 value)
2023
# Export to R flag (1 value)
1
# test value (1 value — do not change)
-23456
###### FINIS ######
```

---

## 20. Fleet and Survey Names

**Size: n_fleets lines then n_idx lines**

```
# Fleet Names (n_fleets lines, one name per line)
fishery_wcvi

# Survey Names (n_idx lines, one name per line)
cpue_index
survey_ssb
```

**Rules:**
- Names appear in output tables and plots
- No spaces — use underscores
- Order must match index order used throughout the file

---

## 21. Complete Dimension Checklist

Use this before running to verify every section:

| Section | Expected size | Formula |
|---|---|---|
| M matrix | n_years rows × n_ages cols | |
| Maturity matrix | n_years rows × n_ages cols | |
| Each WAA matrix | n_years rows × n_ages cols | |
| WAA pointers | 6 lines | always 6 |
| Sel block assignments | n_years rows × n_fleets cols | |
| Sel options | 1 row × n_sel values | |
| Each fleet sel block | n_ages × 2 rows, 4 cols | |
| Fleet metadata | 6 lines × n_fleets values | always 6 lines |
| Fleet catch | n_years rows × (n_ages+1) cols | |
| Fleet discards | n_years rows × (n_ages+1) cols | |
| Fleet release | n_years rows × (n_ages+1) cols | |
| Index header | 10 lines × n_idx values | always 10 lines |
| Each index sel block | n_ages × 2 rows, 4 cols | one block per index |
| Each index data block | n_years rows × (n_ages+3) cols | one block per index |
| Phase data | 8 lines | always 8 |
| Recruitment CV | n_years lines | |
| Lambda index | 1 line × n_idx values | |
| Lambda catch | 1 line × n_fleets values | |
| Catch CV | n_years lines × n_fleets values | |
| Neff catch | n_years lines × n_fleets values | |
| Lambda/CV remaining | 1 or n_idx values | see Section 17 |
| NAA year 1 | 1 row × n_ages values | |
| q initial | 1 row × n_idx values | |

---

## 22. prepare_wham_input sel_spec

The dat file phases are **overridden** by `sel_spec` in R. Always define it explicitly.

```r
# Total components = n_fleet_sel_blocks + n_idx
# Order: fleet_block_1, ..., fleet_block_n, index_1, ..., index_n

sel_spec <- list(
  model = c(
    "logistic",    # fleet block 1
    "logistic",    # index 1
    "logistic"     # index 2
  ),                            # n_sel + n_idx entries
  re = c("none", "none", "none"),
  initial_pars = list(
    c(a50, slope),   # fleet block 1
    c(a50, slope),   # index 1
    c(a50, slope)    # index 2
  ),
  fix_pars = list(
    NULL,   # fleet — estimate both
    1:2,    # index 1 — fix both (no age comp)
    NULL    # index 2 — estimate both (has age comp)
  )
)
```

**fix_pars for logistic (2 parameters: a50=1, slope=2):**

| fix_pars | Effect |
|---|---|
| `NULL` | Estimate both |
| `1` | Fix a50, estimate slope |
| `2` | Fix slope, estimate a50 |
| `1:2` | Fix both |

**re options:**

| re | Effect |
|---|---|
| `"none"` | Constant — no random effects |
| `"iid"` | Independent random variation each year |
| `"ar1"` | Autocorrelated across ages |
| `"ar1_y"` | Autocorrelated across years |
| `"2dar1"` | Autocorrelated across both ages and years |

---

## 23. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| Parser reads wrong values (silent desync) | Missing Release data block | Section 12: add `n_years` rows × `(n_ages+1)` zeros after Discards |
| Parser reads wrong values | Wrong number of rows in any matrix | Check every matrix against Section 21 checklist |
| Wrong index fits | Index order inconsistent | Header, sel blocks, data rows, q initial, names must all follow the same index order |
| `Length of selectivity$model must equal...` | Wrong sel_spec length | Must equal `n_sel + n_idx` |
| `Each selectivity$re entry must be one of...` | Typo in re string | Valid values: `"none"` `"iid"` `"ar1"` `"ar1_y"` `"2dar1"` |
| `dimensions of M$initial_means must be c(n_stocks,n_regions,n_ages)` | Wrong array dim in M list | Use `array(..., dim=c(1,1,n_ages))` not `c(1,1,n_groups)` |
| Hessian not invertible (sdrep fails) | Parameters not identified | Fix sel for indices without age comp; fix F year 1 if no early age comp |
| Selectivity stuck at initial values | sel_spec not passed or fix_pars wrong | sel_spec overrides dat file — verify fix_pars NULL vs 1:2 |
| q not moving | Catchability phase = −1 | Set phase = 1, or fix intentionally: `input$map$log_q <- factor(rep(NA, ...))` |
| `need finite ylim` in plot | NULL/NaN in rep quantities | Check `m1$rep$FAA`, `m1$rep$SSB`, `m1$rep$NAA` for NA/Inf first |
| All missing year Neff wrong | Neff = 0 for fully missing years | Fully missing rows: ALL values = −999 including Neff position |
