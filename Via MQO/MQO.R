# =========================================================================
# 5. ESTATÍSTICAS DESCRITIVAS
# =========================================================================
cat("\n=== ETAPA 5: Estatísticas Descritivas ===\n")

vars_descritivas_v <- dados_v[, c("preco_venda", "area", "quartos", "banheiros",
                                  "suites", "vagas", "tem_piscina",
                                  "tem_churrasqueira", "tem_elevador")]
cat("\n--- Vendas ---\n")
print(summary(vars_descritivas_v))

vars_descritivas_a <- dados_a[, c("preco_aluguel", "area", "quartos", "banheiros",
                                  "suites", "vagas", "tem_piscina",
                                  "tem_churrasqueira", "tem_elevador")]
cat("\n--- Aluguel ---\n")
print(summary(vars_descritivas_a))

# =========================================================================
# 6. ESTIMAÇÃO DO MODELO HEDÔNICO - VENDAS
# =========================================================================
cat("\n=== ETAPA 6: Modelo Hedônico de Vendas ===\n")

# --------------------------------------------------------------------------
# MODELO 1 (Básico): log(P) = f(area, quartos, vagas, bairro, tipologia)
# Justificativa: forma funcional log-linear, padrão na literatura
# (Rosen, 1974; González, 1993; Hermann & Haddad, 2005)
# --------------------------------------------------------------------------
modelo_v1 <- lm(log(preco_venda) ~ area + quartos + vagas +
                  as.factor(tipologia) + as.factor(name),
                data = dados_v)

cat("\n--- Modelo Vendas 1 (Básico) ---\n")
cat("R² ajustado:", summary(modelo_v1)$adj.r.squared, "\n")
cat("Nº observações:", nobs(modelo_v1), "\n")

# --------------------------------------------------------------------------
# MODELO 2 (Avançado): adiciona amenidades
# NOTA SOBRE MULTICOLINEARIDADE:
# - quartos e banheiros são altamente correlacionados
# - suítes estão contidas em quartos E em banheiros
# SOLUÇÃO: incluir quartos + suítes (capta diferenciação de qualidade)
#          NÃO incluir banheiros junto com suítes (redundância)
# --------------------------------------------------------------------------
modelo_v2 <- lm(log(preco_venda) ~ area + quartos + vagas + suites +
                  tem_piscina + tem_churrasqueira + tem_elevador +
                  as.factor(tipologia) + as.factor(name),
                data = dados_v)

cat("\n--- Modelo Vendas 2 (Avançado) ---\n")
cat("R² ajustado:", summary(modelo_v2)$adj.r.squared, "\n")

# --------------------------------------------------------------------------
# MODELO 3 (Log-Log em área): captura retornos decrescentes
# log(P) = β₀ + β₁·log(area) + β₂·quartos + ...
# Interpretação: β₁ = elasticidade (aumento de 1% na área → β₁% no preço)
# --------------------------------------------------------------------------
modelo_v3 <- lm(log(preco_venda) ~ log(area) + quartos + vagas + suites +
                  tem_piscina + tem_churrasqueira + tem_elevador +
                  as.factor(tipologia) + as.factor(name),
                data = dados_v)

cat("\n--- Modelo Vendas 3 (Log-Log em área) ---\n")
cat("R² ajustado:", summary(modelo_v3)$adj.r.squared, "\n")

# Comparação via AIC (critério de informação de Akaike)
cat("\n--- Comparação de Modelos (AIC - menor é melhor) ---\n")
cat("Modelo 1 (Básico):", AIC(modelo_v1), "\n")
cat("Modelo 2 (Avançado):", AIC(modelo_v2), "\n")
cat("Modelo 3 (Log-Log):", AIC(modelo_v3), "\n")

# ESCOLHER O MELHOR MODELO para diagnósticos:
# (ajuste conforme o AIC - provavelmente será o modelo 3)
modelo_venda_final <- modelo_v3

# =========================================================================
# 7. DIAGNÓSTICOS ECONOMÉTRICOS - VENDAS
# =========================================================================
cat("\n=== ETAPA 7: Diagnósticos do Modelo de Vendas ===\n")

# 7a. TESTE VIF (Variance Inflation Factor) - Multicolinearidade
# Regra: VIF > 10 indica problema sério; VIF > 5 merece atenção
cat("\n--- 7a. Teste VIF (Multicolinearidade) ---\n")

# Para calcular VIF, precisamos de um modelo SEM os fatores (bairro/tipologia)
# porque as dummies geram VIF generalizado muito alto por construção
modelo_vif <- lm(log(preco_venda) ~ log(area) + quartos + vagas + suites +
                   tem_piscina + tem_churrasqueira + tem_elevador,
                 data = dados_v)
