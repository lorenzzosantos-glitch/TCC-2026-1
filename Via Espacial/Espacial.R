# =========================================================================
# MODELO HEDÔNICO VIA ECONOMETRIA ESPACIAL — SAR e SEM
# Referências: Anselin (1988), LeSage & Pace (2009)
# Dependências: rodar Carregar base.R antes deste script
# =========================================================================
# SAR (Spatial Lag):   log(P) = ρ·W·log(P) + X·β + ε
#   ρ: influência do preço médio dos vizinhos sobre o imóvel
# SEM (Spatial Error): log(P) = X·β + u,  u = λ·W·u + ε
#   λ: autocorrelação nos erros (variáveis omitidas espacialmente estruturadas)
# =========================================================================

# -------------------------------------------------------------------------
# PACOTES
# -------------------------------------------------------------------------
if (!require("spdep"))      install.packages("spdep")
if (!require("spatialreg")) install.packages("spatialreg")
if (!require("writexl"))    install.packages("writexl")
if (!require("ggplot2"))    install.packages("ggplot2")

library(spdep)
library(spatialreg)
library(writexl)
library(ggplot2)

# =========================================================================
# SE 1: PREPARAÇÃO DOS DADOS ESPACIAIS — VENDAS
# =========================================================================
cat("\n=== SE 1: Preparação Espacial — Vendas ===\n")

vars_v <- c("preco_venda", "area", "quartos", "vagas", "suites",
            "tem_piscina", "tem_churrasqueira", "tem_elevador",
            "tipologia", "name", "latitude", "longitude")

dados_v_sp <- dados_v[complete.cases(dados_v[, vars_v]), ]

# Filtrar coordenadas dentro do município de Porto Alegre
dados_v_sp <- dados_v_sp[
  dados_v_sp$longitude > -51.35 & dados_v_sp$longitude < -51.00 &
    dados_v_sp$latitude  > -30.30 & dados_v_sp$latitude  < -29.90, ]

dados_v_sp$log_preco_venda <- log(dados_v_sp$preco_venda)
dados_v_sp$log_area        <- log(dados_v_sp$area)
dados_v_sp$tipologia       <- as.factor(dados_v_sp$tipologia)
dados_v_sp$name            <- as.factor(dados_v_sp$name)

cat("Observações com coordenadas válidas (vendas):", nrow(dados_v_sp), "\n")

# =========================================================================
# SE 2: MATRIZ DE PESOS ESPACIAIS — k vizinhos mais próximos (k = 10)
# =========================================================================
# knn é o padrão para dados de ponto (imóveis individuais)
# k = 10 é amplamente usado na literatura hedônica urbana
# longlat = TRUE: distâncias em km usando a fórmula de Haversine
# style = "W": padronização por linha (row-standardized) — convenção padrão
# =========================================================================
cat("\n=== SE 2: Matriz de Pesos Espaciais (knn, k=10) ===\n")

coords_v <- cbind(dados_v_sp$longitude, dados_v_sp$latitude)

set.seed(42)
knn_v   <- knearneigh(coords_v, k = 10, longlat = TRUE)
nb_v    <- knn2nb(knn_v)
listw_v <- nb2listw(nb_v, style = "W")

cat("Matriz construída: n =", length(nb_v), "| média de vizinhos = 10\n")

# Estatísticas da matriz de pesos
cat("Resumo da conectividade:\n")
print(summary(nb_v))

# =========================================================================
# SE 3: RE-ESTIMAR MQO NO CONJUNTO ESPACIAL
# (necessário para alinhar índices com a matriz W)
# =========================================================================
cat("\n=== SE 3: MQO Base (conjunto espacial) — Vendas ===\n")

formula_v <- log_preco_venda ~ log_area + quartos + vagas + suites +
  tem_piscina + tem_churrasqueira + tem_elevador + tipologia + name

mqo_v_sp <- lm(formula_v, data = dados_v_sp)
cat("R² ajustado (MQO espacial):", round(summary(mqo_v_sp)$adj.r.squared, 4), "\n")
cat("AIC (MQO):", round(AIC(mqo_v_sp), 2), "\n")

# =========================================================================
# SE 4: TESTE DE MORAN NOS RESÍDUOS DO MQO
# =========================================================================
cat("\n=== SE 4: Teste I de Moran nos Resíduos do MQO (Vendas) ===\n")

