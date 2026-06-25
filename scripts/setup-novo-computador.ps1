# ============================================
# Papeluxo - Setup Completo (Novo Computador)
# ============================================
# Uso: powershell -ExecutionPolicy Bypass -File scripts\setup-novo-computador.ps1
# Requer: Docker Desktop, VSCode, Git
# ============================================
# Este script configura TODO o ambiente do Papeluxo
# em um computador novo, incluindo:
#   ✓ Docker + containers
#   ✓ n8n + workflows
#   ✓ WAHA + webhook + QR Code
#   ✓ Redis + tokens Tray
# ============================================

param(
    [string]$RepoUrl = "",
    [string]$Branch = "main",
    [switch]$SkipClone = $false,
    [switch]$SkipDocker = $false,
    [switch]$OpenBrowser = $true
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "🚀 Papeluxo - Setup"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        🚀 PAPELUXO - SETUP COMPLETO              ║" -ForegroundColor Cyan
Write-Host "║   Assistente de Vendas WhatsApp da Papel & Cia   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================
# PASSO 0 - Verificar Pré-requisitos
# ============================================
Write-Host "`n[0/9] Verificando pré-requisitos..." -ForegroundColor Yellow

# Docker Desktop
try {
    $dockerVer = docker --version 2>$null
    if ($dockerVer) {
        Write-Host "  ✅ Docker: $dockerVer" -ForegroundColor Green
    } else {
        throw "Docker não encontrado"
    }
} catch {
    Write-Host "  ❌ Docker Desktop não está instalado!" -ForegroundColor Red
    Write-Host "     Instale em: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
    Write-Host "     Depois execute este script novamente." -ForegroundColor White
    exit 1
}

# Git
$gitAvailable = $false
try {
    $gitVer = git --version 2>$null
    if ($gitVer) {
        Write-Host "  ✅ Git: $gitVer" -ForegroundColor Green
        $gitAvailable = $true
    }
} catch {}

if (-not $gitAvailable) {
    Write-Host "  ⚠️  Git não encontrado (opcional - pode baixar manualmente)" -ForegroundColor Yellow
    Write-Host "     Baixe em: https://git-scm.com/downloads" -ForegroundColor Gray
}

# VSCode
$vscodeAvailable = $false
try {
    $codeVer = code --version 2>$null
    if ($codeVer) {
        Write-Host "  ✅ VSCode: $($codeVer[0])" -ForegroundColor Green
        $vscodeAvailable = $true
    }
} catch {}

if (-not $vscodeAvailable) {
    Write-Host "  ⚠️  VSCode não encontrado (opcional - pode usar sem)" -ForegroundColor Yellow
    Write-Host "     Baixe em: https://code.visualstudio.com/download" -ForegroundColor Gray
}

# Verificar se Docker está rodando
try {
    $dockerPs = docker ps 2>$null
    if (-not $?) {
        throw "Docker não está rodando"
    }
    Write-Host "  ✅ Docker Desktop está rodando" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Docker Desktop não está rodando!" -ForegroundColor Red
    Write-Host "     Inicie o Docker Desktop e aguarde, depois execute novamente." -ForegroundColor White
    exit 1
}

# ============================================
# PASSO 1 - Clonar ou copiar repositório
# ============================================
$projectDir = "C:\papeluxo"

if (-not $SkipClone) {
    Write-Host "`n[1/9] Configurando projeto..." -ForegroundColor Yellow
    
    if ($RepoUrl -ne "" -and $gitAvailable) {
        # Clonar do GitHub
        if (Test-Path $projectDir) {
            Write-Host "  📁 Diretório já existe: $projectDir" -ForegroundColor Yellow
            $resp = Read-Host "  Deseja sobrescrever? (S/N)"
            if ($resp -eq "S" -or $resp -eq "s") {
                Remove-Item -Recurse -Force $projectDir
            } else {
                Write-Host "  ⚠️  Pulando clone. Usando diretório existente." -ForegroundColor Yellow
                $SkipClone = $true
            }
        }
        
        if (-not $SkipClone) {
            Write-Host "  📦 Clonando repositório: $RepoUrl" -ForegroundColor Gray
            git clone -b $Branch $RepoUrl $projectDir
            Write-Host "  ✅ Repositório clonado!" -ForegroundColor Green
        }
    } else {
        # Copiar do diretório atual
        $currentDir = (Get-Location).Path
        if ($currentDir -ne $projectDir -and (Test-Path "docker-compose.yml")) {
            Write-Host "  📁 Copiando projeto de: $currentDir" -ForegroundColor Gray
            if (Test-Path $projectDir) {
                Remove-Item -Recurse -Force "$projectDir\*" -ErrorAction SilentlyContinue
            } else {
                New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            }
            Copy-Item -Recurse -Force "$currentDir\*" $projectDir -Exclude @(".env", "*.log", "postgres-data", "redis-data", "n8n-data", "traefik-data", "waha-sessions")
            Write-Host "  ✅ Projeto copiado!" -ForegroundColor Green
        } elseif ($currentDir -eq $projectDir) {
            Write-Host "  📁 Já está no diretório do projeto." -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Não foi possível clonar. Informe a URL do repositório:" -ForegroundColor Yellow
            $RepoUrl = Read-Host "  URL do GitHub (ou pressione Enter para pular)"
            if ($RepoUrl -ne "") {
                git clone -b $Branch $RepoUrl $projectDir
                Write-Host "  ✅ Repositório clonado!" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Pulando. Você precisará copiar manualmente." -ForegroundColor Yellow
                New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            }
        }
    }
}

# Entrar no diretório
Set-Location $projectDir
Write-Host "  📂 Diretório: $projectDir" -ForegroundColor Gray

# ============================================
# PASSO 2 - Configurar .env
# ============================================
Write-Host "`n[2/9] Configurando credenciais (.env)..." -ForegroundColor Yellow

if (Test-Path ".env") {
    Write-Host "  📄 Arquivo .env já existe." -ForegroundColor Green
    Write-Host "  ⚠️  Verifique se as credenciais estão corretas!" -ForegroundColor Yellow
    $resp = Read-Host "  Deseja editar agora? (S/N)"
    if ($resp -eq "S" -or $resp -eq "s") {
        if ($vscodeAvailable) {
            code .env
        } else {
            notepad .env
        }
        Write-Host "  ⏸️  Aguarde... Editando .env" -ForegroundColor Yellow
        Read-Host "  Pressione Enter quando terminar de editar"
    }
} else {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "  📄 .env criado a partir de .env.example" -ForegroundColor Green
        Write-Host "  ⚠️  AGORA EDITE O ARQUIVO .env COM SUAS CREDENCIAIS!" -ForegroundColor Red
        if ($vscodeAvailable) {
            code .env
        } else {
            notepad .env
        }
        Write-Host "  ⏸️  Aguarde... Editando .env" -ForegroundColor Yellow
        Read-Host "  Pressione Enter quando terminar de editar"
    } else {
        Write-Host "  ❌ Arquivo .env.example não encontrado!" -ForegroundColor Red
        Write-Host "     Certifique-se de que o repositório foi clonado corretamente." -ForegroundColor White
        exit 1
    }
}

