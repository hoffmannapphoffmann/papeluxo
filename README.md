# Papeluxo 🤖✏️

**Assistente de Vendas WhatsApp da Papel & Cia**

Robô automático de vendas para WhatsApp que atende 24h, consulta produtos na Tray, calcula frete, cria pedidos e gera links de pagamento.

---

## 🚀 Tecnologias

| Componente | Tecnologia |
|------------|------------|
| WhatsApp Gateway | WAHA (devlikeapro/waha) |
| Automação | n8n |
| Banco de Dados | PostgreSQL 16 |
| Cache / Fila | Redis 7 |
| Proxy / SSL | Traefik v3 |
| IA | Google Gemini 2.5-flash |
| Loja | Tray Commerce API |

---

## 📋 Pré-requisitos

- Docker Desktop (Windows) ou Docker Engine (Linux)
- Acesso ao WhatsApp do número comercial
- Git (opcional)

---

## 🛠️ Configuração Rápida

### 1. Clone o repositório

```bash
git clone <seu-repo>
cd Papeluxo
```

### 2. Configure o ambiente

```bash
cp .env.example .env
# Edite o .env com suas credenciais reais
```

### 3. Suba os containers

```bash
docker compose up -d
```

### 4. Verifique se está tudo rodando

```bash
docker ps
# Deve mostrar: waha, n8n-main, n8n-worker-1, n8n-worker-2, postgres, redis, traefik
```

### 5. Configure o webhook no WAHA

```bash
curl -X POST http://localhost:3000/api/sessions/ \
  -H "X-Api-Key: SUA_WAHA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "default",
    "config": {
      "webhooks": [{
        "url": "http://n8n-main:5678/webhook/papelcia-webhook",
        "events": ["message", "session.status"]
      }]
    }
  }'
```

> ⚠️ O webhook é configurado via `POST /api/sessions/` — não existe endpoint `/webhooks` separado.

### 6. Escaneie o QR Code

Acesse: http://localhost:3000/dashboard  
Usuário/Senha: conforme seu `.env`  
Clique na sessão `default` e escaneie o QR code com o WhatsApp.

### 7. Importe os workflows no n8n

Acesse: http://localhost:5678  
Usuário/Senha: conforme seu `.env`

Para **cada** workflow (`workflows/*.json`):

1. **Settings → Import from JSON** → Cole o conteúdo do arquivo
2. **Substitua** os placeholders `COLOQUE_SUA_..._AQUI` pelos valores reais
3. **Associe** a credencial Redis (crie uma nova se necessário)
4. **Salve** e **ative** (botão "Active" no canto superior direito)

> ⚠️ O n8n Community Edition **não suporta** `{{ $env.VARIAVEL }}`. Substitua manualmente.

### 8. Inicialize os tokens no Redis

```bash
docker exec -it redis redis-cli SET tray_access_token "SEU_TOKEN_TRAY"
docker exec -it redis redis-cli SET tray_refresh_token "SEU_REFRESH_TRAY"
```

---

## 📁 Estrutura do Projeto

```
Papeluxo/
├── docker-compose.yml          # Configuração Docker completa
├── .env                        # Credenciais (NÃO versionar - no .gitignore)
├── .env.example                # Modelo de credenciais
├── .gitignore
├── README.md                   # Este arquivo
├── DOCUMENTO_FINAL_PAPELUXO_v6.0.md  # Documentação técnica completa
├── workflows/
│   ├── principal.json          # Workflow Principal (importar no n8n)
│   ├── token.json              # Renovação de Token Tray
│   └── pagamento.json          # Confirmação de Pagamento
├── scripts/
│   └── setup.ps1               # Setup automatizado (PowerShell)
└── docs/
    └── tray-api.md             # Documentação da API Tray
```

---

## 🔄 Workflows

### 1. Workflow Principal

**Nome:** `Papeluxo - Workflow Principal`  
**Trigger:** Webhook `POST /webhook/papelcia-webhook` (WAHA envia mensagens)

**Fluxo:**
- Recebe mensagem → Retorna 200 OK imediato
- Filtra `fromMe === true` (evita loop)
- Filtra mensagens que não são texto
- Lê/cria sessão no Redis
- Switch por etapa → Saudação / Busca Produto / Carrinho / Frete / Dados / Pedido
- Cada etapa gera resposta via Gemini + WAHA
- Atualiza sessão no Redis

