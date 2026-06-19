"""
Scraper - Zap Imóveis (Porto Alegre)
Coleta anúncios de venda e aluguel via API interna do site.
Saída: Base/porto_alegre_venda_zap.csv e Base/porto_alegre_aluguel_zap.csv
"""

import requests
import pandas as pd
import time
import os
import json

# ---------------------------------------------------------------------------
# Configurações
# ---------------------------------------------------------------------------
OUTPUT_DIR  = "Base"
CITY        = "Porto Alegre"
STATE       = "Rio Grande do Sul"
MAX_PAGES   = 100        # máximo de páginas por tipo (24 itens/página)
PAGE_SIZE   = 24
DELAY       = 1.5        # segundos entre requisições (evita bloqueio)

os.makedirs(OUTPUT_DIR, exist_ok=True)

BASE_URL = "https://glue-api.zapimoveis.com.br/v2/listings"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "pt-BR,pt;q=0.9",
    "Origin": "https://www.zapimoveis.com.br",
    "Referer": "https://www.zapimoveis.com.br/",
    "x-domain": "www.zapimoveis.com.br",
}

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------

def build_params(business: str, page_from: int) -> dict:
    """Monta os parâmetros da requisição."""
    return {
        "user":            "anuncia-portal-external-client",
        "portal":          "ZAP",
        "business":        business,          # SALE | RENTAL
        "categoryPage":    "RESULT",
        "listingType":     "USED",
        "addressCity":     CITY,
        "addressState":    STATE,
        "addressCountry":  "Brasil",
        "size":            PAGE_SIZE,
        "from":            page_from,
    }


def extrair_valor_colchete(valor):
    """Mantém o formato original para compatibilidade com limpar_colchetes() do R."""
    return valor  # já vem como string/lista; preservamos


def parsear_listagem(listing: dict) -> dict:
    """Extrai os campos relevantes de um item da API."""
    listing_data = listing.get("listing", {})
    link         = listing.get("link",    {})

    # Localização
    address  = listing_data.get("address", {})
    geo      = address.get("point", {})
    bairro   = address.get("neighborhood", "")

    # Preços
    pricing  = listing_data.get("pricingInfos", [{}])
    preco_venda   = None
    preco_aluguel = None
    for p in pricing:
        if p.get("businessType") == "SALE":
            preco_venda   = _to_float(p.get("price"))
        if p.get("businessType") == "RENTAL":
            preco_aluguel = _to_float(p.get("price"))

    # Amenidades (lista → string separada por vírgula)
    amenities = listing_data.get("amenities", [])
    amenities_str = ",".join(amenities) if isinstance(amenities, list) else str(amenities)

    return {
        "id":              listing_data.get("id", ""),
        "tipologia":       listing_data.get("unitTypes", [""])[0] if listing_data.get("unitTypes") else "",
        "area":            _to_float(listing_data.get("usableAreas", [None])[0]),
        "bedrooms":        f"[{listing_data.get('bedrooms', [0])[0] if listing_data.get('bedrooms') else 0}]",
        "bathrooms":       f"[{listing_data.get('bathrooms', [0])[0] if listing_data.get('bathrooms') else 0}]",
        "suites":          f"[{listing_data.get('suites', [0])[0] if listing_data.get('suites') else 0}]",
        "parkingSpaces":   f"[{listing_data.get('parkingSpaces', [0])[0] if listing_data.get('parkingSpaces') else 0}]",
        "amenities":       amenities_str,
        "name":            bairro,
        "latitude":        geo.get("lat"),
        "longitude":       geo.get("lon"),
        "preco_venda":     preco_venda,
        "preco_aluguel":   preco_aluguel,
    }


def _to_float(value):
    """Converte valor para float, retorna None se inválido."""
    try:
        return float(str(value).replace(",", ".")) if value is not None else None
    except (ValueError, TypeError):
        return None


# ---------------------------------------------------------------------------
# Coleta principal
# ---------------------------------------------------------------------------

def coletar(business: str) -> list[dict]:
    """Percorre todas as páginas para um tipo de negócio (SALE ou RENTAL)."""
    nome = "Vendas" if business == "SALE" else "Aluguel"
    print(f"\n{'='*55}")
    print(f"  Coletando: {nome} — {CITY}")
    print(f"{'='*55}")

    registros   = []
    total_api   = None
    page_from   = 0

    while True:
        params = build_params(business, page_from)
        try:
            resp = requests.get(BASE_URL, headers=HEADERS, params=params, timeout=20)
            resp.raise_for_status()
            data = resp.json()
        except requests.exceptions.HTTPError as e:
            print(f"  [ERRO HTTP] {e} — encerrando coleta.")
            break
        except Exception as e:
            print(f"  [ERRO] {e} — encerrando coleta.")
            break

        listings = (
            data.get("search", {})
                .get("result", {})
                .get("listings", [])
        )

        if total_api is None:
            total_api = (
                data.get("search", {})
                    .get("totalCount", 0)
            )
            paginas_estimadas = (total_api // PAGE_SIZE) + 1
            print(f"  Total de anúncios encontrados: {total_api}")
            print(f"  Páginas estimadas: {min(paginas_estimadas, MAX_PAGES)}\n")

        if not listings:
            print("  Sem mais resultados.")
            break

        for item in listings:
            try:
                registros.append(parsear_listagem(item))
            except Exception:
                pass  # ignora item malformado

        page_from += PAGE_SIZE
        pagina_atual = page_from // PAGE_SIZE
        print(f"  Página {pagina_atual:3d} | Coletados até agora: {len(registros)}")

        if page_from >= total_api or pagina_atual >= MAX_PAGES:
            break

        time.sleep(DELAY)

    print(f"\n  Total coletado ({nome}): {len(registros)} registros")
    return registros


# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # --- Vendas ---
    dados_venda = coletar("SALE")
    if dados_venda:
        df_venda = pd.DataFrame(dados_venda)
        df_venda = df_venda.drop_duplicates(subset=["latitude", "longitude", "area", "bedrooms", "preco_venda"])
        path_venda = os.path.join(OUTPUT_DIR, "porto_alegre_venda_zap.csv")
        df_venda.to_csv(path_venda, index=False, encoding="utf-8")
        print(f"\nSalvo: {path_venda} ({len(df_venda)} linhas)")

    # --- Aluguel ---
    dados_aluguel = coletar("RENTAL")
    if dados_aluguel:
        df_aluguel = pd.DataFrame(dados_aluguel)
        df_aluguel = df_aluguel.drop_duplicates(subset=["latitude", "longitude", "area", "bedrooms", "preco_aluguel"])
        path_aluguel = os.path.join(OUTPUT_DIR, "porto_alegre_aluguel_zap.csv")
        df_aluguel.to_csv(path_aluguel, index=False, encoding="utf-8")
        print(f"Salvo: {path_aluguel} ({len(df_aluguel)} linhas)")

    print("\nColeta finalizada.")