# ============================================
# PASSO 3 - Parar containers antigos
# ============================================
Write-Host "`n[3/9] Parando containers antigos..." -ForegroundColor Yellow
docker compose down 2>$null
Write-Host "  ✅ Containers parados" -ForegroundColor Green

# ============================================
# PASSO 4 - Limpar dados antigos
# ============================================
Write-Host "`n[4/9] Limpando dados de containers anteriores..." -ForegroundColor Yellow
$volumes = @("postgres-data", "redis-data", "n8n-data", "traefik-data", "waha-sessions")
foreach ($vol in $volumes) {
    if (Test-Path $vol) {
        Write-Host "  🗑️  Removendo: $vol" -ForegroundColor Gray
        Remove-Item -Recurse -Force $vol -ErrorAction SilentlyContinue
    }
}
Write-Host "  ✅ Dados limpos" -ForegroundColor Green

# ============================================
# PASSO 5 - Subir containers
# ============================================
Write-Host "`n[5/9] Subindo containers Docker..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar alguns minutos na primeira vez..." -ForegroundColor Gray
docker compose up -d

if (-not $?) {
    Write-Host "  ❌ Erro ao subir containers!" -ForegroundColor Red
    Write-Host "     Execute manualmente: docker compose up -d" -ForegroundColor White
    Write-Host "     E verifique os logs: docker compose logs" -ForegroundColor White
    exit 1
}
Write-Host "  ✅ Containers rodando!" -ForegroundColor Green

