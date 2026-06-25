# 🔧 PLANO DE CORREÇÃO — Papeluxo (para execução pela 4Cline)

**Data:** 19/06/2026
**Versão:** 2.0 — revisada após segunda opinião técnica (GPT)
**Objetivo:** Fazer o bot Papeluxo responder corretamente no WhatsApp, do recebimento da mensagem até a saudação inicial funcionando ponta a ponta — e depois expandir o fluxo completo de vendas.

**IMPORTANTE PARA A CLINE:** este documento corrige uma versão anterior. Os três problemas abaixo (parse do webhook, DNS/Postgres, workflow incompleto) são **independentes entre si** — não são causa e efeito uns dos outros. Resolva-os na ordem dada, mas não perca tempo tentando conectar um ao outro: são bugs separados que coincidem no tempo.

---

## ORDEM DE PRIORIDADE (e por quê)

1. **Webhook parse error** — bloqueia tudo; se o n8n não lê a mensagem, nada mais importa. Este é o gargalo real e tem prioridade absoluta.
2. **DNS do Postgres (`EAI_AGAIN`)** — problema real e paralelo, mas não é causa do erro de parse. Resolver porque compromete a estabilidade geral, não porque explica o sintoma principal.
3. **`host.docker.internal` em vez de `waha`** — correção de rede que reduz uma fonte adicional de instabilidade.
4. **Workflow incompleto** — só faz sentido expandir o fluxo depois que a mensagem "teste" simples gerar uma resposta real no WhatsApp.

---

## 🔴 PASSO 1 — Diagnosticar a causa real do "Failed to parse request body"

### Por que a abordagem mudou

A tentativa original de capturar o payload com um `Code` node dentro do n8n (logo após o Webhook) **não é confiável**: se o erro acontece no parser do Express/n8n antes mesmo do node Webhook materializar `$json`, o Code node pode nunca chegar a executar para essas requisições problemáticas. Precisamos capturar o request **fora do n8n**, sem nenhum parser no meio.

### 1.1 Subir um echo server temporário para capturar o request bruto

Adicione um serviço temporário no `docker-compose.yml` (ou rode via `docker run` avulso, sem precisar editar o compose):

```powershell
docker run -d --name webhook-debug --network papeluxo-network -p 8080:80 mendhak/http-https-echo
```

Esse container devolve exatamente os headers, o body bruto e o Content-Type recebidos, sem interpretar nada.

### 1.2 Apontar o WAHA temporariamente (ou em paralelo) para o echo server

Sem remover o webhook real, registre um segundo webhook na sessão do WAHA apontando para o echo:

```powershell
curl.exe -s http://localhost:3000/api/sessions/default -H "X-Api-Key: papelcia2024"
```

Confirme a estrutura atual de `config.webhooks`, depois faça PUT adicionando uma segunda entrada:

```powershell
curl.exe -s -X PUT http://localhost:3000/api/sessions/default -H "X-Api-Key: papelcia2024" -H "Content-Type: application/json" -d "{\"config\":{\"webhooks\":[{\"url\":\"http://n8n-main:5678/webhook/papelcia-webhook\",\"events\":[\"message\"],\"retries\":{\"policy\":\"constant\",\"delaySeconds\":2,\"attempts\":5}},{\"url\":\"http://webhook-debug:80\",\"events\":[\"message\",\"message.any\",\"message.ack\"],\"retries\":{\"policy\":\"constant\",\"delaySeconds\":2,\"attempts\":1}}]}}"
```

### 1.3 Mandar uma mensagem real e inspecionar a captura

Mande uma mensagem de teste no WhatsApp, depois:

```powershell
docker logs webhook-debug --tail 50
```

Isso vai mostrar, sem distorção:
- O `Content-Type` exato enviado pelo WAHA (com ou sem `charset`, etc.)
- O body bruto, byte a byte
- Se há diferença de formato entre o evento `message` e outros eventos (`message.any`, `message.ack`) que estejam batendo na mesma URL

### 1.4 Testar a hipótese de eventos múltiplos com formatos diferentes

