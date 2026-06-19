# =============================================================================
# TCC: Preços dos Imóveis em Porto Alegre em 2026
#       Uma Análise via Modelo de Preços Hedônicos
# Autor: Lorenzzo Soares Santos
# Orientador: Dr. Sabino da Silva Porto Junior
# UFRGS - Faculdade de Ciências Econômicas
# =============================================================================
# Script completo: limpeza, estimação, diagnósticos e exportação
# =============================================================================

# =========================================================================
# 0. PACOTES NECESSÁRIOS
# =========================================================================
# Instalar apenas uma vez:
# install.packages(c("car", "lmtest", "sandwich", "stargazer", "writexl", "ggplot2"))

library(car)        # vif() - teste de multicolinearidade
library(lmtest)     # bptest() - teste de Breusch-Pagan (heterocedasticidade)
library(sandwich)   # vcovHC() - erros-padrão robustos (HC1)
library(stargazer)  # tabelas formatadas para o TCC
library(writexl)    # exportar para Excel
library(ggplot2)    # gráficos

# =========================================================================
# 1. CARREGAR AS BASES DE DADOS
# =========================================================================
cat("=== ETAPA 1: Carregando dados ===\n")

# Definir diretório de trabalho (onde estão os CSVs)
# NOTA: no R, usar barras normais "/" mesmo no Windows
setwd(file.path(dirname(rstudioapi::getSourceEditorContext()$path), "..", "Base"))

# Carregar os dados diretamente (reprodutível)
dados_venda_brutos  <- read.csv("porto_alegre_venda_zap.csv")
dados_aluguel_brutos <- read.csv("porto_alegre_aluguel_zap.csv")

cat("Vendas brutas:", nrow(dados_venda_brutos), "obs\n")
cat("Aluguel bruto:", nrow(dados_aluguel_brutos), "obs\n")

# =========================================================================
# 2. FUNÇÕES AUXILIARES DE LIMPEZA
# =========================================================================

# Função para limpar campos entre colchetes: "[3]" -> 3, "[]" -> 0
limpar_colchetes <- function(x) {
  num <- as.numeric(gsub("\\[|\\]|'", "", as.character(x)))
  num[is.na(num)] <- 0
  return(num)
}

# Função para extrair preço do campo pricingInfos (se necessário)
# Se preco_venda e preco_aluguel já existem, pular

# =========================================================================
# 3. LIMPEZA DA BASE DE VENDAS
# =========================================================================
cat("\n=== ETAPA 3: Limpeza - Base de Vendas ===\n")

dados_v <- dados_venda_brutos

# 3a. Limpar variáveis numéricas que vêm como texto com colchetes
dados_v$quartos   <- limpar_colchetes(dados_v$bedrooms)
dados_v$banheiros <- limpar_colchetes(dados_v$bathrooms)
dados_v$suites    <- limpar_colchetes(dados_v$suites)
dados_v$vagas     <- limpar_colchetes(dados_v$parkingSpaces)

# 3b. Filtros básicos de qualidade
dados_v <- subset(dados_v,
                  area > 10 &              # mínimo 10m² (exclui erros)
                    area < 1500 &            # máximo razoável
                    preco_venda > 50000 &    # mínimo R$50k
                    preco_venda < 20000000 & # máximo R$20M
                    quartos >= 0 &
                    vagas >= 0 &
                    tipologia != "RESIDENTIAL_ALLOTMENT_LAND" &  # exclui terrenos
                    name != "" & !is.na(name))  # bairro identificado

cat("Após filtros básicos:", nrow(dados_v), "obs\n")

# 3c. Remover duplicatas (mesmo local, área, quartos e preço)
dados_v <- dados_v[!duplicated(dados_v[c("latitude", "longitude", 
                                         "area", "quartos", "preco_venda")]), ]
cat("Após remoção de duplicatas:", nrow(dados_v), "obs\n")

# 3d. Criar variáveis dummy de amenidades
dados_v$tem_piscina       <- ifelse(grepl("POOL", dados_v$amenities, ignore.case = TRUE), 1, 0)
dados_v$tem_churrasqueira <- ifelse(grepl("BARBECUE", dados_v$amenities, ignore.case = TRUE), 1, 0)
dados_v$tem_elevador      <- ifelse(grepl("ELEVATOR", dados_v$amenities, ignore.case = TRUE), 1, 0)

# 3e. Criar preço por m²
dados_v$preco_m2 <- dados_v$preco_venda / dados_v$area

# 3f. Remoção de outliers pelo método IQR (percentis 1% e 99%)
#     Método transparente e reprodutível
q_preco <- quantile(dados_v$preco_venda, c(0.01, 0.99))
q_area  <- quantile(dados_v$area, c(0.01, 0.99))

dados_v <- subset(dados_v,
                  preco_venda >= q_preco[1] & preco_venda <= q_preco[2] &
                    area >= q_area[1] & area <= q_area[2])

cat("Após remoção de outliers (percentil 1%-99%):", nrow(dados_v), "obs\n")

# =========================================================================
# 4. LIMPEZA DA BASE DE ALUGUEL (mesma lógica)
# =========================================================================
cat("\n=== ETAPA 4: Limpeza - Base de Aluguel ===\n")

dados_a <- dados_aluguel_brutos

dados_a$quartos   <- limpar_colchetes(dados_a$bedrooms)
dados_a$banheiros <- limpar_colchetes(dados_a$bathrooms)
dados_a$suites    <- limpar_colchetes(dados_a$suites)
dados_a$vagas     <- limpar_colchetes(dados_a$parkingSpaces)

dados_a <- subset(dados_a,
                  area > 10 & area < 1500 &
                    preco_aluguel > 200 &       # mínimo R$200/mês
                    preco_aluguel < 50000 &     # máximo R$50k/mês
                    quartos >= 0 &
                    vagas >= 0 &
                    tipologia != "RESIDENTIAL_ALLOTMENT_LAND" &
                    name != "" & !is.na(name))

dados_a <- dados_a[!duplicated(dados_a[c("latitude", "longitude",
                                         "area", "quartos", "preco_aluguel")]), ]

dados_a$tem_piscina       <- ifelse(grepl("POOL", dados_a$amenities, ignore.case = TRUE), 1, 0)
dados_a$tem_churrasqueira <- ifelse(grepl("BARBECUE", dados_a$amenities, ignore.case = TRUE), 1, 0)
dados_a$tem_elevador      <- ifelse(grepl("ELEVATOR", dados_a$amenities, ignore.case = TRUE), 1, 0)

q_aluguel <- quantile(dados_a$preco_aluguel, c(0.01, 0.99))
q_area_a  <- quantile(dados_a$area, c(0.01, 0.99))
dados_a <- subset(dados_a,
                  preco_aluguel >= q_aluguel[1] & preco_aluguel <= q_aluguel[2] &
                    area >= q_area_a[1] & area <= q_area_a[2])

cat("Aluguel final:", nrow(dados_a), "obs\n")