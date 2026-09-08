# Accessibility tests for the book's figure palette.
#
#   Rscript scripts/check_palette.R
#
# Base R only, no packages, so it runs before renv::restore() has finished and
# on any machine with R on it. Three questions:
#
#   1. Can someone with colour vision deficiency tell the series apart?
#      Simulate protanopia, deuteranopia and tritanopia (Machado, Oliveira &
#      Fernandes 2009, severity 1.0) and score every pair by CIEDE2000.
#   2. Can someone reading a photocopy? Compare L* between adjacent colours.
#   3. Is a thin line visible at all? WCAG 1.4.11 asks for 3:1 against white
#      for graphical objects.
#
# Change the palette at the bottom, re-run, and update the header comment in
# R/nus_theme.R to whatever this prints.

hex_to_rgb <- function(hex) {
  h <- sub("^#", "", hex)
  strtoi(substring(h, c(1, 3, 5), c(2, 4, 6)), 16L) / 255
}

srgb_to_linear <- function(c) ifelse(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055)^2.4)
linear_to_srgb <- function(c) {
  c <- pmin(pmax(c, 0), 1)
  ifelse(c <= 0.0031308, c * 12.92, 1.055 * c^(1 / 2.4) - 0.055)
}

# sRGB primaries against the D65 white point.
XYZ_FROM_LINEAR <- matrix(
  c(0.4124564, 0.3575761, 0.1804375,
    0.2126729, 0.7151522, 0.0721750,
    0.0193339, 0.1191920, 0.9503041),
  nrow = 3, byrow = TRUE
)
WHITE_D65 <- c(0.95047, 1.0, 1.08883)

rgb_to_lab <- function(rgb) {
  xyz <- as.vector(XYZ_FROM_LINEAR %*% srgb_to_linear(rgb)) / WHITE_D65
  f <- ifelse(xyz > (6 / 29)^3, xyz^(1 / 3), xyz / (3 * (6 / 29)^2) + 4 / 29)
  c(116 * f[2] - 16, 500 * (f[1] - f[2]), 200 * (f[2] - f[3]))
}

# CIE Delta E 2000. Long, unlovely, and the only perceptual distance worth
# quoting — the 1976 version badly overstates differences among saturated
# blues, which is most of this palette.
ciede2000 <- function(lab1, lab2) {
  L1 <- lab1[1]; a1 <- lab1[2]; b1 <- lab1[3]
  L2 <- lab2[1]; a2 <- lab2[2]; b2 <- lab2[3]

  C1 <- sqrt(a1^2 + b1^2); C2 <- sqrt(a2^2 + b2^2)
  Cb <- (C1 + C2) / 2
  G  <- if (Cb > 0) 0.5 * (1 - sqrt(Cb^7 / (Cb^7 + 25^7))) else 0

  a1p <- (1 + G) * a1; a2p <- (1 + G) * a2
  C1p <- sqrt(a1p^2 + b1^2); C2p <- sqrt(a2p^2 + b2^2)
  h1p <- (atan2(b1, a1p) * 180 / pi) %% 360
  h2p <- (atan2(b2, a2p) * 180 / pi) %% 360

  dLp <- L2 - L1
  dCp <- C2p - C1p
  dhp <- if (C1p * C2p == 0) 0
         else if (abs(h2p - h1p) <= 180) h2p - h1p
         else if (h2p - h1p > 180) h2p - h1p - 360
         else h2p - h1p + 360
  dHp <- 2 * sqrt(C1p * C2p) * sin(dhp * pi / 180 / 2)

  Lbp <- (L1 + L2) / 2
  Cbp <- (C1p + C2p) / 2
  hbp <- if (C1p * C2p == 0) h1p + h2p
         else if (abs(h1p - h2p) <= 180) (h1p + h2p) / 2
         else if (h1p + h2p < 360) (h1p + h2p + 360) / 2
         else (h1p + h2p - 360) / 2

  Tt <- 1 - 0.17 * cos((hbp - 30) * pi / 180) +
            0.24 * cos((2 * hbp) * pi / 180) +
            0.32 * cos((3 * hbp + 6) * pi / 180) -
            0.20 * cos((4 * hbp - 63) * pi / 180)

  dTh <- 30 * exp(-((hbp - 275) / 25)^2)
  Rc  <- if (Cbp > 0) 2 * sqrt(Cbp^7 / (Cbp^7 + 25^7)) else 0
  Sl  <- 1 + (0.015 * (Lbp - 50)^2) / sqrt(20 + (Lbp - 50)^2)
  Sc  <- 1 + 0.045 * Cbp
  Sh  <- 1 + 0.015 * Cbp * Tt
  Rt  <- -sin((2 * dTh) * pi / 180) * Rc

  sqrt((dLp / Sl)^2 + (dCp / Sc)^2 + (dHp / Sh)^2 +
       Rt * (dCp / Sc) * (dHp / Sh))
}

