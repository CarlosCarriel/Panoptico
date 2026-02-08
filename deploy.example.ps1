# Deploy PowerShell Dev → Runtime
# INSTRUCCIONES: Copia este archivo como 'deploy.ps1' y ajusta las rutas

$Source = "$env:USERPROFILE\Dev\PowerShell"
$Target = "$env:USERPROFILE\Documents\PowerShell"

Write-Host "[DEPLOY PowerShell] Copiando desde Dev a Runtime..." -ForegroundColor Cyan

if (-not (Test-Path $Source)) {
    Write-Host "[ERROR] Source no existe: $Source" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}

$Exclude = @('.git', '.gitignore', 'deploy.ps1', 'README.md', '*.log')
Get-ChildItem $Source -Exclude $Exclude | Copy-Item -Destination $Target -Recurse -Force

Write-Host "Deploy completado a: $Target" -ForegroundColor Green