# ============================================
# PASSO 6 - Aguardar e verificar serviços
# ============================================
Write-Host "`n[6/9] Aguardando serviços ficarem prontos..." -ForegroundColor Yellow
Write-Host "  ⏳ Aguardando 30 segundos para inicialização..." -ForegroundColor Gray
Start-Sleep -Seconds 30

Write-Host "  📡 Verificando status dos containers:" -ForegroundColor Gray
$services = @("postgres", "redis", "waha", "traefik", "n8n-main", "n8n-worker-1", "n8n-worker-2")
foreach ($svc in $services) {
    $status = docker inspect -f '{{.State.Status}}' $svc 2>$null
    $health = docker inspect -f '{{.State.Health.Status}}' $svc 2>$null
    if ($status -eq "running") {
        if ($health -and $health -ne "<nil>") {
            Write-Host ("  ✅ ${svc}: ${status} (health: ${health})") -ForegroundColor Green
        } else {
            Write-Host ("  ✅ ${svc}: ${status}") -ForegroundColor Green
        }
    } else {
        Write-Host ("  ❌ ${svc}: ${status}") -ForegroundColor Red
    }
}

# Verificar se algum serviço não subiu
$allRunning = $true
foreach ($svc in $services) {
    $status = docker inspect -f '{{.State.Status}}' $svc 2>$null
    if ($status -ne "running") {
        $allRunning = $false
    }
}

if (-not $allRunning) {
    Write-Host "`n  ⚠️  Alguns serviços não estão rodando." -ForegroundColor Yellow
    Write-Host "     Verifique os logs: docker compose logs" -ForegroundColor Yellow
    $resp = Read-Host "  Deseja continuar mesmo assim? (S/N)"
    if ($resp -ne "S" -and $resp -ne "s") {
        exit 1
    }
}

# ============================================
# PASSO 7 - Configurar webhook WAHA
# ============================================
Write-Host "`n[7/9] Configurando webhook no WAHA..." -ForegroundColor Yellow

# Ler WAHA_API_KEY do .env
$envContent = Get-Content ".env" -Raw
$wahaKeyMatch = [regex]::Match($envContent, 'WAHA_API_KEY=(.+)')
$wahaKey = if ($wahaKeyMatch.Success) { $wahaKeyMatch.Groups[1].Value.Trim() } else { "SEM_CHAVE" }

Write-Host "  🔑 WAHA_API_KEY: $($wahaKey.Substring(0, [Math]::Min(10, $wahaKey.Length)))..." -ForegroundColor Gray

try {
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

    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/sessions/" `
        -Method Post `
        -Headers @{
            "X-Api-Key" = $wahaKey
            "Content-Type" = "application/json"
        } `
        -Body $webhookBody

    Write-Host "  ✅ Webhook configurado!" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Não foi possível configurar o webhook automaticamente." -ForegroundColor Yellow
    Write-Host "     Execute manualmente depois que o QR Code for escaneado:" -ForegroundColor Yellow
    Write-Host "     curl -X POST http://localhost:3000/api/sessions/ \`n`       -H 'X-Api-Key: $wahaKey' \`n`       -H 'Content-Type: application/json' \`n`       -d '{\"name\":\"default\",\"config\":{\"webhooks\":[{\"url\":\"http://n8n-main:5678/webhook/papelcia-webhook\",\"events\":[\"message\"]}]}}'" -ForegroundColor Gray
}

# ============================================
# PASSO 8 - Inicializar tokens Tray no Redis
# ============================================
Write-Host "`n[8/9] Inicializando tokens Tray no Redis..." -ForegroundColor Yellow

