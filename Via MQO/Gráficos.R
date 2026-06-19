# =========================================================================
# 11. GRÁFICOS MQO
# =========================================================================

# Resíduos vs Valores Ajustados (detecta heterocedasticidade visual)
png("diagnostico_residuos_vs_ajustados.png", width = 1200, height = 500)
par(mfrow = c(1, 2))
plot(fitted(modelo_venda_robusto), residuals(modelo_venda_robusto),
     pch = 20, col = rgb(0, 0, 0, 0.1), cex = 0.5,
     main = "Resíduos vs Ajustados (Vendas)",
     xlab = "Valores Ajustados", ylab = "Resíduos")
abline(h = 0, col = "red", lty = 2)

plot(fitted(modelo_aluguel_robusto), residuals(modelo_aluguel_robusto),
     pch = 20, col = rgb(0, 0, 0, 0.1), cex = 0.5,
     main = "Resíduos vs Ajustados (Aluguel)",
     xlab = "Valores Ajustados", ylab = "Resíduos")
abline(h = 0, col = "red", lty = 2)
dev.off()

cat("\n=== SCRIPT FINALIZADO COM SUCESSO ===\n")
cat("Arquivos gerados:\n")
cat("  - resultados_modelo_hedonico.xlsx\n")
cat("  - tabela_modelos_tcc.txt\n")
cat("  - diagnostico_qqplot_vendas.png\n")
cat("  - diagnostico_qqplot_aluguel.png\n")
cat("  - diagnostico_cook_vendas.png\n")
cat("  - diagnostico_cook_aluguel.png\n")
cat("  - diagnostico_residuos_vs_ajustados.png\n")