vif_resultado <- vif(modelo_vif)
print(vif_resultado)

# Se algum VIF > 10, remover a variável problemática
if (any(vif_resultado > 10)) {
  cat("ALERTA: Multicolinearidade detectada! Verificar variáveis com VIF > 10.\n")
} else {
  cat("OK: Nenhuma variável contínua apresenta VIF > 10.\n")
}

# VIF generalizado para fatores (GVIF)
cat("\n--- GVIF para o modelo completo ---\n")
print(vif(modelo_venda_final))

# 7b. ERROS-PADRÃO ROBUSTOS (HC1) - Correção de Heterocedasticidade
# Em amostras grandes de mercado imobiliário, heterocedasticidade é esperada
# (imóveis mais caros têm maior variância de preço).
# Seguindo White (1980), reportamos erros-padrão robustos por padrão.
cat("\n--- 7b. Estimação com Erros-Padrão Robustos (HC1) ---\n")

# Erros robustos à la White (HC1)
coef_robustos_v <- coeftest(modelo_venda_final, 
                            vcov = vcovHC(modelo_venda_final, type = "HC1"))

# Teste de Breusch-Pagan (reportar no TCC como justificativa para erros robustos)
bp_teste <- bptest(modelo_venda_final)
cat("Teste de Breusch-Pagan: estatística =", bp_teste$statistic, 
    ", p-valor =", bp_teste$p.value, "\n")
if (bp_teste$p.value < 0.05) {
  cat("Heterocedasticidade confirmada (p < 0.05) — erros robustos HC1 aplicados.\n")
} else {
  cat("Homocedasticidade não rejeitada, mas erros robustos mantidos por precaução.\n")
}

# Matriz de variância-covariância robusta (guardar para usar no stargazer)
vcov_robusto_v <- vcovHC(modelo_venda_final, type = "HC1")

cat("\n--- Coeficientes com Erros Robustos (Vendas) ---\n")
print(coef_robustos_v)

# 7c. NORMALIDADE DOS RESÍDUOS
cat("\n--- 7c. Normalidade dos Resíduos ---\n")

# Shapiro-Wilk (aceita no máximo 5000 obs - usar subamostra se necessário)
set.seed(42)
amostra_residuos <- sample(residuals(modelo_venda_final), 
                           min(5000, length(residuals(modelo_venda_final))))
shapiro_teste <- shapiro.test(amostra_residuos)
print(shapiro_teste)
cat("Nota: Com amostras grandes (>5000 obs), o Shapiro-Wilk tende a rejeitar\n")
cat("      normalidade mesmo com desvios pequenos. Avaliar visualmente pelo Q-Q plot.\n")

# Gráfico Q-Q dos resíduos (salvar para o TCC)
png("diagnostico_qqplot_vendas.png", width = 800, height = 600)
par(mfrow = c(1, 2))
qqnorm(residuals(modelo_venda_final), main = "Q-Q Plot - Resíduos (Vendas)")
qqline(residuals(modelo_venda_final), col = "red", lwd = 2)
hist(residuals(modelo_venda_final), breaks = 50, 
     main = "Histograma dos Resíduos (Vendas)",
     xlab = "Resíduos", col = "lightblue", border = "white")
dev.off()
cat("Gráfico salvo: diagnostico_qqplot_vendas.png\n")

# 7d. REMOÇÃO DE OUTLIERS POR DISTÂNCIA DE COOK
cat("\n--- 7d. Análise de Outliers (Distância de Cook) ---\n")
cooks_v <- cooks.distance(modelo_venda_final)
limiar_cook <- 4 / nobs(modelo_venda_final)
n_outliers_cook <- sum(cooks_v > limiar_cook)
cat("Limiar de Cook (4/n):", limiar_cook, "\n")
cat("Observações influentes:", n_outliers_cook, "\n")

# Gráfico de Cook
png("diagnostico_cook_vendas.png", width = 800, height = 400)
plot(cooks_v, type = "h", main = "Distância de Cook - Vendas",
     ylab = "Distância de Cook", xlab = "Observação")
abline(h = limiar_cook, col = "red", lty = 2)
dev.off()
cat("Gráfico salvo: diagnostico_cook_vendas.png\n")

# Re-estimar SEM outliers influentes
dados_v_limpo <- dados_v[cooks_v <= limiar_cook, ]
cat("Observações após remoção por Cook:", nrow(dados_v_limpo), "\n")

modelo_venda_robusto <- lm(log(preco_venda) ~ log(area) + quartos + vagas + suites +
                             tem_piscina + tem_churrasqueira + tem_elevador +
                             as.factor(tipologia) + as.factor(name),
                           data = dados_v_limpo)

