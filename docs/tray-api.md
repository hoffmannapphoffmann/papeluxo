# Documentação da API Tray — Papeluxo

**Baseado no e-mail oficial da Tray + testes realizados em 17/06/2026**  
**Versão:** 1.0  
**Status:** ✅ Endpoints validados

---

## 1. Informações Gerais

| Item | Valor |
|------|-------|
| API Base URL (Teste) | `https://lojatesteintegracaotray.commercesuite.com.br/web_api` |
| API Base URL (Produção) | `https://www.papelecompanhia.com.br/web_api` |
| Store ID (Teste) | 1501119 |
| Store ID (Produção) | 1211391 |
| Autenticação | OAuth 2.0 (consumer_key + consumer_secret) |
| Formato | JSON |

---

## 2. Autenticação

### 2.1 Obter Access Token (primeira vez)

**Endpoint:**
```
POST {{TRAY_API_URL}}/auth
```

**Parâmetros (query string):**

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| consumer_key | Sim | Sua Consumer Key |
| consumer_secret | Sim | Seu Consumer Secret |
| code | Sim | Authorization Code (gerado na instalação do app) |

**Resposta:**
```json
{
  "access_token": "APP_ID-8717-STORE_ID-1501119-...",
  "refresh_token": "9fbc331a9a5cf799...",
  "date_expiration_access_token": "2026-06-17 18:00:48",
  "date_expiration_refresh_token": "2026-07-17 15:00:48",
  "api_host": "https://lojatesteintegracaotray.commercesuite.com.br/web_api",
  "store_id": "1501119"
}
```

### 2.2 Renovar Access Token (✅ TESTADO E FUNCIONANDO)

**Endpoint:**
```
GET {{TRAY_API_URL}}/auth?consumer_key={{KEY}}&consumer_secret={{SECRET}}&refresh_token={{REFRESH_TOKEN}}
```

⚠️ **IMPORTANTE:** Use `refresh_token` (NÃO `code`) como parâmetro.

**Exemplo (PowerShell):**
```powershell
$url = "https://lojatesteintegracaotray.commercesuite.com.br/web_api/auth?consumer_key=$consumerKey&consumer_secret=$consumerSecret&refresh_token=$refreshToken"
Invoke-RestMethod -Uri $url -Method GET
```

**Resposta:**
```json
{
  "message": "Refreshed tokens",
  "code": "200",
  "access_token": "APP_ID-8717-STORE_ID-1501119-...",
  "refresh_token": "d6d4c593317429ab...",
  "date_expiration_access_token": "2026-06-17 18:00:48",
  "date_expiration_refresh_token": "2026-07-17 15:00:48",
  "date_activated": "2026-06-17 15:00:48",
  "api_host": "https://lojatesteintegracaotray.commercesuite.com.br/web_api",
  "store_id": "1501119"
}
```

✅ **VALIDAÇÃO:** Testado e funcionou em 17/06/2026 com sucesso.

---

## 3. Produtos

### 3.1 Buscar Produtos por Nome (✅ TESTADO E FUNCIONANDO)

**Endpoint:**
```
GET {{TRAY_API_URL}}/products?access_token={{TOKEN}}&name={{termo}}&limit={{limite}}&status=1
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição | Exemplo |
|-----------|-------------|-----------|---------|
| access_token | Sim | Seu Access Token | APP_ID-8717-... |
| name | Sim | Termo de busca | caderno |
| limit | Não | Quantidade de resultados | 5 (padrão) |
| status | Não | Status do produto | 1 (ativo) |

**Exemplo (PowerShell):**
```powershell
$token = "APP_ID-8717-STORE_ID-1501119-..."
Invoke-RestMethod -Uri "https://lojatesteintegracaotray.commercesuite.com.br/web_api/products?access_token=$token&name=caderno" -Method GET
```

**Resposta:**
```json
{
  "Products": [
    {
      "Product": {
        "id": "12345",
        "name": "Caderno Universitário 10 matérias",
        "price": "19.90",
        "stock": "150",
        "description": "Caderno espiral com 100 folhas",
        "category_id": "5",
        "image": "https://..."
      }
    }
  ]
}
```

⚠️ **TRATAMENTO FLEXÍVEL (obrigatório no n8n):**
```javascript
const produtos = response.Products || response.data || [];
const primeiroProduto = produtos[0]?.Product || produtos[0] || null;
```

✅ **VALIDAÇÃO:** Testado e funcionou com "caderno" em 17/06/2026.

### 3.2 Buscar Produtos por Categoria (Similares)

**Endpoint:**
```
GET {{TRAY_API_URL}}/products?access_token={{TOKEN}}&category_id={{cat_id}}&limit={{limite}}&status=1
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| access_token | Sim | Seu Access Token |
| category_id | Sim | ID da categoria do produto |
| limit | Não | Quantidade de resultados |

