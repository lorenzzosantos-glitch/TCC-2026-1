# Preços de Imóveis em Porto Alegre (2026)
### Uma Análise via Modelos de Preços Hedônicos

**Autor:** Lorenzzo Soares Santos  
**Orientador:** Prof. Dr. Sabino da Silva Porto Junior  
**Instituição:** UFRGS — Faculdade de Ciências Econômicas  
**Curso:** Ciências Econômicas  
**Ano:** 2026

---

## Sobre o projeto

Este TCC estima os determinantes dos preços de venda e aluguel de imóveis residenciais em Porto Alegre usando a metodologia de **preços hedônicos** (Rosen, 1974). A base de dados foi coletada do portal ZAP Imóveis e engloba anúncios ativos em 2026.

Três abordagens econométricas são comparadas:

| Abordagem | Script | Descrição |
|---|---|---|
| MQO (Mínimos Quadrados Ordinários) | `Via MQO/MQO.R` | Modelo hedônico log-linear padrão da literatura |
| Random Forest | `Via Random Forest/RF.R` | Modelo de aprendizado de máquina via `ranger` |
| Econometria Espacial | `Via Espacial/Espacial.R` | SAR e SEM com matriz de pesos knn (k=10) |

---

## Estrutura do repositório

```
TCC 2026-1/
│
├── Carregar base.R              # Etapa 1: carrega e limpa as duas bases
│
├── Base/
│   ├── porto_alegre_venda_zap.csv
│   └── porto_alegre_aluguel_zap.csv
│
├── Via MQO/
│   ├── MQO.R                   # Etapas 5–10: MQO, diagnósticos, exportação
│   └── Gráficos.R              # Gráficos de diagnóstico do MQO
│
├── Via Random Forest/
│   └── RF.R                    # Random Forest com tuning de mtry e comparativo
│
└── Via Espacial/
    └── Espacial.R              # SAR, SEM, Moran's I, testes LM
```

---

## Pré-requisitos

### R e RStudio

