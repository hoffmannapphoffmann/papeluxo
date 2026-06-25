<#
.SYNOPSIS
    Script de configuração inicial do Papeluxo - Assistente de Vendas WhatsApp
.DESCRIPTION
    Este script automatiza a configuração inicial do ambiente Docker para o Papeluxo
.NOTES
    Versão: 1.0
    Data: 28/05/2026
    Autor: Papel & Cia
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PAPELUXO - Configuração Inicial" -ForegroundColor Cyan
Write-Host "  Assistente de Vendas WhatsApp" -ForegroundColor Cyan
Write-Host "  Papel & Cia" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# PASSO 1: Verificar Docker
# ============================================
Write-Host "[1/8] Verificando Docker..." -ForegroundColor Yellow

$dockerVersion = docker --version 2>$null
if (-not $dockerVersion) {
    Write-Host "  ❌ Docker não encontrado!" -ForegroundColor Red
    Write-Host "  Por favor, instale o Docker Desktop em: https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Docker encontrado: $dockerVersion" -ForegroundColor Green

# ============================================
# PASSO 2: Verificar Docker Compose
# ============================================
Write-Host "[2/8] Verificando Docker Compose..." -ForegroundColor Yellow

$composeVersion = docker compose version 2>$null
if (-not $composeVersion) {
    Write-Host "  ❌ Docker Compose não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Docker Compose encontrado: $composeVersion" -ForegroundColor Green

# ============================================
# PASSO 3: Verificar arquivos necessários
# ============================================
Write-Host "[3/8] Verificando arquivos de configuração..." -ForegroundColor Yellow

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

$requiredFiles = @(
    "docker-compose.yml",
    ".env"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $projectRoot $file
    if (-not (Test-Path $filePath)) {
        $missingFiles += $file
        Write-Host "  ❌ Arquivo ausente: $file" -ForegroundColor Red
    } else {
        Write-Host "  ✅ Arquivo encontrado: $file" -ForegroundColor Green
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "  ❌ Arquivos ausentes detectados. Crie-os antes de continuar." -ForegroundColor Red
    exit 1
}

# ============================================
# PASSO 4: Criar diretórios de dados
# ============================================
Write-Host "[4/8] Criando diretórios de dados persistentes..." -ForegroundColor Yellow

$dataDirs = @(
    "postgres-data",
    "redis-data",
    "waha-sessions",
    "n8n-data",
    "traefik-data",
    "workflows"
)

foreach ($dir in $dataDirs) {
    $dirPath = Join-Path $projectRoot $dir
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Host "  ✅ Diretório criado: $dir" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Diretório já existe: $dir" -ForegroundColor Green
    }
}

# ============================================
# PASSO 5: Subir containers
# ============================================
Write-Host "[5/8] Subindo containers Docker..." -ForegroundColor Yellow
Write-Host "  Isso pode levar alguns minutos na primeira execução..." -ForegroundColor Gray

Set-Location $projectRoot
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Erro ao subir containers!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Containers iniciados com sucesso!" -ForegroundColor Green

# ============================================
# PASSO 6: Aguardar healthchecks
# ============================================
Write-Host "[6/8] Aguardando containers ficarem saudáveis..." -ForegroundColor Yellow

$services = @("postgres", "redis", "waha", "n8n-main")
foreach ($service in $services) {
    Write-Host "  Aguardando $service..." -NoNewline -ForegroundColor Gray
    $maxAttempts = 30
    $attempt = 0
    $healthy = $false
    
    while ($attempt -lt $maxAttempts -and -not $healthy) {
        $status = docker inspect --format='{{.State.Health.Status}}' $service 2>$null
        if ($status -eq "healthy") {
            $healthy = $true
        } else {
            Start-Sleep -Seconds 2
            $attempt++
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
    
    if ($healthy) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ⚠️  Timeout - verifique manualmente" -ForegroundColor Yellow
    }
}

# ============================================
# PASSO 7: Configurar Webhook no WAHA
# ============================================
Write-Host "[7/8] Configurando webhook no WAHA..." -ForegroundColor Yellow

$webhookBody = @{
    name = "default"
    config = @{
        webhooks = @(
            @{
                url = "http://n8n-main:5678/webhook/papelcia-webhook"
                events = @("message", "session.status")
            }
        )
    }
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/sessions/" `
        -Method Post `
        -Headers @{
            "X-Api-Key" = "COLOQUE_SUA_WAHA_API_KEY"
            "Content-Type" = "application/json"
        } `
        -Body $webhookBody `
        -ErrorAction Stop
    
    Write-Host "  ✅ Webhook configurado com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Não foi possível configurar webhook automaticamente." -ForegroundColor Yellow
    Write-Host "  Configure manualmente via curl ou dashboard do WAHA." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Comando manual:" -ForegroundColor Gray
    Write-Host '  curl -X POST http://localhost:3000/api/sessions/ \' -ForegroundColor Gray
    Write-Host '    -H "X-Api-Key: COLOQUE_SUA_WAHA_API_KEY" \' -ForegroundColor Gray
    Write-Host '    -H "Content-Type: application/json" \' -ForegroundColor Gray
    Write-Host '    -d "{`"name`":`"default`",`"config`":{`"webhooks`":[{`"url`":`"http://n8n-main:5678/webhook/papelcia-webhook`",`"events`":[`"message`",`"session.status`"]}]}}"' -ForegroundColor Gray
}

# ============================================
# PASSO 8: Inicializar Tokens no Redis
# ============================================
Write-Host "[8/8] Inicializando tokens no Redis..." -ForegroundColor Yellow

try {
    docker exec redis redis-cli SET tray_access_token "COLOQUE_SEU_TRAY_ACCESS_TOKEN" 2>$null
    docker exec redis redis-cli SET tray_refresh_token "COLOQUE_SEU_TRAY_REFRESH_TOKEN" 2>$null
    Write-Host "  ✅ Tokens inicializados no Redis!" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Não foi possível inicializar tokens no Redis." -ForegroundColor Yellow
    Write-Host "  Execute manualmente:" -ForegroundColor Yellow
    Write-Host '  docker exec redis redis-cli SET tray_access_token "SEU_TOKEN"' -ForegroundColor Gray
    Write-Host '  docker exec redis redis-cli SET tray_refresh_token "SEU_REFRESH"' -ForegroundColor Gray
}

# ============================================
# RESUMO FINAL
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ CONFIGURAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Acesse os serviços:" -ForegroundColor White
Write-Host "  📊 WAHA Dashboard: http://localhost:3000/dashboard" -ForegroundColor Cyan
Write-Host "  🔧 n8n Editor:     http://localhost:5678" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Credenciais padrão:" -ForegroundColor White
Write-Host "  Usuário: admin" -ForegroundColor Gray
Write-Host "  Senha:   COLOQUE_SUA_WAHA_API_KEY" -ForegroundColor Gray
Write-Host ""
Write-Host "  Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Acesse o WAHA Dashboard e escaneie o QR Code" -ForegroundColor Yellow
Write-Host "  2. Acesse o n8n e importe os workflows da pasta ./workflows/" -ForegroundColor Yellow
Write-Host "  3. Ative os workflows no n8n" -ForegroundColor Yellow
Write-Host "  4. Envie uma mensagem de teste para o WhatsApp" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Para ver os logs:" -ForegroundColor Gray
Write-Host "  docker compose logs -f" -ForegroundColor Gray
Write-Host ""
Write-Host "  Para parar os serviços:" -ForegroundColor Gray
Write-Host "  docker compose down" -ForegroundColor Gray
Write-Host ""