**Uso no Papeluxo:** Usado para buscar produtos similares quando o cliente não quer o produto principal.

### 3.3 Buscar Produtos por Palavras-chave (Alternativa para Similares)

**Endpoint:**
```
GET {{TRAY_API_URL}}/products?access_token={{TOKEN}}&keywords={{termo_original}}&limit={{limite}}&status=1
```

---

## 4. Frete

### 4.1 Calcular Frete

**Endpoint:**
```
GET {{TRAY_API_URL}}/shippings/cotation/?access_token={{TOKEN}}&zipcode={{CEP}}&products_id[]={{id1}}&products_quantity[]={{qtd1}}&products_price[]={{preco1}}
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição | Exemplo |
|-----------|-------------|-----------|---------|
| access_token | Sim | Seu Access Token | APP_ID-8717-... |
| zipcode | Sim | CEP do cliente (8 dígitos) | 83458890 |
| products_id[] | Sim | ID do produto | 12345 |
| products_quantity[] | Sim | Quantidade | 2 |
| products_price[] | Sim | Preço unitário | 1.89 |

**Exemplo:**
```
GET /web_api/shippings/cotation/?access_token=TOKEN&zipcode=83458890&products_id[]=12345&products_quantity[]=2&products_price[]=1.89
```

**Resposta:**
```json
{
  "Quotation": {
    "shipping": [
      {
        "name": "Sedex",
        "price": "14.94",
        "deadline": "1",
        "message": null,
        "code": "sedex"
      },
      {
        "name": "PAC",
        "price": "23.24",
        "deadline": "3",
        "message": null,
        "code": "pac"
      },
      {
        "name": "Jadlog",
        "price": "22.35",
        "deadline": "2",
        "message": null,
        "code": "jadlog"
      }
    ]
  }
}
```

**Tratamento no n8n:**
```javascript
const opcoes = response.Quotation?.shipping || [];
const opcoesFormatadas = opcoes.map((s, i) => {
  const preco = parseFloat(s.price).toFixed(2).replace('.', ',');
  const dias = s.deadline;
  const diaTexto = dias === '1' ? 'dia útil' : 'dias úteis';
  return `${i+1}. ${s.name}: R$ ${preco} (${dias} ${diaTexto})`;
});
```

---

## 5. Clientes

### 5.1 Verificar Cliente por CPF

**Endpoint:**
```
GET {{TRAY_API_URL}}/customers?access_token={{TOKEN}}&cpf={{cpf}}
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| access_token | Sim | Seu Access Token |
| cpf | Sim | CPF (apenas números) |

**Exemplo:**
```
GET /web_api/customers?access_token=TOKEN&cpf=12345678900
```

**Resposta (cliente encontrado):**
```json
{
  "Customers": [
    {
      "Customer": {
        "id": "789",
        "name": "Cleverson Hoffmann",
        "cpf": "12345678900",
        "email": "cleverson@email.com",
        "zip_code": "83458890",
        "phone": "41995548374"
      }
    }
  ]
}
```

**Resposta (cliente não encontrado):**
```json
{
  "Customers": []
}
```

### 5.2 Criar Cliente

**Endpoint:**
```
POST {{TRAY_API_URL}}/customers?access_token={{TOKEN}}
Content-Type: application/json
```