- **R** ≥ 4.3.0 — [cran.r-project.org](https://cran.r-project.org)
- **RStudio** ≥ 2023.12 (recomendado) — [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop)

### Pacotes necessários

Cole este bloco no console do R para instalar tudo de uma vez:

```r
install.packages(c(
  # MQO
  "car", "lmtest", "sandwich", "stargazer", "writexl", "ggplot2",
  # Random Forest
  "ranger", "caret",
  # Econometria Espacial
  "spdep", "spatialreg"
))
```

> **Nota sobre `spatialreg`:** a partir do R 4.0, as funções de estimação espacial (`lagsarlm`, `errorsarlm`) foram movidas do `spdep` para o pacote separado `spatialreg`. Ambos precisam estar instalados.

---

## Configuração antes de rodar

### 1. Atualizar o caminho dos dados

Abra `Carregar base.R` e localize a linha 31:

```r
setwd("C:/Users/loren/OneDrive/Documentos/Base de dados tcc")
```

Substitua pelo caminho da pasta `Base/` **no seu computador**. Exemplo:

```r
setwd("C:/Users/SEU_USUARIO/Documents/GitHub/TCC 2026-1/Base")
```

> Dica: no RStudio, vá em *Session → Set Working Directory → Choose Directory* e navegue até a pasta `Base/`.

### 2. Verificar os nomes dos arquivos CSV

Os arquivos CSV devem estar em `Base/` com os seguintes nomes exatos:

```
porto_alegre_venda_zap.csv
porto_alegre_aluguel_zap.csv
```

Se o `Carregar base.R` tentar ler com `.csv.csv` no final (duplicação de extensão), corrija as linhas 34–35:

```r
# De:
dados_venda_brutos  <- read.csv("porto_alegre_venda_zap.csv.csv")
dados_aluguel_brutos <- read.csv("porto_alegre_aluguel_zap.csv.csv")

# Para:
dados_venda_brutos  <- read.csv("porto_alegre_venda_zap.csv")
dados_aluguel_brutos <- read.csv("porto_alegre_aluguel_zap.csv")
```

---

## Ordem de execução

Os scripts **dependem uns dos outros** e devem ser rodados nessa ordem dentro da **mesma sessão do R** (ou via `source()`):

### Passo 1 — Carregar e limpar a base

```r
source("Carregar base.R")
```

Cria os objetos `dados_v` (vendas) e `dados_a` (aluguel) no ambiente. Todos os passos seguintes dependem deles.

---

### Passo 2 — MQO (Modelo Hedônico Base)

```r
source("Via MQO/MQO.R")
source("Via MQO/Gráficos.R")
```

**O que faz:**
- Estima três especificações (básica, avançada, log-log em área)
- Seleciona o melhor modelo por AIC
- Roda diagnósticos: VIF, Breusch-Pagan, Shapiro-Wilk, Distância de Cook
- Aplica erros-padrão robustos HC1 (White, 1980)
- Remove observações influentes pelo critério de Cook

**Objetos gerados** (necessários nos próximos passos):
- `modelo_venda_robusto` — MQO final de vendas (pós-Cook)
- `modelo_aluguel_robusto` — MQO final de aluguel (pós-Cook)

**Arquivos salvos:**
```
resultados_modelo_hedonico.xlsx
tabela_modelos_tcc.txt
diagnostico_qqplot_vendas.png
diagnostico_qqplot_aluguel.png
diagnostico_cook_vendas.png
diagnostico_cook_aluguel.png
diagnostico_residuos_vs_ajustados.png
```

---

### Passo 3 — Random Forest

> Rodar após o Passo 2.

```r
source("Via Random Forest/RF.R")
```

**O que faz:**
- Divide os dados em treino (80%) e teste (20%)
- Busca o melhor `mtry` via erro OOB (out-of-bag) para mtry ∈ {2, …, 7}
- Estima o modelo final com 1.000 árvores
- Calcula R², RMSE e MAE no conjunto de teste
- Gera importância das variáveis por permutação (top 20)
- Compara MQO vs RF no mesmo conjunto de teste

**Arquivos salvos:**
```
resultados_random_forest.xlsx
rf_importancia_vendas.png
rf_importancia_aluguel.png
rf_predito_obs_vendas.png
rf_predito_obs_aluguel.png
```

---

### Passo 4 — Econometria Espacial (SAR e SEM)

> Rodar após o Passo 2. Independente do Passo 3.

```r
source("Via Espacial/Espacial.R")
```

**O que faz:**
1. Filtra imóveis com coordenadas dentro dos limites de Porto Alegre
2. Constrói a matriz de pesos espaciais W (knn, k=10, row-standardized)
3. Re-estima o MQO no conjunto espacial (alinhamento de índices)
4. Testa autocorrelação espacial nos resíduos (**Moran's I**)
5. Aplica os **testes LM** de Anselin (1988) para escolha entre SAR e SEM:
   - `LMlag` / `RLMlag` → indica SAR
   - `LMerr` / `RLMerr` → indica SEM
6. Estima **SAR** (`lagsarlm`) e **SEM** (`errorsarlm`)
7. Calcula efeitos diretos, indiretos e totais para o SAR
8. Verifica Moran's I nos resíduos pós-estimação
9. Compara MQO vs SAR vs SEM por AIC, pseudo-R² e Moran residual

> **Tempo estimado:** a estimação de SAR/SEM com `method = "LU"` leva entre 1 e 5 minutos dependendo do tamanho da amostra.

**Arquivos salvos:**
```
resultados_espacial.xlsx
moran_residuos_vendas.png
moran_residuos_aluguel.png
```

---

## Resumo dos outputs

| Arquivo | Gerado por | Conteúdo |
|---|---|---|
| `resultados_modelo_hedonico.xlsx` | MQO.R | Coeficientes por variável, tipologia e bairro |
| `tabela_modelos_tcc.txt` | MQO.R | Tabela stargazer com erros robustos HC1 |
| `resultados_random_forest.xlsx` | RF.R | Comparativo MQO×RF, importâncias, tuning |
| `resultados_espacial.xlsx` | Espacial.R | Comparativo MQO×SAR×SEM, testes LM, coeficientes |
| `diagnostico_*.png` | MQO.R / Gráficos.R | Q-Q plot, Cook, resíduos vs ajustados |
| `rf_*.png` | RF.R | Importância, predito vs observado |
| `moran_residuos_*.png` | Espacial.R | Gráfico de dispersão de Moran |

---

## Metodologia resumida

### Modelo hedônico (Rosen, 1974)

```
log(Preço) = β₀ + β₁·log(Área) + β₂·Quartos + β₃·Vagas + β₄·Suítes
           + β₅·Piscina + β₆·Churrasqueira + β₇·Elevador
           + Σ δⱼ·Tipologiaⱼ + Σ γₖ·Bairroₖ + ε
```

A forma log-linear é padrão na literatura (González, 1993; Hermann & Haddad, 2005) e permite interpretar os coeficientes como variações percentuais no preço.

### Modelos espaciais

**SAR** — *Spatial Autoregressive* (Anselin, 1988):
```
log(P) = ρ·W·log(P) + X·β + ε
```
ρ captura o efeito dos preços dos imóveis vizinhos sobre o preço do imóvel. No SAR, os coeficientes β não são efeitos marginais diretos — é necessário decompor em efeitos direto, indireto e total via `impacts()`.

**SEM** — *Spatial Error Model* (Anselin, 1988):
```
log(P) = X·β + u,   u = λ·W·u + ε
```
λ captura autocorrelação nos erros, associada a variáveis omitidas com estrutura espacial (ex.: qualidade de infraestrutura, amenidades não observadas por bairro).

### Matriz de pesos W

Construída com k=10 vizinhos mais próximos (knn), usando distâncias geodésicas (fórmula de Haversine) e padronização por linha (*row-standardized*, `style = "W"`). A escolha de knn é adequada para dados de ponto (imóveis individuais) em contraposição à contiguidade poligonal usada para dados agregados por área.

---

## Variáveis

| Variável | Tipo | Descrição |
|---|---|---|
| `preco_venda` | Contínua | Preço de venda (R$) |
| `preco_aluguel` | Contínua | Preço de aluguel mensal (R$) |
| `area` | Contínua | Área privativa (m²) |
| `quartos` | Discreta | Número de dormitórios |
| `suites` | Discreta | Número de suítes |
| `vagas` | Discreta | Vagas de garagem |
| `tem_piscina` | Dummy | 1 se o condomínio tem piscina |
| `tem_churrasqueira` | Dummy | 1 se tem churrasqueira |
| `tem_elevador` | Dummy | 1 se tem elevador |
| `tipologia` | Fator | Tipo do imóvel (apartamento, casa, etc.) |
| `name` | Fator | Bairro (variável de efeito fixo espacial) |
| `latitude` / `longitude` | Coordenadas | Localização do imóvel (WGS84) |

---

## Referências

- ANSELIN, L. *Spatial Econometrics: Methods and Models*. Dordrecht: Kluwer, 1988.
- GONZÁLEZ, M. A. S. A pesquisa de avaliação de imóveis no Brasil. *Engenharia Civil*, Porto Alegre, 1993.
- HERMANN, B. M.; HADDAD, E. A. Mercado imobiliário e amenidades urbanas. *Estudos Econômicos*, v. 35, n. 3, 2005.
- LESAGE, J.; PACE, R. K. *Introduction to Spatial Econometrics*. Boca Raton: CRC Press, 2009.
- ROSEN, S. Hedonic prices and implicit markets. *Journal of Political Economy*, v. 82, n. 1, p. 34–55, 1974.
- WHITE, H. A heteroskedasticity-consistent covariance matrix estimator. *Econometrica*, v. 48, n. 4, p. 817–838, 1980.

---

## Licença

Código disponibilizado para fins acadêmicos. Os dados foram coletados de fonte pública (ZAP Imóveis) e são utilizados exclusivamente para pesquisa científica.