Os logs originais do WAHA mostram múltiplos `Sending POST...` quase simultâneos para a mesma URL — sinal de que mais de um tipo de evento pode estar sendo disparado. Compare no echo server se o payload de `message` é sempre um JSON válido e completo, e se `message.ack` (ou outros) vêm com estrutura diferente ou corpo vazio.

Se confirmado que eventos diferentes do `message` estão causando o problema, restrinja o webhook real para emitir apenas o necessário:

```powershell
curl.exe -s -X PUT http://localhost:3000/api/sessions/default -H "X-Api-Key: papelcia2024" -H "Content-Type: application/json" -d "{\"config\":{\"webhooks\":[{\"url\":\"http://n8n-main:5678/webhook/papelcia-webhook\",\"events\":[\"message\"],\"retries\":{\"policy\":\"constant\",\"delaySeconds\":2,\"attempts\":5}}]}}"
```

### 1.5 Verificar se há path duplicado registrado no n8n

```powershell
curl.exe -s -H "X-N8N-API-KEY: SEU_TOKEN" http://localhost:5678/api/v1/workflows
```

Procure qualquer outro workflow (ativo ou não) com um node Webhook usando `path: papelcia-webhook`. Em modo `queue`, registros duplicados de path podem gerar comportamento inconsistente, já que o `n8n-main` é quem recebe e enfileira o webhook — os workers nunca recebem webhooks diretamente, então um path conflitante na camada de recepção pode se manifestar como erro de parse mesmo sem relação com os workers.

### 1.6 Remover o echo server de debug

Depois de identificada e corrigida a causa, remova o container temporário:

```powershell
docker rm -f webhook-debug
```

E reverta a configuração do WAHA para apenas o webhook real (já feito no passo 1.4 se aplicável).

### Critério de sucesso do Passo 1

Mande uma mensagem real no WhatsApp e confirme:
- `docker logs n8n-main --tail 10` **não mostra mais** `Failed to parse request body`
- O log mostra `Enqueued execution` seguido de `Execution ... finished` para essa mensagem
- `docker logs n8n-worker-1 --tail 20` e `docker logs n8n-worker-2 --tail 20` não mostram erro associado a essa execução

---

## 🟡 PASSO 2 — Resolver o DNS do Postgres (`EAI_AGAIN`)

Este é um problema **separado e paralelo** ao erro de parse — não é causa dele. `EAI_AGAIN` é uma falha de resolução de nome (`getaddrinfo`), não lentidão de conexão. Tratar isso como timeout (aumentando `connection timeout` ou `pool size`) ataca o sintoma errado.

### 2.1 Confirmar resolução de nome dentro da rede Docker

```powershell
docker exec n8n-main ping -n 4 postgres
docker exec n8n-main nslookup postgres
docker network inspect papeluxo-network
```

Se o `ping` falhar intermitentemente ou o `nslookup` não resolver de forma consistente, o problema é de fato DNS interno do Docker, não do Postgres em si.

### 2.2 Garantir hostname explícito no serviço Postgres

No `docker-compose.yml`, adicione `hostname` explícito ao serviço `postgres` (hoje só tem `container_name`, que nem sempre é suficiente para resolução DNS confiável dentro da rede):

```yaml
postgres:
  image: postgres:16
  container_name: postgres
  hostname: postgres
  restart: unless-stopped
  ...
```

### 2.3 Recriar os containers para aplicar a mudança

```powershell
docker compose up -d --force-recreate postgres
docker compose up -d --force-recreate n8n-main n8n-worker-1 n8n-worker-2
```

### 2.4 Não aplicar mitigação de timeout/pool

**Não adicione** `DB_POSTGRESDB_CONNECTION_TIMEOUT` ou `DB_POSTGRESDB_POOL_SIZE` como tentativa de correção — isso mascara o sintoma sem resolver a causa, e pode inclusive atrasar a detecção de que o DNS continua falhando.

### Critério de sucesso do Passo 2

Rode `docker exec n8n-main ping -n 20 postgres` e confirme 0% de perda de pacote. Depois, use o bot por 10-15 minutos trocando mensagens e confirme que `docker logs n8n-main --tail 100` não mostra mais `EAI_AGAIN` nem `Database connection timed out`.

---

## 🟢 PASSO 3 — Corrigir a rota de rede para o WAHA