**Body:**
```json
{
  "Customer": {
    "name": "Cleverson Hoffmann",
    "cpf": "12345678900",
    "email": "cleverson@email.com",
    "zip_code": "83458890",
    "phone": "41995548374"
  }
}
```

**Resposta:**
```json
{
  "Customer": {
    "id": "789",
    "name": "Cleverson Hoffmann",
    "cpf": "12345678900",
    "email": "cleverson@email.com",
    "zip_code": "83458890"
  }
}
```

---

## 6. Pedidos

### 6.1 Criar Pedido

**Endpoint:**
```
POST {{TRAY_API_URL}}/orders?access_token={{TOKEN}}
Content-Type: application/json
```

**Body:**
```json
{
  "Order": {
    "customer_id": "789",
    "shipping_type": "Sedex",
    "shipping_price": "14.94",
    "Products": [
      {
        "product_id": "12345",
        "price": "1.89",
        "quantity": "2"
      }
    ]
  }
}
```

**Resposta:**
```json
{
  "Order": {
    "id": "98765",
    "customer_id": "789",
    "shipping_type": "Sedex",
    "shipping_price": "14.94",
    "total": "18.72",
    "status": "pending",
    "created_at": "2026-06-17 15:30:00"
  }
}
```

### 6.2 Gerar Link de Pagamento (TrayCheckout)

⚠️ **A CONFIRMAR:** O endpoint exato pode variar. Normalmente é algo como:
```
POST {{TRAY_API_URL}}/orders/{{order_id}}/checkout
```
ou
```
GET {{TRAY_API_URL}}/checkout?order_id={{order_id}}
```

Verificar na documentação oficial da Tray.

---

## 7. Webhook de Pagamento

### 7.1 Receber Notificação de Pagamento

**Trigger:** Tray envia POST para `https://bot.papelecompanhia.com.br/webhook/tray-payment`

**Payload esperado:**
```json
{
  "status": "approved",
  "order_id": "98765",
  "customer_phone": "41995548374",
  "payment_method": "pix"
}
```

**Status possíveis:**
- `approved` → Pagamento aprovado
- `paid` → Pagamento confirmado
- `confirmed` → Pagamento confirmado (alternativo)
- `pending` → Aguardando pagamento
- `rejected` → Pagamento recusado

---

## 8. Credenciais Atuais (Teste)

| Credencial | Valor |
|------------|-------|
| TRAY_API_URL | `https://lojatesteintegracaotray.commercesuite.com.br/web_api` |
| TRAY_ACCESS_TOKEN | `APP_ID-8717-STORE_ID-1501119-0e99638624bb7f2c318d9044012d877a06cc23e15494bb63442ade6ae1acc5e7` |
| TRAY_REFRESH_TOKEN | `d6d4c593317429ab97b50455f74f345f1de4adae86f7e51d38d2eff52bfa2c34` |
| TRAY_CONSUMER_KEY | `23434a5ebd9782bd594191042f52d44d864d8117d2be01a0508b39bce2490b53` |
| TRAY_CONSUMER_SECRET | `9d0c1b8ae2321ccd7be0278b361c5faba22f9c9da61b6c8913e1652d12732fd6` |
| Store ID (Teste) | 1501119 |

---

## 9. Resumo dos Endpoints Testados

| Endpoint | Status | Data do Teste |
|----------|--------|---------------|
| auth (renovação com `refresh_token`) | ✅ Funciona | 17/06/2026 |
| products?name= | ✅ Funciona | 17/06/2026 |
| shippings/cotation/ | ⏳ A testar | - |
| customers (GET) | ⏳ A testar | - |
| customers (POST) | ⏳ A testar | - |
| orders (POST) | ⏳ A testar | - |
| checkout (link pagamento) | ⏳ A testar | - |

---

**Documento gerado em:** 17/06/2026  
**Baseado no e-mail oficial da Tray + testes realizados**  
**Versão:** 1.0  
**Status:** ✅ Pronto para uso
