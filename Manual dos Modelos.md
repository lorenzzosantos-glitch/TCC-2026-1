# Manual dos Modelos
### Guia Econométrico — TCC: Preços de Imóveis em Porto Alegre (2026)

**Autor:** Lorenzzo Soares Santos  
**Orientador:** Prof. Dr. Sabino da Silva Porto Junior  
**UFRGS — Faculdade de Ciências Econômicas**

---

## 1. O Modelo de Preços Hedônicos

### 1.1 A ideia por trás do modelo

Quando você compra um apartamento, você não está comprando um bem homogêneo — está comprando um pacote de atributos: metros quadrados, número de quartos, localização, presença de elevador, proximidade a escolas e parques. O preço observado no mercado é, na verdade, a soma implícita do que cada um desses atributos vale para os compradores.

Essa intuição foi formalizada por **Kevin Lancaster (1966)**, que propôs tratar os bens de consumo como cestas de características. A grande contribuição foi perceber que o mercado não precifica o bem diretamente — ele precifica os atributos que o compõem.

**Sherwin Rosen (1974)** levou essa ideia ao mercado imobiliário e criou o arcabouço que usamos até hoje. No artigo *"Hedonic Prices and Implicit Markets"*, ele mostrou que o preço de equilíbrio de um imóvel revela os **preços implícitos** de cada atributo — o quanto o mercado paga, na margem, por mais um quarto, por mais um metro quadrado, ou por estar num bairro específico.

O modelo ganhou enorme popularidade porque resolve um problema prático: como medir o valor de características que não são vendidas separadamente? Não existe um mercado para "estar a 500 metros de um parque", mas o mercado imobiliário revela esse valor toda vez que dois imóveis idênticos são vendidos a preços diferentes apenas por causa da localização.

No Brasil, a metodologia chegou com força nos anos 1990, a partir de trabalhos como os de **González (1993)** e, no caso específico de mercados urbanos, de **Hermann e Haddad (2005)**, que aplicaram modelos hedônicos para mensurar o efeito de amenidades urbanas sobre os preços em São Paulo.

### 1.2 Forma funcional

A especificação mais usada na literatura é a **log-linear** (ou semi-log):

```
log(Preço) = β₀ + β₁·log(Área) + β₂·Quartos + β₃·Vagas + β₄·Suítes
           + β₅·Piscina + β₆·Churrasqueira + β₇·Elevador
           + Σ δⱼ·Tipologiaⱼ + Σ γₖ·Bairroₖ + ε
```

A forma log garante que os coeficientes das variáveis contínuas sejam **elasticidades** (a variação percentual no preço associada a uma variação de 1% na área, por exemplo) e que os coeficientes das variáveis binárias sejam interpretados como variações percentuais aproximadas no preço.

Os **efeitos fixos de bairro** (dummies `γₖ`) capturam tudo o que é específico de cada bairro e não foi medido diretamente: infraestrutura, segurança, acesso a serviços, prestígio histórico. É uma forma transparente de controlar por localização sem precisar mensurar cada fator individualmente.

---

## 2. MQO — Mínimos Quadrados Ordinários

### 2.1 O que o MQO faz

O MQO (ou OLS, em inglês) é o método padrão para estimar os parâmetros β do modelo hedônico. Ele encontra os coeficientes que **minimizam a soma dos quadrados dos resíduos** — a diferença entre o preço observado e o preço previsto pelo modelo.

Sob as hipóteses clássicas (linearidade, independência, homoscedasticidade e normalidade dos erros), o MQO é o estimador linear não-viesado de menor variância — resultado conhecido como **Teorema de Gauss-Markov**.

No contexto de preços de imóveis, os coeficientes estimados têm uma interpretação econômica direta:

- **β₁ (log(Área))**: elasticidade-preço da área. Se β₁ = 0,55, um imóvel 10% maior tende a custar 5,5% a mais.
- **β₂ (Quartos)**: variação percentual no preço por quarto adicional.
- **γₖ (Bairro X)**: prêmio (ou desconto) percentual que o mercado atribui a estar no bairro X em relação ao bairro de referência.

### 2.2 Diagnósticos e correções

O MQO é sensível a violações das suas hipóteses. No mercado imobiliário, duas são especialmente comuns:

**Heterocedasticidade:** a variância dos erros tende a crescer com o preço do imóvel (imóveis caros têm maior dispersão de preços). Detectada pelo **teste de Breusch-Pagan** e corrigida com **erros-padrão robustos HC1** (White, 1980) — a correção não muda os coeficientes, apenas os erros-padrão e, consequentemente, os testes de significância.