### 2. Renovação de Token

**Nome:** `Papeluxo - Renovar Token Tray`  
**Trigger:** Schedule (a cada 2h30)

**Fluxo:**
- Lê refresh_token do Redis
- Chama Tray Auth API (parâmetro `code`)
- Atualiza access_token (expira em 2.5h) e refresh_token no Redis

### 3. Confirmação de Pagamento

**Nome:** `Papeluxo - Confirmar Pagamento`  
**Trigger:** Webhook `POST /webhook/tray-payment`

**Fluxo:**
- Recebe webhook → Retorna 200 OK imediato
- Verifica status (approved/paid/confirmed)
- Envia mensagem de confirmação ao cliente via WAHA
- Atualiza sessão no Redis como `etapa: finalizado`

---

## ⚠️ Antes de Importar os Workflows

Cada workflow contém placeholders que você **precisa substituir** manualmente no n8n:

| Placeholder | Onde encontrar |
|-------------|----------------|
| `COLOQUE_SUA_WAHA_API_KEY_AQUI` | Seu `.env` → `WAHA_API_KEY` |
| `COLOQUE_SUA_TRAY_API_URL_AQUI` | Seu `.env` → `TRAY_API_URL` |
| `COLOQUE_SUA_CONSUMER_KEY_AQUI` | Seu `.env` → `TRAY_CONSUMER_KEY` |
| `COLOQUE_SUA_CONSUMER_SECRET_AQUI` | Seu `.env` → `TRAY_CONSUMER_SECRET` |

---

## 🧪 Teste Rápido

Após configurar tudo, envie uma mensagem para o WhatsApp conectado:

- "Olá" → Deve responder com saudação
- "Quero uma caneta" → Deve buscar na Tray
- "Meu CEP é 83458890" → Deve calcular frete

---

## 🔒 Segurança ao Configurar

### 1. Copie o arquivo de ambiente
```bash
cp .env.example .env
```
Preencha **todas** as credenciais com valores reais no `.env` (este arquivo NUNCA é versionado — já está no `.gitignore`).

### 2. Importe os workflows e substitua os placeholders
Os arquivos em `workflows/*.json` contém placeholders **propositadamente** (`COLOQUE_SUA_..._AQUI`). Após importar cada workflow no n8n:
- Acesse http://localhost:5678
- Para cada workflow: identifique os placeholders e **substitua dentro do n8n** (painel visual) pelos valores do seu `.env`
- **NUNCA** substitua os placeholders diretamente nos arquivos `.json` antes de commitar

### 3. Tokens e chaves — onde cada um mora
| Segredo | Onde vive | Como o n8n lê |
|---------|-----------|----------------|
| Gemini API Key | `.env` | Placeholder no workflow → preencher manualmente no n8n |
| WAHA API Key | `.env` | Placeholder `COLOQUE_SUA_WAHA_API_KEY_AQUI` → preencher no n8n |
| Tray Consumer Key/Secret | `.env` | Placeholders no token.json → preencher no n8n |
| Tray Access/Refresh Token | **Redis** | Workflow de token renova a cada 2h30 e salva no Redis; workflow principal lê do Redis via node `Redis GET` |

### 4. Verificação automática de segredos
Antes de qualquer commit, rode:
```bash
bash scripts/check-secrets.sh
```
Ou instale o hook de pre-commit (uma vez por clone):
```bash
ln -sf ../../scripts/check-secrets.sh .git/hooks/pre-commit
```
O hook bloqueia automaticamente commits que contenham chaves, tokens ou senhas reais.

## 🔒 Segurança

- **NUNCA** versionar o arquivo `.env` (já está no `.gitignore`)
- Trocar **todas as senhas** antes de ir para produção
- Usar senhas fortes (32+ caracteres) para n8n e WAHA
- As credenciais Tray e Gemini de teste devem ser substituídas em produção

---

## 📚 Documentação

- [Documento Completo do Projeto (v6.0)](DOCUMENTO_FINAL_PAPELUXO_v6.0.md)
- [Documentação da API Tray](docs/tray-api.md)

---

## 📄 Licença

Proprietário — Papel & Cia