moran_mqo_v <- lm.morantest(mqo_v_sp, listw = listw_v)
cat("I de Moran:", round(moran_mqo_v$estimate[1], 4), "\n")
cat("p-valor:   ", round(moran_mqo_v$p.value, 6), "\n")

if (moran_mqo_v$p.value < 0.05) {
  cat(">> Autocorrelação espacial detectada (p < 0.05) — modelos espaciais indicados.\n")
} else {
  cat(">> Autocorrelação espacial NÃO detectada — MQO pode ser suficiente.\n")
}

# =========================================================================
# SE 5: TESTES DE MULTIPLICADORES DE LAGRANGE (Anselin 1988)
# Guiam a escolha entre SAR e SEM:
#   LMlag  → testa se ρ ≠ 0 (SAR)
#   LMerr  → testa se λ ≠ 0 (SEM)
#   RLMlag → versão robusta (condicional a LMerr)
#   RLMerr → versão robusta (condicional a LMlag)
# Regra:
#   RLMlag sig, RLMerr não → SAR
#   RLMerr sig, RLMlag não → SEM
#   Ambos sig              → comparar via AIC
#   Nenhum sig             → MQO suficiente
# =========================================================================
cat("\n=== SE 5: Testes LM — Vendas ===\n")

lm_tests_v <- lm.LMtests(mqo_v_sp, listw = listw_v,
                          test = c("LMlag", "LMerr", "RLMlag", "RLMerr", "SARMA"))
print(summary(lm_tests_v))

p_rlag_v <- lm_tests_v$RLMlag$p.value
p_rerr_v <- lm_tests_v$RLMerr$p.value

cat("\n--- Decisão de Anselin (1988) ---\n")
if (lm_tests_v$LMlag$p.value > 0.05 & lm_tests_v$LMerr$p.value > 0.05) {
  cat("Nenhum LM significativo → MQO é adequado.\n")
} else if (p_rlag_v < 0.05 & p_rerr_v >= 0.05) {
  cat("RLM-lag sig, RLM-err não → INDICADO: SAR (Spatial Lag).\n")
} else if (p_rerr_v < 0.05 & p_rlag_v >= 0.05) {
  cat("RLM-err sig, RLM-lag não → INDICADO: SEM (Spatial Error).\n")
} else {
  cat("Ambos RLM significativos → estimar SAR e SEM; escolher pelo menor AIC.\n")
}

# =========================================================================
# SE 6: MODELO SAR (Spatial Lag) — VENDAS
# =========================================================================
cat("\n=== SE 6: SAR (Spatial Lag) — Vendas ===\n")
# method = "LU": decomposição LU esparsa — recomendado para n > 2000
# quiet  = TRUE: suprime progresso da iteração
cat("Estimando SAR — pode levar alguns minutos para amostras grandes...\n")

sar_venda <- lagsarlm(
  formula_v,
  data   = dados_v_sp,
  listw  = listw_v,
  method = "LU",
  quiet  = TRUE
)

cat("\n--- SAR Vendas: Resumo ---\n")
print(summary(sar_venda))

rho_v   <- sar_venda$rho
rho_p_v <- 1 - pchisq(sar_venda$LR1$statistic, df = 1)
cat("\nρ (rho)    =", round(rho_v, 4), "| p-valor (LR):", formatC(rho_p_v, format = "e", digits = 3), "\n")

sse_sar_v       <- sum(residuals(sar_venda)^2)
sst_v           <- sum((dados_v_sp$log_preco_venda - mean(dados_v_sp$log_preco_venda))^2)
pseudo_r2_sar_v <- 1 - sse_sar_v / sst_v
aic_sar_v       <- AIC(sar_venda)
loglik_sar_v    <- as.numeric(logLik(sar_venda))

cat("Pseudo-R²  :", round(pseudo_r2_sar_v, 4), "\n")
cat("AIC        :", round(aic_sar_v, 2), "\n")
cat("Log-lik    :", round(loglik_sar_v, 2), "\n")

# -------------------------------------------------------------------------
# SE 6b: EFEITOS DIRETOS, INDIRETOS E TOTAIS (SAR)
# No SAR, β não é o efeito marginal direto:
#   Efeito total  = (I - ρW)^{-1} β  (inclui feedback espacial)
#   Direto        ≈ β / (1 - ρ)     (efeito no próprio imóvel)
#   Indireto      = total - direto   (spillover para vizinhos)
# -------------------------------------------------------------------------
cat("\n--- SE 6b: Efeitos Diretos, Indiretos e Totais (SAR Vendas) ---\n")
cat("Calculando impactos (R = 500 simulações)...\n")