O node `HTTP Request - Enviar WhatsApp` está configurado com:
```
http://host.docker.internal:3000/api/sendText
```

Isso é desnecessário e é uma fonte adicional de instabilidade: `waha` já está na mesma rede Docker (`papeluxo-network`) que `n8n-main`. Usar `host.docker.internal` faz a requisição sair do container, passar pelo host Windows (via mecanismo especial do Docker Desktop), e voltar — mais lento e mais uma camada que pode falhar.

### 3.1 Corrigir a URL no workflow

No node `HTTP Request - Enviar WhatsApp` (e em qualquer outro node que chame o WAHA, incluindo os que serão criados no Passo 4), troque:

```
http://host.docker.internal:3000/api/sendText
```

por:

```
http://waha:3000/api/sendText
```

Isso pode ser feito via API (PUT no workflow) ou diretamente no editor visual do n8n.

### Critério de sucesso do Passo 3

Envie a mensagem de teste e confirme nos logs do WAHA (`docker logs waha --tail 10`) que a chamada `sendText` chega e responde normalmente, e que o tempo de resposta entre o `Enqueued execution` (n8n) e o envio da mensagem no WhatsApp está visivelmente mais rápido/consistente que antes.

---

## 🔵 PASSO 4 — Completar o workflow principal (fluxo de vendas)

**Só inicie este passo depois que uma mensagem real gerar a saudação inicial corretamente no WhatsApp, de forma estável, com os Passos 1-3 confirmados.**

Atualmente o `Switch - Etapas da Conversa` só tem **uma saída conectada** (para "Saudação Inicial"). Isso significa que depois da primeira mensagem, **qualquer mensagem seguinte do cliente não tem para onde ir** — o bot vai travar silenciosamente (sem erro, sem resposta) a partir da segunda interação. Este problema é real e vai se manifestar assim que os Passos 1-3 estiverem resolvidos, mas não é a causa do erro de parse atual.

### 4.1 Estrutura do Switch que precisa existir

O node `Switch - Etapas da Conversa` deve ter uma saída para cada valor de `sessao.etapa`, usando a expressão:
```
={{ $json.sessao.etapa }}
```
com as seguintes rotas (rules), na ordem da especificação original do projeto:

| Valor de `etapa` | Saída do Switch deve ir para |
|---|---|
| `inicio` | Code - Saudação Inicial *(já existe)* |
| `aguardando_produto` | Code - Classificar Intenção → HTTP Gemini → HTTP Tray Buscar Produto |
| `produto_encontrado` | Code - Processar Confirmação/Similar |
| `aguardando_quantidade` | Code - Processar Quantidade |
| `carrinho_ativo` | Code - Processar Mais Produtos ou Ir para Frete |
| `aguardando_cep` | HTTP ViaCEP → HTTP Tray Cotação Frete |
| `aguardando_frete` | Code - Processar Escolha de Frete |
| `aguardando_nome` | Code - Validar Nome |
| `aguardando_cpf` | Code - Validar CPF |
| `aguardando_email` | Code - Validar Email → Code - Criar Pedido |
| `confirmando_pedido` | HTTP Tray Customer → HTTP Tray Order → HTTP Pagamento |
| `pagamento_pendente` | Code - Mensagem "Aguardando pagamento" |
| `transferindo_humano` | Code - Fluxo Transferência Humano |

**Cada ramo termina em um node "HTTP Request - Enviar WhatsApp" (reaproveite o já existente, já corrigido no Passo 3 para usar `http://waha:3000`) seguido de "Redis SET - Sessão".**

### 4.2 Abordagem recomendada de implementação

Não tente criar tudo de uma vez no editor visual do n8n manualmente — é o caminho mais lento e propenso a erro de digitação em expressões. Em vez disso:

1. Exporte o workflow atual via API (`GET /api/v1/workflows/papeluxo-workflow-principal`).
2. Edite o JSON diretamente, adicionando os nodes e conexões faltantes em lote, usando como referência os blocos de código já especificados no documento técnico original do projeto (`DOCUMENTO FINAL — PAPELUXO v6.0`, seções 11.3 a 11.10), que já contêm o JavaScript pronto para cada etapa (Code - Confirmar Carrinho, Code - Quantidade, Code - CEP/Frete, Code - Nome/CPF/Email, Code - Criar Pedido, Code - Transferência Humano).
3. Faça o PUT do workflow completo de uma vez.
4. Desative e reative o workflow para garantir que os webhooks/triggers sejam re-registrados.

