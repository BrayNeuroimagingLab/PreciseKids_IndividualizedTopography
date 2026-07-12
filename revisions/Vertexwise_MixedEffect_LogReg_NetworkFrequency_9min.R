# Vertex-wise mixed-effect logistic regression, child vs adult assignment frequency
# --- 9-MINUTE version (identical model to the 60-min Figure 4 analysis) ---
# Only the input assignment maps (9 min) and output dir differ.

library(ciftiTools)
library(lme4)
library(readxl)
library(dplyr)
library(purrr)

rm(list = ls())

wb_path <- "/Applications/workbench/bin_macosx64"
ciftiTools.setOption("wb_path", wb_path)

BASE            <- "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
OUTPUT_DIR_BASE <- file.path(BASE, "LogReg_MixedEffect_Uncorrectedoutputs_9min")
template_path   <- file.path(BASE, "Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii")
input_dir       <- file.path(BASE, "networkassignment_gradiation_9min")   # <-- 9-min binary maps
covar_csv       <- file.path(BASE, "prckids-motion_beh.xlsx")

networks        <- setdiff(1:16, c(4, 6))
skip_sub        <- "003"
motion_col      <- "censored_volumes"
bin_thresh      <- 0.5
wb_cmd          <- file.path(wb_path, "wb_command")
N_grayordinates <- 91282

dir.create(OUTPUT_DIR_BASE, showWarnings = FALSE, recursive = TRUE)

covars <- readxl::read_xlsx(covar_csv) %>%
  mutate(sub = trimws(as.character(sub)),
         sex01 = dplyr::recode(tolower(sex), "m" = 0L, "f" = 1L, .default = NA_integer_))
stopifnot(motion_col %in% names(covars), "family" %in% names(covars))
covars <- covars %>%
  mutate(motion = as.numeric(.data[[motion_col]]), family = factor(family)) %>%
  mutate(motion = (motion - mean(motion, na.rm = TRUE)) / sd(motion, na.rm = TRUE))

xtempl <- read_cifti(template_path)
labels <- as.integer(as.vector(as.matrix(xtempl)))
V <- length(labels)

subjects  <- sprintf("%03d", 2:26); subjects <- setdiff(subjects, skip_sub)
child_ids <- paste0("1973", subjects, "C")
adult_ids <- paste0("1973", subjects, "P")
all_ids   <- c(child_ids, adult_ids)

fit_vertex <- function(v_idx, all_data, covars) {
  y <- all_data[v_idx, ]; subs <- colnames(all_data)
  df <- data.frame(sub = subs, y = y) %>%
    inner_join(covars, by = "sub") %>%
    mutate(group = ifelse(grepl("C$", sub), 1, 0), sex = sex01, family = droplevels(family)) %>%
    filter(is.finite(y), is.finite(motion), !is.na(sex))
  df$y <- as.integer(df$y >= bin_thresh)
  if (nrow(df) < 5 || length(unique(df$y)) < 2)
    return(c(beta_group=NA_real_,p_group=NA_real_,beta_motion=NA_real_,p_motion=NA_real_,beta_sex=NA_real_,p_sex=NA_real_))
  if (nlevels(df$family) < 2) {
    g <- try(suppressWarnings(glm(y ~ group + sex + motion, data=df, family=binomial())), silent=TRUE)
    if (inherits(g,"try-error")) return(c(beta_group=NA_real_,p_group=NA_real_,beta_motion=NA_real_,p_motion=NA_real_,beta_sex=NA_real_,p_sex=NA_real_))
    cf <- summary(g)$coefficients; gc <- function(t,c) if (t %in% rownames(cf)) cf[t,c] else NA_real_
    return(c(beta_group=gc("group","Estimate"),p_group=gc("group","Pr(>|z|)"),
             beta_motion=gc("motion","Estimate"),p_motion=gc("motion","Pr(>|z|)"),
             beta_sex=gc("sex","Estimate"),p_sex=gc("sex","Pr(>|z|)")))
  }
  m <- try(suppressWarnings(glmer(y ~ group + sex + motion + (1|family), data=df, family=binomial(),
        control=glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=1e4)))), silent=TRUE)
  if (inherits(m,"try-error"))
    m <- try(suppressWarnings(glmer(y ~ group + sex + motion + (1|family), data=df, family=binomial(),
          control=glmerControl(optimizer="Nelder_Mead"))), silent=TRUE)
  if (!inherits(m,"try-error")) {
    beta_fe <- try(lme4::fixef(m), silent=TRUE); VC_fe <- try(lme4::vcov.merMod(m, use.hessian=FALSE), silent=TRUE)
    wald <- function(b,VC,t){ if (inherits(b,"try-error")||inherits(VC,"try-error")) return(c(NA_real_,NA_real_))
      if (!t %in% names(b)) return(c(NA_real_,NA_real_)); se<-sqrt(diag(VC))[t]; est<-b[t]
      if (!is.finite(est)||!is.finite(se)||se==0) return(c(NA_real_,NA_real_)); z<-est/se; c(est,2*pnorm(abs(z),lower.tail=FALSE)) }
    bg<-wald(beta_fe,VC_fe,"group"); bm<-wald(beta_fe,VC_fe,"motion"); bs<-wald(beta_fe,VC_fe,"sex")
    return(c(beta_group=bg[1],p_group=bg[2],beta_motion=bm[1],p_motion=bm[2],beta_sex=bs[1],p_sex=bs[2]))
  }
  g <- try(suppressWarnings(glm(y ~ group + sex + motion, data=df, family=binomial())), silent=TRUE)
  if (inherits(g,"try-error")) return(c(beta_group=NA_real_,p_group=NA_real_,beta_motion=NA_real_,p_motion=NA_real_,beta_sex=NA_real_,p_sex=NA_real_))
  cf <- summary(g)$coefficients; gc <- function(t,c) if (t %in% rownames(cf)) cf[t,c] else NA_real_
  c(beta_group=gc("group","Estimate"),p_group=gc("group","Pr(>|z|)"),
    beta_motion=gc("motion","Estimate"),p_motion=gc("motion","Pr(>|z|)"),
    beta_sex=gc("sex","Estimate"),p_sex=gc("sex","Pr(>|z|)"))
}

