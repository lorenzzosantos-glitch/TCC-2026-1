# =========================================================================
# MODELO HEDÔNICO VIA RANDOM FOREST (ranger)
# Variáveis idênticas ao MQO — permite comparação direta de desempenho
# =========================================================================

# -------------------------------------------------------------------------
# PACOTES
# -------------------------------------------------------------------------
if (!require("ranger"))  install.packages("ranger")
if (!require("caret"))   install.packages("caret")
if (!require("writexl")) install.packages("writexl")
if (!require("ggplot2")) install.packages("ggplot2")

library(ranger)
library(caret)
library(writexl)
library(ggplot2)

# =========================================================================
# RF 1: VENDAS
# =========================================================================
cat("\n=== RF: Modelo de Vendas ===\n")

# Preparar dados: log-transformações e conversão de fatores
vars_v <- c("preco_venda", "area", "quartos", "vagas", "suites",
            "tem_piscina", "tem_churrasqueira", "tem_elevador",
            "tipologia", "name")

dados_v_rf <- dados_v[complete.cases(dados_v[, vars_v]), ]
dados_v_rf$log_preco_venda <- log(dados_v_rf$preco_venda)
dados_v_rf$log_area        <- log(dados_v_rf$area)
dados_v_rf$tipologia       <- as.factor(dados_v_rf$tipologia)
dados_v_rf$name            <- as.factor(dados_v_rf$name)

# -------------------------------------------------------------------------
# RF 1a: Divisão treino/teste (80/20)
# -------------------------------------------------------------------------
set.seed(42)
idx_v    <- createDataPartition(dados_v_rf$log_preco_venda, p = 0.8, list = FALSE)
treino_v <- dados_v_rf[ idx_v, ]
teste_v  <- dados_v_rf[-idx_v, ]
cat("Treino:", nrow(treino_v), "| Teste:", nrow(teste_v), "\n")

# -------------------------------------------------------------------------
# RF 1b: Tuning de mtry via OOB error
# Preditores: log_area, quartos, vagas, suites,
#             tem_piscina, tem_churrasqueira, tem_elevador, tipologia, name (= 9)
# Regra de bolso: sqrt(9) ≈ 3; testamos 2 a 7
# -------------------------------------------------------------------------
cat("\n--- Tuning de mtry (Vendas) ---\n")

formula_v <- log_preco_venda ~ log_area + quartos + vagas + suites +
  tem_piscina + tem_churrasqueira + tem_elevador + tipologia + name

resultados_tuning_v <- data.frame(mtry = integer(), OOB_RMSE = numeric())

for (m in 2:7) {
  set.seed(42)
  rf_tmp <- ranger(formula_v, data = treino_v,
                   num.trees = 500, mtry = m, seed = 42)
  # OOB error já está na escala quadrática — converter para RMSE
  oob_rmse <- sqrt(rf_tmp$prediction.error)
  resultados_tuning_v <- rbind(resultados_tuning_v,
                                data.frame(mtry = m, OOB_RMSE = oob_rmse))
  cat("  mtry =", m, "| OOB RMSE =", round(oob_rmse, 5), "\n")
}

melhor_mtry_v <- resultados_tuning_v$mtry[which.min(resultados_tuning_v$OOB_RMSE)]
cat("Melhor mtry:", melhor_mtry_v, "\n")

# -------------------------------------------------------------------------
# RF 1c: Modelo final com melhor mtry (1000 árvores)
# -------------------------------------------------------------------------
set.seed(42)
rf_venda_final <- ranger(
  formula_v,
  data          = treino_v,
  num.trees     = 1000,
  mtry          = melhor_mtry_v,
  min.node.size = 5,
  importance    = "permutation",
  seed          = 42
)

pred_v    <- predict(rf_venda_final, data = teste_v)$predictions
rmse_rf_v <- sqrt(mean((pred_v - teste_v$log_preco_venda)^2))
r2_rf_v   <- cor(pred_v, teste_v$log_preco_venda)^2
mae_rf_v  <- mean(abs(pred_v - teste_v$log_preco_venda))
oob_r2_v  <- 1 - rf_venda_final$prediction.error / var(treino_v$log_preco_venda)

cat("\n--- RF Vendas (final, 1000 árvores) ---\n")
cat("R²  (teste) :", round(r2_rf_v,   4), "\n")
cat("RMSE (teste):", round(rmse_rf_v, 4), "\n")
cat("MAE  (teste):", round(mae_rf_v,  4), "\n")
cat("R²  (OOB)   :", round(oob_r2_v,  4), "\n")

# -------------------------------------------------------------------------
# RF 1d: Importância das variáveis — top 20 (evita poluição com N bairros)
# -------------------------------------------------------------------------
imp_v     <- sort(importance(rf_venda_final), decreasing = TRUE)
imp_v_df  <- data.frame(Variavel = names(imp_v), Importancia = as.numeric(imp_v))
imp_v_top <- head(imp_v_df, 20)

