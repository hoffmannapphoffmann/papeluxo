# Método de Trabalho — Cline (Preenchido para a Claude)

- **Projeto:** Papeluxo — Assistente de Vendas WhatsApp da Papel & Cia
- **Stack / tecnologias:** WAHA (devlikeapro/waha:latest) + n8n (n8nio/n8n:latest) + Redis 7 + PostgreSQL 16 + Google Gemini 2.5-flash + Tray Commerce API + Docker
- **Onde está hospedado / armazenado dados (não pode mudar sem aprovação):** Windows local, `C:\Projetos\Papeluxo`, 7 containers Docker (postgres, redis, waha, n8n-main, n8n-worker-1, n8n-worker-2, traefik)
- **Objetivo desta etapa:** Corrigir o erro `Unexpected end of JSON input` na credential Redis do n8n para que o workflow principal execute e o Papeluxo responda mensagens no WhatsApp

---

## Estado Atual do Projeto (24/06/2026 - 20h16)

### Infraestrutura

| Componente | Status | Detalhes |
|-----------|--------|----------|
| 7 containers Docker | ✅ Rodando | postgres, redis, waha, n8n-main, n8n-worker-1, n8n-worker-2, traefik |
| docker-compose.yml | ✅ Corrigido | `N8N_ENCRYPTION_KEY` nos 3 containers n8n, `hostname: postgres` |
| .env | ✅ Atualizado | Tokens Tray 17/06/2026, Gemini, WAHA, credenciais |
| WAHA | ✅ Sessão ativa | `default`, status `SCAN_QR_CODE`, webhook `http://n8n-main:5678/webhook/papelcia-webhook` |
| Tokens Redis | ✅ Inicializados | `tray_access_token` = `0e996386...`, `tray_refresh_token` = `d6d4c593...` |
| n8n Workflows | ✅ 3 ativos | `CGYZXJ2uorMZO2lz` (Pagamento), `jpiARLRdMdcez9XI` (Principal), `kzbPBdNVTiUvJqDn` (Token) |

### Arquivos Corrigidos (prontos para usar)

| Arquivo | Status |
|---------|--------|
| `docker-compose.yml` | ✅ Com encryption key |
| `.env` | ✅ Tokens válidos |
| `workflows/principal.json` | ✅ 27 nós, JSON válido, sem placeholders |
| `workflows/token.json` | ✅ `refresh_token` corrigido |
| `workflows/pagamento.json` | ✅ Completo |
| `redis-creds-fixed.json` | ✅ Credential Redis com ID `kUMv0GjlL2OOV0jf` |
| `test-webhook.json` | ✅ Payload de teste |
| `VALIDACAO_PAPELUXO.md` | ✅ Documento de erros/acertos |

---

## Erro Atual (a corrigir nesta etapa)

**Sintoma:** Webhook recebido, workflow executa, mas falha no nó Redis com:

```
SyntaxError: Unexpected end of JSON input
    at JSON.parse (<anonymous>)
    at Credentials.getData (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@.../credentials.ts:62:22)
    at CredentialsHelper.getDecrypted
    at Redis.node.ts:550:23
Worker finished execution 1 (job 1)
```

**Causa:** A credential Redis (`kUMv0GjlL2OOV0jf`) foi importada com o campo `data` corrompido ou vazio. O export mostra o campo com escapes válidos (`"data":"{\"host\":\"redis\",\"port\":6379}"`), mas ao tentar reimportar o mesmo JSON exportado, dá erro `null value in column "data"`.

**Comandos já tentados:**
```powershell
# Export mostra a credential OK
docker exec n8n-main n8n export:credentials --all --output=/tmp/creds-check.json
# Retorna: [{"id":"kUMv0GjlL2OOV0jf","name":"redis","data":"{\"host\":\"redis\",\"port\":6379}",...}]

# Mas a credential não funciona no worker - JSON.parse falha
```

---

## Plano de Ação (Primeiro Passo Proposto)

**Corrigir diretamente no PostgreSQL o campo `data` da credential**, depois testar:

1. Conectar ao PostgreSQL: `docker exec postgres psql -U n8n -d n8n`
2. Verificar o valor atual: `SELECT id, data FROM credentials_entity WHERE id = 'kUMv0GjlL2OOV0jf';`
3. Se estiver vazio ou `NULL`: `UPDATE credentials_entity SET data = '{"host":"redis","port":6379}' WHERE id = 'kUMv0GjlL2OOV0jf';`
4. Testar webhook: `POST http://localhost:5678/webhook/papelcia-webhook` com o payload do `test-webhook.json`
5. Verificar logs: `docker logs n8n-worker-1 --tail 20` — o erro `Unexpected end of JSON input` deve desaparecer

**Acesso n8n:** `hoffmann.app.hoffmann@gmail.com` / `Apquck1988*`
**WAHA API Key:** `papelcia2024`

---

## Lições Aprendidas (já corrigidas)

| Problema | Solução |
|----------|---------|
| `Mismatching encryption keys` | Limpar `n8n-data` ao mudar `N8N_ENCRYPTION_KEY` |
| `Unknown webhook` | Usar `publish:workflow --active=true` + reiniciar n8n |
| Placeholders `COLOQUE_SUA_*` | Substituir ANTES de importar |
| WAHA sessão parada sem webhook | Configurar na criação da sessão |