for (net in networks) {
  cat("\n=== Network", net, "===\n")
  all_data <- matrix(NA_real_, nrow=V, ncol=length(all_ids)); colnames(all_data) <- all_ids
  for (i in seq_along(all_ids)) {
    f <- file.path(input_dir, sprintf("Network%d_Assignment_sub%s.dscalar.nii", net, all_ids[i]))
    if (file.exists(f)) all_data[,i] <- as.numeric(as.vector(as.matrix(read_cifti(f))))
    else cat("Warning: missing", f, "\n")
  }
  idxs <- which(labels == net); cat("Vertices in mask:", length(idxs), "\n")
  out_mat <- vapply(idxs, function(ii) fit_vertex(ii, all_data, covars),
    FUN.VALUE=c(beta_group=0,p_group=0,beta_motion=0,p_motion=0,beta_sex=0,p_sex=0))
  results_df <- data.frame(vertex=idxs, beta_group=out_mat["beta_group",], p_group=out_mat["p_group",],
    beta_motion=out_mat["beta_motion",], p_motion=out_mat["p_motion",],
    beta_sex=out_mat["beta_sex",], p_sex=out_mat["p_sex",])
  cat("UNCORRECTED p<0.05 — group:", sum(results_df$p_group<0.05,na.rm=TRUE),
      "motion:", sum(results_df$p_motion<0.05,na.rm=TRUE), "sex:", sum(results_df$p_sex<0.05,na.rm=TRUE), "\n")
  OUTDIR <- file.path(OUTPUT_DIR_BASE, sprintf("Network_%02d", net)); dir.create(OUTDIR, showWarnings=FALSE, recursive=TRUE)
  write.csv(results_df, file.path(OUTDIR, sprintf("N%02d_Vertexwise_LogReg_results_uncorrected.csv", net)), row.names=FALSE)
  write.csv(dplyr::filter(results_df, p_group<0.05), file.path(OUTDIR, sprintf("N%02d_Significant_vertices_group_p_lt_0p05.csv", net)), row.names=FALSE)

  beta_full <- rep(NA_real_, V); pval_full <- rep(NA_real_, V)
  beta_full[idxs] <- out_mat["beta_group",]; pval_full[idxs] <- out_mat["p_group",]
  beta_full[!is.finite(beta_full)] <- 0; pval_full[!is.finite(pval_full)] <- 1
  bp <- rep(0, N_grayordinates); pp <- rep(1, N_grayordinates)
  bp[seq_along(beta_full)] <- beta_full; pp[seq_along(pval_full)] <- pval_full
  bt <- file.path(OUTDIR, sprintf("N%02d_tmp_beta_group_91282.txt", net))
  pt <- file.path(OUTDIR, sprintf("N%02d_tmp_pvals_uncorrected_91282.txt", net))
  write.table(bp, bt, row.names=FALSE, col.names=FALSE, quote=FALSE)
  write.table(pp, pt, row.names=FALSE, col.names=FALSE, quote=FALSE)
  system2(wb_cmd, args=c("-cifti-convert","-from-text", bt, template_path,
    file.path(OUTDIR, sprintf("N%02d_ChildVsAdult_GroupBeta_LMMorFE_9min.dscalar.nii", net))))
  system2(wb_cmd, args=c("-cifti-convert","-from-text", pt, template_path,
    file.path(OUTDIR, sprintf("N%02d_ChildVsAdult_Pvals_uncorrected_LMMorFE_9min.dscalar.nii", net))))
}
cat("\nDone. 9-min vertex-wise results in", OUTPUT_DIR_BASE, "\n")