cat("\n--- Top 20 variáveis mais importantes (Vendas) ---\n")
print(imp_v_top)

png("rf_importancia_vendas.png", width = 900, height = 650)
print(
  ggplot(imp_v_top, aes(x = reorder(Variavel, Importancia), y = Importancia)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = "Importância das Variáveis — RF Vendas (top 20)",
         x = NULL, y = "Importância (permutação)") +
    theme_minimal(base_size = 13)
)
dev.off()
cat("Gráfico salvo: rf_importancia_vendas.png\n")

# Predito vs Observado
png("rf_predito_obs_vendas.png", width = 700, height = 700)
plot(teste_v$log_preco_venda, pred_v,
     xlab = "log(Preço Venda) Observado",
     ylab = "log(Preço Venda) Predito",
     main = "RF Vendas: Predito vs Observado",
     pch  = 20, col = adjustcolor("steelblue", alpha.f = 0.4))
abline(0, 1, col = "red", lwd = 2)
legend("topleft", bty = "n",
       legend = paste0("R² = ", round(r2_rf_v, 3),
                       "  |  RMSE = ", round(rmse_rf_v, 3)))
dev.off()
cat("Gráfico salvo: rf_predito_obs_vendas.png\n")

# =========================================================================
# RF 2: ALUGUEL
# =========================================================================
cat("\n=== RF: Modelo de Aluguel ===\n")

vars_a <- c("preco_aluguel", "area", "quartos", "suites",
            "tem_piscina", "tem_churrasqueira", "tem_elevador",
            "tipologia", "name")

dados_a_rf <- dados_a[complete.cases(dados_a[, vars_a]), ]
dados_a_rf$log_preco_aluguel <- log(dados_a_rf$preco_aluguel)
dados_a_rf$log_area          <- log(dados_a_rf$area)
dados_a_rf$tipologia         <- as.factor(dados_a_rf$tipologia)
dados_a_rf$name              <- as.factor(dados_a_rf$name)

set.seed(42)
idx_a    <- createDataPartition(dados_a_rf$log_preco_aluguel, p = 0.8, list = FALSE)
treino_a <- dados_a_rf[ idx_a, ]
teste_a  <- dados_a_rf[-idx_a, ]
cat("Treino:", nrow(treino_a), "| Teste:", nrow(teste_a), "\n")

# -------------------------------------------------------------------------
# Preditores: log_area, quartos, suites,
#             tem_piscina, tem_churrasqueira, tem_elevador, tipologia, name (= 8)
# -------------------------------------------------------------------------
cat("\n--- Tuning de mtry (Aluguel) ---\n")

formula_a <- log_preco_aluguel ~ log_area + quartos + suites +
  tem_piscina + tem_churrasqueira + tem_elevador + tipologia + name

resultados_tuning_a <- data.frame(mtry = integer(), OOB_RMSE = numeric())

for (m in 2:7) {
  set.seed(42)
  rf_tmp <- ranger(formula_a, data = treino_a,
                   num.trees = 500, mtry = m, seed = 42)
  oob_rmse <- sqrt(rf_tmp$prediction.error)
  resultados_tuning_a <- rbind(resultados_tuning_a,
                                data.frame(mtry = m, OOB_RMSE = oob_rmse))
  cat("  mtry =", m, "| OOB RMSE =", round(oob_rmse, 5), "\n")
}

melhor_mtry_a <- resultados_tuning_a$mtry[which.min(resultados_tuning_a$OOB_RMSE)]
cat("Melhor mtry:", melhor_mtry_a, "\n")

set.seed(42)
rf_aluguel_final <- ranger(
  formula_a,
  data          = treino_a,
  num.trees     = 1000,
  mtry          = melhor_mtry_a,
  min.node.size = 5,
  importance    = "permutation",
  seed          = 42
)

pred_a    <- predict(rf_aluguel_final, data = teste_a)$predictions
rmse_rf_a <- sqrt(mean((pred_a - teste_a$log_preco_aluguel)^2))
r2_rf_a   <- cor(pred_a, teste_a$log_preco_aluguel)^2
mae_rf_a  <- mean(abs(pred_a - teste_a$log_preco_aluguel))
oob_r2_a  <- 1 - rf_aluguel_final$prediction.error / var(treino_a$log_preco_aluguel)

cat("\n--- RF Aluguel (final, 1000 árvores) ---\n")
cat("R²  (teste) :", round(r2_rf_a,   4), "\n")
cat("RMSE (teste):", round(rmse_rf_a, 4), "\n")
cat("MAE  (teste):", round(mae_rf_a,  4), "\n")
cat("R²  (OOB)   :", round(oob_r2_a,  4), "\n")