# Tentar extrair tokens do .env
$trayAccessMatch = [regex]::Match($envContent, 'TRAY_ACCESS_TOKEN=(.+)')
$trayRefreshMatch = [regex]::Match($envContent, 'TRAY_REFRESH_TOKEN=(.+)')
$trayAccess = if ($trayAccessMatch.Success) { $trayAccessMatch.Groups[1].Value.Trim() } else { "" }
$trayRefresh = if ($trayRefreshMatch.Success) { $trayRefreshMatch.Groups[1].Value.Trim() } else { "" }

if ($trayAccess -ne "" -and $trayRefresh -ne "") {
    try {
        docker exec redis redis-cli SET tray_access_token $trayAccess 2>$null
        docker exec redis redis-cli SET tray_refresh_token $trayRefresh 2>$null
        Write-Host "  ✅ Tokens Tray configurados no Redis!" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Erro ao configurar tokens no Redis." -ForegroundColor Yellow
        Write-Host "     Execute manualmente:" -ForegroundColor Yellow
        Write-Host "     docker exec redis redis-cli SET tray_access_token `"$trayAccess`"" -ForegroundColor Gray
        Write-Host "     docker exec redis redis-cli SET tray_refresh_token `"$trayRefresh`"" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠️  Tokens Tray não encontrados no .env" -ForegroundColor Yellow
    Write-Host "     Execute manualmente após configurar:" -ForegroundColor Yellow
    Write-Host "     docker exec redis redis-cli SET tray_access_token `"SEU_TOKEN`"" -ForegroundColor Gray
    Write-Host "     docker exec redis redis-cli SET tray_refresh_token `"SEU_REFRESH`"" -ForegroundColor Gray
}

# ============================================
# PASSO 9 - Finalização
# ============================================
Write-Host "`n[9/9] ✅ SETUP CONCLUÍDO!" -ForegroundColor Green
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        ✅ PAPELUXO PRONTO PARA USO!              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 PRÓXIMOS PASSOS:" -ForegroundColor White
Write-Host ""

Write-Host "1️⃣  ABRIR WAHA E ESCANEAR QR CODE" -ForegroundColor Yellow
Write-Host "   ➜ http://localhost:3000/dashboard" -ForegroundColor White
Write-Host "   ➜ Clique na sessão 'default'" -ForegroundColor Gray
Write-Host "   ➜ Escaneie o QR Code com o WhatsApp" -ForegroundColor Gray
Write-Host ""

Write-Host "2️⃣  ABRIR n8n E IMPORTAR WORKFLOWS" -ForegroundColor Yellow
Write-Host "   ➜ http://localhost:5678" -ForegroundColor White
Write-Host "   ➜ Para CADA workflow em workflows/*.json:" -ForegroundColor Gray
Write-Host "     1. Settings > Import from JSON" -ForegroundColor Gray
Write-Host "     2. Cole o JSON" -ForegroundColor Gray
Write-Host "     3. Substitua COLOQUE_SUA_..._AQUI pelos valores reais" -ForegroundColor Gray
Write-Host "     4. Crie/associe a credencial Redis" -ForegroundColor Gray
Write-Host "     5. Salve e ative" -ForegroundColor Gray
Write-Host ""

Write-Host "3️⃣  TESTAR" -ForegroundColor Yellow
Write-Host "   ➜ Envie 'Olá' para o WhatsApp conectado" -ForegroundColor White
Write-Host ""

if ($vscodeAvailable) {
    Write-Host "4️⃣  ABRIR NO VSCODE" -ForegroundColor Yellow
    Write-Host "   ➜ code $projectDir" -ForegroundColor White
    Write-Host ""
}

if ($OpenBrowser) {
    Write-Host "⏳ Abrindo WAHA e n8n no navegador..." -ForegroundColor Gray
    Start-Process "http://localhost:3000/dashboard"
    Start-Process "http://localhost:5678"
}

Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🚀 PAPELUXO AGORA PODE USAR CLINE + DEEPSEEK  ║" -ForegroundColor Cyan
Write-Host "║  No VSCode, abra a pasta C:\papeluxo            ║" -ForegroundColor Cyan
Write-Host "║  E use o Cline para editar os workflows!       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