### 4.3 Implementar incrementalmente, testando cada etapa

Não implemente as 13 etapas de uma vez sem testar. Ordem sugerida de implementação e teste manual (simulando respostas do cliente via o mesmo método Python/urllib usado no Passo 1, trocando `body` e o `etapa` salvo no Redis a cada teste):

1. `aguardando_produto` → testar buscar um produto real na Tray (ex: "caneta bic") e confirmar que retorna preço/estoque corretos.
2. `produto_encontrado` → testar resposta "sim" e "não".
3. `aguardando_quantidade` → testar número de unidades.
4. `carrinho_ativo` → testar "sim" (mais produtos) e "não" (ir para frete).
5. `aguardando_cep` → testar CEP válido e inválido.
6. `aguardando_frete` → testar escolha de opção.
7. `aguardando_nome` / `aguardando_cpf` / `aguardando_email` → testar coleta sequencial.
8. `confirmando_pedido` → testar criação de cliente/pedido na Tray (ambiente de testes, Store ID 1501119).
9. `transferindo_humano` → testar transferência com resumo da conversa.

Para cada etapa testada com sucesso, reporte antes de seguir para a próxima.

### 4.4 Nós de tratamento de erro (adicionar em paralelo, não no final)

Conforme a especificação original (seção 14), todo node HTTP Request que chama Tray, ViaCEP ou Gemini deve ter:
```
Timeout: 30000
On Error: Continue on Fail
Retry On Fail: true
Max Tries: 3
```
E logo após cada um, um `IF` checando se houve erro, incrementando `sessao.erros_consecutivos` e transferindo para humano se `>= 2-3` erros. Implemente isso **junto** com cada etapa do passo 4.3, não como uma fase separada no final — assim cada etapa já nasce robusta.

---

## ✅ CHECKLIST FINAL DE VALIDAÇÃO

Antes de considerar o projeto "funcionando", confirme:

- [ ] Mensagem real no WhatsApp gera resposta do bot em menos de 10 segundos
- [ ] `docker logs n8n-main` não mostra mais `Failed to parse request body`
- [ ] `docker exec n8n-main ping postgres` não mostra mais falha de resolução (`EAI_AGAIN`)
- [ ] Node de envio ao WAHA usa `http://waha:3000`, não `http://host.docker.internal:3000`
- [ ] Conversa completa testada manualmente: produto → quantidade → mais produtos → CEP → frete → nome → CPF → email → pedido criado → link de pagamento recebido
- [ ] Mensagem de "não entendi" aparece corretamente após 2 falhas de classificação de intenção
- [ ] Transferência para humano envia resumo correto para o número do atendente (5541999616806@c.us)
- [ ] `fromMe === true` continua sendo filtrado (testar enviando mensagem do próprio número conectado, bot não deve responder a si mesmo)
- [ ] Workflow de renovação de token Tray rodando a cada 2h30 sem erro
- [ ] Workflow de confirmação de pagamento testado com payload simulado da Tray
- [ ] Container `webhook-debug` removido após uso (não deixar rodando em produção)

---

## 📌 Observação sobre o ambiente

Lembre-se: o n8n roda em **modo `queue`** com Redis + 2 workers (`n8n-worker-1`, `n8n-worker-2`). O `n8n-main` é o único que recebe webhooks; os workers só processam execuções já enfileiradas. Isso significa que:

- Erros de **parse do request HTTP** (como o problema atual) só podem aparecer nos logs do `n8n-main`, nunca nos workers — por isso a captura externa via echo server é o caminho certo para esse tipo de erro.
- Erros de **execução do workflow** (depois que o webhook já respondeu 200 e a mensagem foi enfileirada) aparecem nos logs dos **workers**, não no `n8n-main`. Ao depurar etapas do fluxo de vendas (Passo 4), sempre cheque:
```powershell
docker logs n8n-worker-1 --tail 50
docker logs n8n-worker-2 --tail 50
```