cat("R² ajustado (sem outliers):", summary(modelo_venda_robusto)$adj.r.squared, "\n")

# =========================================================================
# 8. ESTIMAÇÃO DO MODELO HEDÔNICO - ALUGUEL
# =========================================================================
cat("\n=== ETAPA 8: Modelo Hedônico de Aluguel ===\n")

# Modelo básico
modelo_a1 <- lm(log(preco_aluguel) ~ area + quartos + suites +
                  tem_piscina + tem_churrasqueira + tem_elevador +
                  as.factor(tipologia) + as.factor(name),
                data = dados_a)

# Modelo log-log em área
modelo_a2 <- lm(log(preco_aluguel) ~ log(area) + quartos + suites +
                  tem_piscina + tem_churrasqueira + tem_elevador +
                  as.factor(tipologia) + as.factor(name),
                data = dados_a)

cat("R² ajustado (linear):", summary(modelo_a1)$adj.r.squared, "\n")
cat("R² ajustado (log-log):", summary(modelo_a2)$adj.r.squared, "\n")
cat("AIC (linear):", AIC(modelo_a1), "\n")
cat("AIC (log-log):", AIC(modelo_a2), "\n")

modelo_aluguel_final <- modelo_a2  # ajustar conforme AIC

# =========================================================================
# 9. DIAGNÓSTICOS - ALUGUEL
# =========================================================================
cat("\n=== ETAPA 9: Diagnósticos do Modelo de Aluguel ===\n")

# VIF
modelo_vif_a <- lm(log(preco_aluguel) ~ log(area) + quartos + suites +
                     tem_piscina + tem_churrasqueira + tem_elevador,
                   data = dados_a)
cat("\n--- VIF (Aluguel) ---\n")
print(vif(modelo_vif_a))

# Erros-Padrão Robustos (HC1) - Aluguel
cat("\n--- Erros-Padrão Robustos HC1 (Aluguel) ---\n")

coef_robustos_a <- coeftest(modelo_aluguel_final,
                            vcov = vcovHC(modelo_aluguel_final, type = "HC1"))

bp_a <- bptest(modelo_aluguel_final)
cat("Teste de Breusch-Pagan: estatística =", bp_a$statistic,
    ", p-valor =", bp_a$p.value, "\n")
if (bp_a$p.value < 0.05) {
  cat("Heterocedasticidade confirmada — erros robustos HC1 aplicados.\n")
} else {
  cat("Homocedasticidade não rejeitada, mas erros robustos mantidos por precaução.\n")
}

vcov_robusto_a <- vcovHC(modelo_aluguel_final, type = "HC1")

cat("\n--- Coeficientes com Erros Robustos (Aluguel) ---\n")
print(coef_robustos_a)

# Q-Q plot
png("diagnostico_qqplot_aluguel.png", width = 800, height = 600)
par(mfrow = c(1, 2))
qqnorm(residuals(modelo_aluguel_final), main = "Q-Q Plot - Resíduos (Aluguel)")
qqline(residuals(modelo_aluguel_final), col = "red", lwd = 2)
hist(residuals(modelo_aluguel_final), breaks = 50,
     main = "Histograma dos Resíduos (Aluguel)",
     xlab = "Resíduos", col = "lightblue", border = "white")
dev.off()

# Cook's distance
cat("\n--- Distância de Cook (Aluguel) ---\n")
cooks_a <- cooks.distance(modelo_aluguel_final)
limiar_cook_a <- 4 / nobs(modelo_aluguel_final)
n_outliers_cook_a <- sum(cooks_a > limiar_cook_a)
cat("Limiar de Cook (4/n):", limiar_cook_a, "\n")
cat("Observações influentes:", n_outliers_cook_a, "\n")

# Gráfico de Cook - Aluguel
png("diagnostico_cook_aluguel.png", width = 800, height = 400)
plot(cooks_a, type = "h", main = "Distância de Cook - Aluguel",
     ylab = "Distância de Cook", xlab = "Observação")
abline(h = limiar_cook_a, col = "red", lty = 2)
dev.off()
cat("Gráfico salvo: diagnostico_cook_aluguel.png\n")

dados_a_limpo <- dados_a[cooks_a <= limiar_cook_a, ]

modelo_aluguel_robusto <- lm(log(preco_aluguel) ~ log(area) + quartos + suites +
                               tem_piscina + tem_churrasqueira + tem_elevador +
                               as.factor(tipologia) + as.factor(name),
                             data = dados_a_limpo)

cat("R² ajustado (sem outliers):", summary(modelo_aluguel_robusto)$adj.r.squared, "\n")