set.seed(42)
impactos_sar_v <- impacts(sar_venda, listw = listw_v, R = 500)
print(summary(impactos_sar_v, zstats = TRUE, short = TRUE))

# =========================================================================
# SE 7: MODELO SEM (Spatial Error) — VENDAS
# =========================================================================
cat("\n=== SE 7: SEM (Spatial Error) — Vendas ===\n")
cat("Estimando SEM — pode levar alguns minutos...\n")

sem_venda <- errorsarlm(
  formula_v,
  data  = dados_v_sp,
  listw = listw_v,
  quiet = TRUE
)

cat("\n--- SEM Vendas: Resumo ---\n")
print(summary(sem_venda))

lambda_v   <- sem_venda$lambda
lambda_p_v <- 1 - pchisq(sem_venda$LR1$statistic, df = 1)
cat("\nλ (lambda) =", round(lambda_v, 4), "| p-valor (LR):", formatC(lambda_p_v, format = "e", digits = 3), "\n")

sse_sem_v       <- sum(residuals(sem_venda)^2)
pseudo_r2_sem_v <- 1 - sse_sem_v / sst_v
aic_sem_v       <- AIC(sem_venda)
loglik_sem_v    <- as.numeric(logLik(sem_venda))

cat("Pseudo-R²  :", round(pseudo_r2_sem_v, 4), "\n")
cat("AIC        :", round(aic_sem_v, 2), "\n")
cat("Log-lik    :", round(loglik_sem_v, 2), "\n")

# =========================================================================
# SE 8: MORAN PÓS-ESTIMAÇÃO (verificar correção da autocorrelação)
# =========================================================================
cat("\n=== SE 8: Moran nos Resíduos Pós-Estimação (Vendas) ===\n")

moran_sar_v <- moran.test(residuals(sar_venda), listw_v)
moran_sem_v <- moran.test(residuals(sem_venda), listw_v)

cat("I de Moran — MQO : I =", round(moran_mqo_v$estimate[1], 4),
    "| p =", formatC(moran_mqo_v$p.value, format = "e", digits = 2), "\n")
cat("I de Moran — SAR : I =", round(moran_sar_v$estimate[1], 4),
    "| p =", formatC(moran_sar_v$p.value, format = "e", digits = 2), "\n")
cat("I de Moran — SEM : I =", round(moran_sem_v$estimate[1], 4),
    "| p =", formatC(moran_sem_v$p.value, format = "e", digits = 2), "\n")

if (moran_sar_v$p.value > 0.05)
  cat(">> SAR: autocorrelação corrigida (Moran não sig.).\n") else
  cat(">> SAR: ainda há autocorrelação residual.\n")
if (moran_sem_v$p.value > 0.05)
  cat(">> SEM: autocorrelação corrigida (Moran não sig.).\n") else
  cat(">> SEM: ainda há autocorrelação residual.\n")

# Gráfico I de Moran nos resíduos do MQO
png("moran_residuos_vendas.png", width = 700, height = 700)
moran.plot(residuals(mqo_v_sp), listw_v,
           xlab = "Resíduos MQO (Vendas)",
           ylab = "Lag Espacial dos Resíduos",
           main = "Gráfico de Moran — Resíduos MQO (Vendas)",
           pch = 20, col = adjustcolor("steelblue", alpha.f = 0.3))
dev.off()
cat("Gráfico salvo: moran_residuos_vendas.png\n")


# =========================================================================
# =========================================================================
# ALUGUEL — mesma sequência (SE 9 a SE 16)
# =========================================================================
# =========================================================================

cat("\n\n========================================================\n")
cat("=== SE 9 a 16: ALUGUEL ===\n")
cat("========================================================\n")

# =========================================================================
# SE 9: PREPARAÇÃO ESPACIAL — ALUGUEL
# =========================================================================
cat("\n=== SE 9: Preparação Espacial — Aluguel ===\n")

vars_a <- c("preco_aluguel", "area", "quartos", "suites",
            "tem_piscina", "tem_churrasqueira", "tem_elevador",
            "tipologia", "name", "latitude", "longitude")

dados_a_sp <- dados_a[complete.cases(dados_a[, vars_a]), ]
dados_a_sp <- dados_a_sp[
  dados_a_sp$longitude > -51.35 & dados_a_sp$longitude < -51.00 &
    dados_a_sp$latitude  > -30.30 & dados_a_sp$latitude  < -29.90, ]