imp_a     <- sort(importance(rf_aluguel_final), decreasing = TRUE)
imp_a_df  <- data.frame(Variavel = names(imp_a), Importancia = as.numeric(imp_a))
imp_a_top <- head(imp_a_df, 20)

cat("\n--- Top 20 variáveis mais importantes (Aluguel) ---\n")
print(imp_a_top)

png("rf_importancia_aluguel.png", width = 900, height = 650)
print(
  ggplot(imp_a_top, aes(x = reorder(Variavel, Importancia), y = Importancia)) +
    geom_col(fill = "coral3") +
    coord_flip() +
    labs(title = "Importância das Variáveis — RF Aluguel (top 20)",
         x = NULL, y = "Importância (permutação)") +
    theme_minimal(base_size = 13)
)
dev.off()
cat("Gráfico salvo: rf_importancia_aluguel.png\n")

png("rf_predito_obs_aluguel.png", width = 700, height = 700)
plot(teste_a$log_preco_aluguel, pred_a,
     xlab = "log(Preço Aluguel) Observado",
     ylab = "log(Preço Aluguel) Predito",
     main = "RF Aluguel: Predito vs Observado",
     pch  = 20, col = adjustcolor("coral3", alpha.f = 0.4))
abline(0, 1, col = "red", lwd = 2)
legend("topleft", bty = "n",
       legend = paste0("R² = ", round(r2_rf_a, 3),
                       "  |  RMSE = ", round(rmse_rf_a, 3)))
dev.off()
cat("Gráfico salvo: rf_predito_obs_aluguel.png\n")

# =========================================================================
# RF 3: COMPARATIVO MQO vs RANDOM FOREST (no conjunto de teste do RF)
# =========================================================================
cat("\n=== COMPARATIVO: MQO vs Random Forest ===\n")

# Recalcular métricas do MQO no mesmo conjunto de teste (comparação justa)
pred_mqo_v <- predict(modelo_venda_robusto,  newdata = teste_v)
pred_mqo_a <- predict(modelo_aluguel_robusto, newdata = teste_a)

tabela_comp <- data.frame(
  Modelo = c("MQO — Vendas", "RF — Vendas", "MQO — Aluguel", "RF — Aluguel"),
  R2     = round(c(
    cor(pred_mqo_v, teste_v$log_preco_venda)^2,
    r2_rf_v,
    cor(pred_mqo_a, teste_a$log_preco_aluguel)^2,
    r2_rf_a
  ), 4),
  RMSE   = round(c(
    sqrt(mean((pred_mqo_v - teste_v$log_preco_venda)^2)),
    rmse_rf_v,
    sqrt(mean((pred_mqo_a - teste_a$log_preco_aluguel)^2)),
    rmse_rf_a
  ), 4),
  MAE    = round(c(
    mean(abs(pred_mqo_v - teste_v$log_preco_venda)),
    mae_rf_v,
    mean(abs(pred_mqo_a - teste_a$log_preco_aluguel)),
    mae_rf_a
  ), 4)
)

cat("\n")
print(tabela_comp)

# =========================================================================
# RF 4: EXPORTAÇÃO DOS RESULTADOS
# =========================================================================
cat("\n=== Exportando Resultados RF ===\n")

write_xlsx(list(
  "Comparativo_MQO_RF"  = tabela_comp,
  "Importancia_Vendas"  = imp_v_df,
  "Importancia_Aluguel" = imp_a_df,
  "Tuning_Vendas"       = resultados_tuning_v,
  "Tuning_Aluguel"      = resultados_tuning_a
), path = "resultados_random_forest.xlsx")

cat("Arquivo salvo: resultados_random_forest.xlsx\n")

cat("\n========================================================\n")
cat("RESUMO FINAL — RANDOM FOREST\n")
cat("========================================================\n")
cat("\nVENDAS:\n")
cat("  R²   (teste):", round(r2_rf_v,   4), "\n")
cat("  RMSE (teste):", round(rmse_rf_v, 4), "\n")
cat("  MAE  (teste):", round(mae_rf_v,  4), "\n")
cat("  R²   (OOB)  :", round(oob_r2_v,  4), "\n")
cat("  mtry:", melhor_mtry_v, "| Árvores: 1000 | min.node.size: 5\n")

cat("\nALUGUEL:\n")
cat("  R²   (teste):", round(r2_rf_a,   4), "\n")
cat("  RMSE (teste):", round(rmse_rf_a, 4), "\n")
cat("  MAE  (teste):", round(mae_rf_a,  4), "\n")
cat("  R²   (OOB)  :", round(oob_r2_a,  4), "\n")
cat("  mtry:", melhor_mtry_a, "| Árvores: 1000 | min.node.size: 5\n")