# =========================================================================
# 10. EXPORTAÇÃO DE RESULTADOS PARA O TCC
# =========================================================================
cat("\n=== ETAPA 10: Exportando Resultados ===\n")

# 10a. Tabela comparativa dos modelos (para o Word)
# Extrai apenas as variáveis estruturais (não as 82 dummies de bairro)
gerar_tabela <- function(modelo, nome_modelo) {
  s <- summary(modelo)
  coefs <- as.data.frame(s$coefficients)
  colnames(coefs) <- c("Coeficiente", "Erro_Padrao", "t_valor", "p_valor")
  
  # Significância
  coefs$Sig <- ifelse(coefs$p_valor < 0.001, "***",
                      ifelse(coefs$p_valor < 0.01, "**",
                             ifelse(coefs$p_valor < 0.05, "*",
                                    ifelse(coefs$p_valor < 0.1, ".", "NS"))))
  
  coefs$Variavel <- rownames(coefs)
  coefs$Modelo <- nome_modelo
  
  # Separar variáveis estruturais e de bairro
  is_bairro <- grepl("as.factor\\(name\\)", coefs$Variavel)
  is_tipologia <- grepl("as.factor\\(tipologia\\)", coefs$Variavel)
  
  lista <- list(
    estruturais = coefs[!is_bairro & !is_tipologia, ],
    tipologia = coefs[is_tipologia, ],
    bairros = coefs[is_bairro, ],
    r2_ajustado = s$adj.r.squared,
    f_stat = s$fstatistic[1],
    n_obs = nobs(modelo),
    aic = AIC(modelo)
  )
  return(lista)
}

tab_venda <- gerar_tabela(modelo_venda_robusto, "Vendas")
tab_aluguel <- gerar_tabela(modelo_aluguel_robusto, "Aluguel")

# Exportar para Excel (3 abas)
write_xlsx(list(
  "Var_Estruturais_Venda" = tab_venda$estruturais,
  "Tipologia_Venda" = tab_venda$tipologia,
  "Bairros_Venda" = tab_venda$bairros,
  "Var_Estruturais_Aluguel" = tab_aluguel$estruturais,
  "Tipologia_Aluguel" = tab_aluguel$tipologia,
  "Bairros_Aluguel" = tab_aluguel$bairros
), path = "resultados_modelo_hedonico.xlsx")

cat("Tabelas salvas: resultados_modelo_hedonico.xlsx\n")

# 10b. Resumo dos modelos
cat("\n========================================================\n")
cat("RESUMO FINAL DOS MODELOS\n")
cat("========================================================\n")
cat("\nMODELO DE VENDAS:\n")
cat("  R² ajustado:", tab_venda$r2_ajustado, "\n")
cat("  F-statistic:", tab_venda$f_stat, "\n")
cat("  N obs:", tab_venda$n_obs, "\n")
cat("  AIC:", tab_venda$aic, "\n")

cat("\nMODELO DE ALUGUEL:\n")
cat("  R² ajustado:", tab_aluguel$r2_ajustado, "\n")
cat("  F-statistic:", tab_aluguel$f_stat, "\n")
cat("  N obs:", tab_aluguel$n_obs, "\n")
cat("  AIC:", tab_aluguel$aic, "\n")

# 10c. Tabela LaTeX/HTML via stargazer com erros robustos HC1
# Calcular erros robustos para os modelos finais (pós-Cook)
vcov_robusto_vf <- vcovHC(modelo_venda_robusto, type = "HC1")
vcov_robusto_af <- vcovHC(modelo_aluguel_robusto, type = "HC1")

# Extrair erros-padrão robustos
se_robusto_v <- sqrt(diag(vcov_robusto_vf))
se_robusto_a <- sqrt(diag(vcov_robusto_af))

stargazer(modelo_venda_robusto, modelo_aluguel_robusto,
          type = "text",
          se = list(se_robusto_v, se_robusto_a),  # erros robustos HC1
          title = "Modelos Hedônicos - Porto Alegre (2026) — Erros Robustos HC1",
          dep.var.labels = c("log(Preço Venda)", "log(Preço Aluguel)"),
          omit = c("as.factor\\(name\\)", "as.factor\\(tipologia\\)"),
          omit.labels = c("Dummies de Bairro", "Dummies de Tipologia"),
          add.lines = list(
            c("Dummies de Bairro", "Sim", "Sim"),
            c("Dummies de Tipologia", "Sim", "Sim"),
            c("Erros-padrão", "Robustos (HC1)", "Robustos (HC1)")
          ),
          notes = "Erros-padrão robustos (HC1) entre parênteses.",
          out = "tabela_modelos_tcc.txt")

cat("\nTabela stargazer salva: tabela_modelos_tcc.txt\n")