dados_a_sp$log_preco_aluguel <- log(dados_a_sp$preco_aluguel)
dados_a_sp$log_area          <- log(dados_a_sp$area)
dados_a_sp$tipologia         <- as.factor(dados_a_sp$tipologia)
dados_a_sp$name              <- as.factor(dados_a_sp$name)

cat("Observações com coordenadas válidas (aluguel):", nrow(dados_a_sp), "\n")

coords_a <- cbind(dados_a_sp$longitude, dados_a_sp$latitude)

set.seed(42)
knn_a   <- knearneigh(coords_a, k = 10, longlat = TRUE)
nb_a    <- knn2nb(knn_a)
listw_a <- nb2listw(nb_a, style = "W")

# =========================================================================
# SE 10: MQO BASE — ALUGUEL
# =========================================================================
formula_a <- log_preco_aluguel ~ log_area + quartos + suites +
  tem_piscina + tem_churrasqueira + tem_elevador + tipologia + name

mqo_a_sp <- lm(formula_a, data = dados_a_sp)
cat("R² ajustado (MQO espacial):", round(summary(mqo_a_sp)$adj.r.squared, 4), "\n")
cat("AIC (MQO):", round(AIC(mqo_a_sp), 2), "\n")

# =========================================================================
# SE 11: MORAN + LM TESTS — ALUGUEL
# =========================================================================
cat("\n=== SE 11: Moran + LM — Aluguel ===\n")

moran_mqo_a <- lm.morantest(mqo_a_sp, listw = listw_a)
cat("I de Moran (MQO aluguel):", round(moran_mqo_a$estimate[1], 4),
    "| p =", formatC(moran_mqo_a$p.value, format = "e", digits = 3), "\n")

lm_tests_a <- lm.LMtests(mqo_a_sp, listw = listw_a,
                          test = c("LMlag", "LMerr", "RLMlag", "RLMerr", "SARMA"))
print(summary(lm_tests_a))

p_rlag_a <- lm_tests_a$RLMlag$p.value
p_rerr_a <- lm_tests_a$RLMerr$p.value

cat("\n--- Decisão de Anselin (1988) — Aluguel ---\n")
if (lm_tests_a$LMlag$p.value > 0.05 & lm_tests_a$LMerr$p.value > 0.05) {
  cat("Nenhum LM significativo → MQO é adequado.\n")
} else if (p_rlag_a < 0.05 & p_rerr_a >= 0.05) {
  cat("RLM-lag sig → INDICADO: SAR.\n")
} else if (p_rerr_a < 0.05 & p_rlag_a >= 0.05) {
  cat("RLM-err sig → INDICADO: SEM.\n")
} else {
  cat("Ambos RLM sig → comparar SAR e SEM via AIC.\n")
}

# =========================================================================
# SE 12: SAR — ALUGUEL
# =========================================================================
cat("\n=== SE 12: SAR (Spatial Lag) — Aluguel ===\n")
cat("Estimando SAR (aluguel)...\n")

sar_aluguel <- lagsarlm(
  formula_a,
  data   = dados_a_sp,
  listw  = listw_a,
  method = "LU",
  quiet  = TRUE
)

print(summary(sar_aluguel))

rho_a   <- sar_aluguel$rho
rho_p_a <- 1 - pchisq(sar_aluguel$LR1$statistic, df = 1)
cat("\nρ (rho)    =", round(rho_a, 4), "| p-valor (LR):", formatC(rho_p_a, format = "e", digits = 3), "\n")

sst_a           <- sum((dados_a_sp$log_preco_aluguel - mean(dados_a_sp$log_preco_aluguel))^2)
sse_sar_a       <- sum(residuals(sar_aluguel)^2)
pseudo_r2_sar_a <- 1 - sse_sar_a / sst_a
aic_sar_a       <- AIC(sar_aluguel)
loglik_sar_a    <- as.numeric(logLik(sar_aluguel))

cat("Pseudo-R²  :", round(pseudo_r2_sar_a, 4), "\n")
cat("AIC        :", round(aic_sar_a, 2), "\n")

cat("\n--- Efeitos Diretos, Indiretos e Totais (SAR Aluguel) ---\n")
set.seed(42)
impactos_sar_a <- impacts(sar_aluguel, listw = listw_a, R = 500)
print(summary(impactos_sar_a, zstats = TRUE, short = TRUE))

# =========================================================================
# SE 13: SEM — ALUGUEL
# =========================================================================
cat("\n=== SE 13: SEM (Spatial Error) — Aluguel ===\n")
cat("Estimando SEM (aluguel)...\n")