CVD <- list(
  protan = matrix(c( 0.152286,  1.052583, -0.204868,
                     0.114503,  0.786281,  0.099216,
                    -0.003882, -0.048116,  1.051998), nrow = 3, byrow = TRUE),
  deutan = matrix(c( 0.367322,  0.860646, -0.227968,
                     0.280085,  0.672501,  0.047413,
                    -0.011820,  0.042940,  0.968881), nrow = 3, byrow = TRUE),
  tritan = matrix(c( 1.255528, -0.076749, -0.178779,
                    -0.078411,  0.930809,  0.147602,
                     0.004733,  0.691367,  0.303900), nrow = 3, byrow = TRUE)
)

simulate_cvd <- function(rgb, kind) {
  linear_to_srgb(as.vector(CVD[[kind]] %*% srgb_to_linear(rgb)))
}

relative_luminance <- function(rgb) sum(srgb_to_linear(rgb) * c(0.2126, 0.7152, 0.0722))

contrast_ratio <- function(fg, bg = c(1, 1, 1)) {
  a <- relative_luminance(fg); b <- relative_luminance(bg)
  (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

check_palette <- function(name, palette) {
  rgbs <- lapply(palette, hex_to_rgb)
  labs <- lapply(rgbs, rgb_to_lab)
  Ls   <- round(vapply(labs, `[`, numeric(1), 1), 1)

  cat("\n=== ", name, " ===\n", sep = "")
  cat("hex :", palette, "\n")
  cat("L*  :", Ls, "\n")

  gaps <- round(diff(sort(Ls)), 1)
  cat("sorted L* gaps:", gaps, " min:", min(gaps), "\n")
  cat("contrast vs white:", round(vapply(rgbs, contrast_ratio, numeric(1)), 2), "\n")

  worst_overall <- Inf
  for (cond in c("normal", "protan", "deutan", "tritan")) {
    sim <- if (cond == "normal") rgbs else lapply(rgbs, simulate_cvd, kind = cond)
    sl  <- lapply(sim, rgb_to_lab)

    worst <- Inf; pair <- c("", "")
    for (i in seq_along(palette)) {
      for (j in seq_along(palette)) {
        if (j <= i) next
        d <- ciede2000(sl[[i]], sl[[j]])
        if (d < worst) { worst <- d; pair <- c(palette[i], palette[j]) }
      }
    }
    worst_overall <- min(worst_overall, worst)
    cat(sprintf("  %-7s min dE00 = %5.1f  (%s vs %s)\n", cond, worst, pair[1], pair[2]))
  }
  cat(sprintf("  WORST across all conditions: %.1f\n", worst_overall))
  invisible(list(min_gap = min(gaps), worst_dE00 = worst_overall))
}

if (sys.nframe() == 0L) {
  check_palette(
    "NUS discrete series",
    c("#003D7C", "#96233F", "#007E96", "#E8720C", "#BFC6CE")
  )
}
