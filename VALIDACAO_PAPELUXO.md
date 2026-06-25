# 📋 Documento de Validação — Papeluxo

**Data:** 24/06/2026  
**Versão:** 1.1  
**Objetivo:** Registrar erros e acertos para evitar retrabalho

---

## ✅ VALIDADO (Absoluta Certeza)

| # | Componente | Detalhes | Data |
|---|-----------|----------|------|
| 1 | `docker-compose.yml` | `N8N_ENCRYPTION_KEY=papeluxo2026encryptionkey32chars` em main + 2 workers | 24/06 |
| 2 | `docker-compose.yml` | `hostname: postgres` explícito | 24/06 |
| 3 | `.env` | Tokens Tray 17/06/2026 (access `0e996386...`, refresh `d6d4c593...`) | 24/06 |
| 4 | `.env` | WAHA_API_KEY=`papelcia2024`, Gemini=`AIzaSyBZLX...`, Consumer Key/Secret | 24/06 |
| 5 | `workflows/token.json` | Parâmetro `refresh_token` (não `code`) na renovação Tray | 24/06 |
| 6 | `workflows/pagamento.json` | 100% completo, já funcionou em produção | 24/06 |
| 7 | `workflows/principal.json` | JSON 100% válido, 27 nós, sem placeholders, sem comentários | 24/06 |
| 8 | Infraestrutura | 7 containers sobem corretamente (postgres, redis, waha, n8n-main, worker1, worker2, traefik) | 24/06 |
| 9 | WAHA Sessão | Criada com webhook `http://n8n-main:5678/webhook/papelcia-webhook` | 24/06 |
| 10 | Tokens Redis | `tray_access_token` + `tray_refresh_token` inicializados | 24/06 |
| 11 | Workflow Principal | Webhook registrado, execuções enfileiradas e concluídas | 24/06 |
| 12 | n8n encryption key | Sem erro de "mismatching" após limpeza do volume n8n-data | 24/06 |
| 13 | Credential Redis | `kUMv0GjlL2OOV0jf` importada com `data` JSON válido no PostgreSQL | 24/06 20:24 |

---

## ❌ ERROS ENCONTRADOS E CORRIGIDOS

| # | Erro | Causa | Correção | Data |
|---|------|-------|----------|------|
| 1 | `unknown webhook` | Workflow não ativado / n8n não reiniciado | `publish:workflow --active=true` + `docker restart n8n-main` | 24/06 |
| 2 | `Mismatching encryption keys` | `n8n-data` do pendrive com chave antiga | Limpeza total dos volumes | 24/06 |
| 3 | `Credential does not exist` | Credential Redis não importada | Importar com ID `kUMv0GjlL2OOV0jf` | 24/06 |
| 4 | WAHA sessão STOPPED sem webhook | Sessão reiniciada sem configuração | Recriar com `POST /api/sessions/` + `config.webhooks` | 24/06 |
| 5 | `Unexpected end of JSON input` no Redis | Credential criptografada com chave antiga (antes da N8N_ENCRYPTION_KEY) | DELETAR credential via SQL + recriar com `import:credentials` | 24/06 20:24 |
| 6 | `null value in column "data"` ao importar credential | Campo `data` como objeto `{}` em vez de string `"{}"` | Formatar `data` como string JSON escapada | 24/06 |

---

## 🔧 EM CORREÇÃO

| # | Item | Problema | Próximo Passo |
|---|------|----------|---------------|
| 1 | WAHA sendText formato | n8n HTTP Request pode estar enviando body errado | Testar formato do body enviado ao WAHA |

---

## 📝 REGRAS APRENDIDAS

1. **SEMPRE** limpar `n8n-data` ao mudar `N8N_ENCRYPTION_KEY`
2. **SEMPRE** usar `publish:workflow --active=true` + reiniciar n8n
3. **NUNCA** usar comentários em JSON
4. **NUNCA** usar placeholders `COLOQUE_SUA_*` — substituir ANTES de importar
5. **Credential Redis** no n8n import: campo `data` deve ser STRING JSON escapada, não objeto
6. **WAHA webhook** precisa ser configurado ao CRIAR a sessão, não depois
7. **Tokens Tray** precisam ser inicializados no Redis após `docker compose up -d`
8. **Workers** precisam da mesma `N8N_ENCRYPTION_KEY` que o `n8n-main`
9. **Credential criptografada com chave antiga** causa `JSON.parse` falhar — deletar via SQL e recriar