sem_aluguel <- errorsarlm(
  formula_a,
  data  = dados_a_sp,
  listw = listw_a,
  quiet = TRUE
)

print(summary(sem_aluguel))

lambda_a   <- sem_aluguel$lambda
lambda_p_a <- 1 - pchisq(sem_aluguel$LR1$statistic, df = 1)
cat("\nλ (lambda) =", round(lambda_a, 4), "| p-valor (LR):", formatC(lambda_p_a, format = "e", digits = 3), "\n")

sse_sem_a       <- sum(residuals(sem_aluguel)^2)
pseudo_r2_sem_a <- 1 - sse_sem_a / sst_a
aic_sem_a       <- AIC(sem_aluguel)
loglik_sem_a    <- as.numeric(logLik(sem_aluguel))

cat("Pseudo-R²  :", round(pseudo_r2_sem_a, 4), "\n")
cat("AIC        :", round(aic_sem_a, 2), "\n")

# =========================================================================
# SE 14: MORAN PÓS-ESTIMAÇÃO — ALUGUEL
# =========================================================================
cat("\n=== SE 14: Moran Pós-Estimação (Aluguel) ===\n")

moran_sar_a <- moran.test(residuals(sar_aluguel), listw_a)
moran_sem_a <- moran.test(residuals(sem_aluguel), listw_a)

cat("I de Moran — MQO : I =", round(moran_mqo_a$estimate[1], 4),
    "| p =", formatC(moran_mqo_a$p.value, format = "e", digits = 2), "\n")
cat("I de Moran — SAR : I =", round(moran_sar_a$estimate[1], 4),
    "| p =", formatC(moran_sar_a$p.value, format = "e", digits = 2), "\n")
cat("I de Moran — SEM : I =", round(moran_sem_a$estimate[1], 4),
    "| p =", formatC(moran_sem_a$p.value, format = "e", digits = 2), "\n")

png("moran_residuos_aluguel.png", width = 700, height = 700)
moran.plot(residuals(mqo_a_sp), listw_a,
           xlab = "Resíduos MQO (Aluguel)",
           ylab = "Lag Espacial dos Resíduos",
           main = "Gráfico de Moran — Resíduos MQO (Aluguel)",
           pch = 20, col = adjustcolor("coral3", alpha.f = 0.3))
dev.off()
cat("Gráfico salvo: moran_residuos_aluguel.png\n")

# =========================================================================
# SE 15: TABELA COMPARATIVA — MQO vs SAR vs SEM
# =========================================================================
cat("\n=== SE 15: Comparativo MQO vs SAR vs SEM ===\n")

tabela_comp_esp <- data.frame(
  Modelo         = c("MQO (Vendas)", "SAR (Vendas)", "SEM (Vendas)",
                     "MQO (Aluguel)", "SAR (Aluguel)", "SEM (Aluguel)"),
  N              = c(nrow(dados_v_sp), nrow(dados_v_sp), nrow(dados_v_sp),
                     nrow(dados_a_sp), nrow(dados_a_sp), nrow(dados_a_sp)),
  Log_Lik        = round(c(as.numeric(logLik(mqo_v_sp)), loglik_sar_v, loglik_sem_v,
                           as.numeric(logLik(mqo_a_sp)), loglik_sar_a, loglik_sem_a), 2),
  AIC            = round(c(AIC(mqo_v_sp), aic_sar_v, aic_sem_v,
                           AIC(mqo_a_sp), aic_sar_a, aic_sem_a), 2),
  Pseudo_R2      = round(c(
    summary(mqo_v_sp)$adj.r.squared,
    pseudo_r2_sar_v, pseudo_r2_sem_v,
    summary(mqo_a_sp)$adj.r.squared,
    pseudo_r2_sar_a, pseudo_r2_sem_a
  ), 4),
  Param_Espacial = c(NA, round(rho_v, 4), round(lambda_v, 4),
                     NA, round(rho_a, 4), round(lambda_a, 4)),
  Tipo           = c("—", "ρ (rho)", "λ (lambda)",
                     "—", "ρ (rho)", "λ (lambda)"),
  Moran_Residuos = round(c(
    moran_mqo_v$estimate[1], moran_sar_v$estimate[1], moran_sem_v$estimate[1],
    moran_mqo_a$estimate[1], moran_sar_a$estimate[1], moran_sem_a$estimate[1]
  ), 4),
  Moran_p        = formatC(c(
    moran_mqo_v$p.value, moran_sar_v$p.value, moran_sem_v$p.value,
    moran_mqo_a$p.value, moran_sar_a$p.value, moran_sem_a$p.value
  ), format = "e", digits = 2)
)