**Observações influentes:** imóveis atípicos (cobertura de luxo, lote industrial classificado errado) podem distorcer os coeficientes. A **Distância de Cook** identifica observações cuja exclusão alteraria significativamente os parâmetros estimados. O critério padrão é remover observações com Cook > 4/n.

**Multicolinearidade:** variáveis correlacionadas (quartos e área, por exemplo) inflam os erros-padrão e dificultam a separação dos efeitos. O **VIF (Variance Inflation Factor)** mensura esse problema; valores acima de 10 indicam colinearidade severa.

### 2.3 O que o MQO não captura

O ponto cego do MQO clássico é a **dependência espacial**. Imóveis próximos tendem a ter preços similares — não apenas porque compartilham bairro (o que as dummies capturam), mas porque a vizinhança imediata tem um efeito que vai além das fronteiras administrativas. Quando essa dependência existe e é ignorada, os resíduos do MQO apresentam autocorrelação espacial, violando a hipótese de independência e tornando as inferências inválidas.

---

## 3. Modelos de Econometria Espacial

### 3.1 Por que o espaço importa

A **Primeira Lei da Geografia de Tobler (1970)** diz: *"tudo está relacionado com tudo, mas coisas próximas estão mais relacionadas entre si do que coisas distantes."* No mercado imobiliário, isso se manifesta de pelo menos duas formas:

1. **Spillover de preços:** o preço de um imóvel é influenciado pelos preços dos imóveis vizinhos — tanto por comparação de mercado (proprietários precificam com base em transações próximas recentes) quanto por externalidades reais (um empreendimento de luxo valoriza toda a quadra).

2. **Variáveis omitidas com estrutura espacial:** qualidade da iluminação pública, ruído de trânsito, acesso a ciclovias — variáveis que não estão na base mas que variam continuamente no espaço e afetam os preços. Quando omitidas, sua estrutura espacial contamina os resíduos do MQO.

O diagnóstico é feito via **Índice de Moran**, que testa se os resíduos do MQO apresentam autocorrelação espacial. Um Moran's I positivo e significativo indica que imóveis próximos têm resíduos de mesmo sinal — o modelo está sistematicamente errando na mesma direção em regiões específicas da cidade.

### 3.2 A matriz de pesos espaciais W

Antes de estimar qualquer modelo espacial, é preciso definir quem são os "vizinhos" de cada imóvel. Isso é feito pela **matriz de pesos W**, onde cada elemento wᵢⱼ representa o peso do imóvel j sobre o imóvel i.

Para dados de ponto (coordenadas de imóveis individuais), a escolha mais adequada é **k vizinhos mais próximos (knn)**, com k=10. Cada imóvel recebe influência de seus 10 vizinhos mais próximos em distância geodésica. A matriz é normalizada por linha (*row-standardized*), de modo que o somatório das influências recebidas por cada imóvel seja sempre 1 — isso garante que o parâmetro espacial (ρ ou λ) seja interpretável e comparável entre especificações.

### 3.3 SAR — Modelo Autorregressivo Espacial

O **SAR** (*Spatial Autoregressive Model*) captura **spillover de preços**. A hipótese é que o preço de um imóvel depende, em parte, dos preços dos imóveis vizinhos:

```
log(P) = ρ·W·log(P) + X·β + ε
```

O parâmetro **ρ** mede a intensidade do efeito de vizinhança. Se ρ = 0,3, um aumento de 10% nos preços dos imóveis vizinhos está associado a um aumento de 3% no preço do imóvel.

**Atenção:** no SAR, os coeficientes β não são efeitos marginais diretos. Como o preço de cada imóvel afeta os vizinhos, que afetam outros vizinhos em cascata, existe um efeito multiplicador. É necessário decompor os efeitos em:
- **Efeito direto:** impacto de uma variável sobre o próprio imóvel
- **Efeito indireto (spillover):** impacto que se propaga pelos vizinhos
- **Efeito total:** soma dos dois

Essa decomposição, feita via `impacts()` no R, é o que torna os resultados do SAR economicamente interpretáveis.

### 3.4 SEM — Modelo de Erro Espacial

O **SEM** (*Spatial Error Model*) captura **autocorrelação nos erros** — não nos preços. A hipótese é que variáveis omitidas relevantes têm estrutura espacial:

```
log(P) = X·β + u,   u = λ·W·u + ε
```

O parâmetro **λ** mede a autocorrelação dos resíduos. No SEM, os coeficientes β têm interpretação direta (diferente do SAR), pois o problema espacial está no termo de erro, não na variável dependente. O SEM é preferido quando a autocorrelação espacial é interpretada como consequência de variáveis omitidas, não de interação de mercado.

### 3.5 Como escolher entre SAR e SEM

Os **testes LM de Anselin (1988)** são o critério padrão:

| Teste | Hipótese alternativa |
|---|---|
| LMlag | Existe dependência espacial na variável dependente → SAR |
| LMerr | Existe autocorrelação espacial nos erros → SEM |
| RLMlag (robusto) | LMlag controlado pela presença de erro espacial |
| RLMerr (robusto) | LMerr controlado pela presença de defasagem espacial |

A regra prática: se apenas LMlag é significativo → SAR; se apenas LMerr é significativo → SEM; se ambos forem significativos, compare os robustos (RLM) e escolha o de maior estatística.

---

## 4. Random Forest — O que muda na análise

### 4.1 Uma abordagem diferente de previsão

O **Random Forest** é um algoritmo de aprendizado de máquina que constrói centenas de árvores de decisão sobre subamostras aleatórias dos dados e combina as previsões pela média. Cada árvore aprende a segmentar os dados por regras do tipo "se área > 80m² e bairro = Moinhos de Vento, então o preço tende a ser X".

O RF não substitui o modelo hedônico — ele **complementa** a análise, respondendo a uma pergunta diferente: quanto do preço conseguimos prever sem impor nenhuma estrutura funcional?

### 4.2 O que o RF libera em relação ao MQO

**Não linearidades:** o MQO assume que o efeito de cada variável é constante. O RF captura que o efeito de um quarto adicional pode ser muito diferente em um studio de 30m² e em uma mansão de 500m². Não é necessário especificar interações ou transformações manualmente.

**Interações complexas:** o valor de ter piscina pode depender do bairro, da tipologia e do tamanho do imóvel ao mesmo tempo. O RF detecta essas interações automaticamente, sem que o pesquisador precise antecipá-las.

**Robustez a outliers:** como cada árvore vê apenas uma subamostra dos dados, observações atípicas têm influência limitada sobre o resultado final. O processo de remoção de outliers por Cook ou IQR, necessário no MQO, perde parte de sua urgência no RF.

**Sem hipóteses distribucionais:** o MQO exige normalidade dos erros para inferência em amostras pequenas. O RF não faz nenhuma suposição sobre a distribuição dos dados.

### 4.3 O que o RF não faz

**Interpretação estrutural:** os coeficientes do MQO têm significado econômico claro — são preços implícitos, derivados de uma teoria. O RF não oferece isso. A importância das variáveis por permutação diz quais atributos mais afetam a previsão, mas não diz *quanto* um quarto adicional vale em reais.

**Inferência causal:** o RF é um método preditivo. Ele não foi projetado para estimar efeitos causais nem para testar hipóteses econômicas sobre os determinantes do preço.

**Extrapolação:** o RF interpola bem dentro do suporte dos dados de treinamento, mas extrapola mal. Um imóvel com características fora do range observado receberá previsões menos confiáveis do que no MQO.

### 4.4 Como o RF é usado neste TCC

O RF é estimado com as **mesmas variáveis** do MQO — log(Área), quartos, vagas, suítes, amenidades, tipologia e bairro — para que a comparação de desempenho seja justa. O critério de avaliação são R², RMSE e MAE calculados no **mesmo conjunto de teste** (20% dos dados, separados antes de qualquer estimação).

O parâmetro **mtry** (número de variáveis consideradas em cada divisão da árvore) é otimizado por busca via erro OOB (*out-of-bag*) para valores entre 2 e 7. O modelo final usa 1.000 árvores com `min.node.size = 5`.

A **importância das variáveis por permutação** mostra como o erro de previsão aumenta quando os valores de cada variável são embaralhados aleatoriamente. Variáveis com alta importância são aquelas cujas relações com o preço o modelo aprendeu com maior profundidade.

A pergunta central da comparação é: **o ganho de previsão do RF em relação ao MQO é expressivo o suficiente para justificar a perda de interpretabilidade?** Em mercados relativamente bem comportados, a resposta costuma ser não — e essa é, em si, uma conclusão econômica relevante.