print(tabela_comp_esp)

# =========================================================================
# SE 16: EXPORTAÇÃO DOS RESULTADOS
# =========================================================================
cat("\n=== SE 16: Exportando Resultados ===\n")

extrair_coef_sp <- function(modelo, nome) {
  cf <- coef(summary(modelo))
  df <- as.data.frame(cf)
  colnames(df) <- c("Coeficiente", "Erro_Padrao", "z_valor", "p_valor")
  df$Sig <- ifelse(df$p_valor < 0.001, "***",
            ifelse(df$p_valor < 0.01,  "**",
            ifelse(df$p_valor < 0.05,  "*",
            ifelse(df$p_valor < 0.1,   ".", "NS"))))
  df$Variavel <- rownames(df)
  df$Modelo   <- nome
  rownames(df) <- NULL
  df[, c("Modelo", "Variavel", "Coeficiente", "Erro_Padrao", "z_valor", "p_valor", "Sig")]
}

so_estruturais <- function(df) {
  df[!grepl("name|tipologia", df$Variavel), ]
}

# Tabela de testes LM
lm_resumo_v <- data.frame(
  Teste     = c("LMlag", "LMerr", "RLMlag", "RLMerr", "SARMA"),
  Statistic = round(c(lm_tests_v$LMlag$statistic, lm_tests_v$LMerr$statistic,
                      lm_tests_v$RLMlag$statistic, lm_tests_v$RLMerr$statistic,
                      lm_tests_v$SARMA$statistic), 4),
  p_valor   = formatC(c(lm_tests_v$LMlag$p.value, lm_tests_v$LMerr$p.value,
                        lm_tests_v$RLMlag$p.value, lm_tests_v$RLMerr$p.value,
                        lm_tests_v$SARMA$p.value), format = "e", digits = 3),
  Mercado   = "Vendas"
)

lm_resumo_a <- data.frame(
  Teste     = c("LMlag", "LMerr", "RLMlag", "RLMerr", "SARMA"),
  Statistic = round(c(lm_tests_a$LMlag$statistic, lm_tests_a$LMerr$statistic,
                      lm_tests_a$RLMlag$statistic, lm_tests_a$RLMerr$statistic,
                      lm_tests_a$SARMA$statistic), 4),
  p_valor   = formatC(c(lm_tests_a$LMlag$p.value, lm_tests_a$LMerr$p.value,
                        lm_tests_a$RLMlag$p.value, lm_tests_a$RLMerr$p.value,
                        lm_tests_a$SARMA$p.value), format = "e", digits = 3),
  Mercado   = "Aluguel"
)

write_xlsx(list(
  "Comparativo_Modelos"  = tabela_comp_esp,
  "Testes_LM"            = rbind(lm_resumo_v, lm_resumo_a),
  "SAR_Vendas_Estruct"   = so_estruturais(extrair_coef_sp(sar_venda,   "SAR Vendas")),
  "SEM_Vendas_Estruct"   = so_estruturais(extrair_coef_sp(sem_venda,   "SEM Vendas")),
  "SAR_Aluguel_Estruct"  = so_estruturais(extrair_coef_sp(sar_aluguel, "SAR Aluguel")),
  "SEM_Aluguel_Estruct"  = so_estruturais(extrair_coef_sp(sem_aluguel, "SEM Aluguel")),
  "SAR_Vendas_Completo"  = extrair_coef_sp(sar_venda,   "SAR Vendas"),
  "SEM_Vendas_Completo"  = extrair_coef_sp(sem_venda,   "SEM Vendas"),
  "SAR_Aluguel_Completo" = extrair_coef_sp(sar_aluguel, "SAR Aluguel"),
  "SEM_Aluguel_Completo" = extrair_coef_sp(sem_aluguel, "SEM Aluguel")
), path = "resultados_espacial.xlsx")

cat("Arquivo salvo: resultados_espacial.xlsx\n")

cat("\n========================================================\n")
cat("RESUMO FINAL — ECONOMETRIA ESPACIAL\n")
cat("========================================================\n")
print(tabela_comp_esp[, c("Modelo", "AIC", "Pseudo_R2", "Param_Espacial", "Tipo", "Moran_p")])
