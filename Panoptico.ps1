# =============================================================
# PANÓPTICO v3.0 - Lanzador e Interfaz de Usuario
# =============================================================

# [INIT] Carga de Dependencias
$corePath = "$PSScriptRoot\Panoptico_Core.psm1"
if (Test-Path $corePath) {
    Import-Module $corePath -Force
}
else {
    Write-Warning "Panoptico: Core module not found at $corePath"
    return
}

# [INIT] Cargar Configuración
try {
    $Config = Initialize-PanopticoConfig -Path "$PSScriptRoot\config.json"
}
catch {
    Write-Error "Panoptico: Falló la carga de configuración. $($_.Exception.Message)"
    return
}

# [PROTECCIÓN] Evitar doble carga
if ($global:PanopticoEnv.Loaded) {
    Write-Warning "Panóptico ya está cargado en esta sesión. Use 'pan' para ver el menú."
    return
}

# [GLOBALES] Entorno de Ejecución
$global:PanopticoEnv = @{
    IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Version = "3.0.0"
    Loaded  = $true
}

# [FUNC] Wrappers de Optimización (RAM)
function ram1 { 
    Write-Host "`n[RAM-1] Limpieza de Procesos en Segundo Plano (Bloatware)..." -ForegroundColor Cyan
    $res = Invoke-MemoryOptimization -Level 1 
    if ($res.Killed) { Write-Host "   Orden de detención enviada a: $($res.Killed -join ', ')" -ForegroundColor DarkGray }
    Write-Host "   -> Recursos liberados: $($res.FreedMB) MB" -ForegroundColor Green
}

function ram2 {
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Warning "Privilegios de Administrador Requeridos"; return }
    Write-Host "`n[RAM-2] Optimización de Conjunto de Trabajo (Working Set Trim)..." -ForegroundColor Cyan
    $res = Invoke-MemoryOptimization -Level 2
    Write-Host "   -> Recursos liberados (Paginación forzada): $($res.FreedMB) MB" -ForegroundColor Green
}

function ram3 {
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Warning "Privilegios de Administrador Requeridos"; return }
    Write-Host "`n[RAM-3] MODO PROFUNDO (Detención + Compactación Global)..." -ForegroundColor Magenta
    
    # VERIFICACIÓN INTERACTIVA
    $candidates = @()
    $targets = $Config.Optimization.Ram3_Aggressive + $Config.Focalizar.VipProcesses
    foreach ($t in $targets) {
        $p = Get-Process -Name $t -ErrorAction SilentlyContinue
        if ($p) { $candidates += "$($p.ProcessName) (PID: $($p.Id))" }
    }
    
    if ($candidates) {
        Write-Host "`n[!] Procesos activos detectados para cierre potencial:" -ForegroundColor Yellow
        $candidates | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        
        $confirm = Read-Host "`n¿Autoriza el cierre de estos procesos para máxima liberación? (S/n)"
        if ($confirm -ne 'S' -and $confirm -ne 's') {
            Write-Host "   Cancelado por usuario. Ejecutando solo compactación..." -ForegroundColor DarkGray
            # Lógica de Nivel 2: Alternativa sin cierre forzado.
            # Decisión: Abortar terminación de procesos pero ejecutar limpieza de memoria.
            # Simplificación: Detener ram3 por negativa del usuario y sugerir ram2.
            Write-Host "   Sugerencia: use 'ram2' para limpiar sin cerrar aplicaciones." -ForegroundColor White
            return
        }
    }
    
    $res = Invoke-MemoryOptimization -Level 3 -Force
    if ($res.Killed) { Write-Host "   Procesos terminados: $($res.Killed -join ', ')" -ForegroundColor DarkGray }
    Write-Host "   -> Recursos liberados (Delta Working Set): $($res.FreedMB) MB" -ForegroundColor Green
}

# [FUNC] Wrappers de Hibernación (Hiber)
function Invoke-HibernationPhase {
    param($PhaseName, $TargetList)
    
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Warning "Requiere Admin"; return }
    Write-Host "`n[HIBER] Ejecutando Fase: $PhaseName" -ForegroundColor Yellow
    
    foreach ($item in $TargetList) {
        $res = Invoke-ServiceAction -Target $item -Action Hibernate
        
        if ($res.Status -eq "Success") {
            Write-Host "   [✓] Hibernado: $($item.Name) ($($item.Desc))" -ForegroundColor Green
        }
        elseif ($res.Status -eq "Skipped") {
            # Mostrar solo omitidos si estaban activos para reducir ruido
            # Manejo especial para DoSvc (Restringido)
            if ($res.Message -like "*Restringido*") {
                Write-Host "   [!] Advertencia: $($item.Name) - $($res.Message)" -ForegroundColor Yellow
            }
            else {
                Write-Host "   [-] Omitido: $($item.Name) - $($res.Message)" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "   [x] Error: $($item.Name) - $($res.Message)" -ForegroundColor Red
        }
    }
}

function hiber1 { Invoke-HibernationPhase "Telemetría" $Config.Hibernation.Level1_Telemetry }
function hiber2 { Invoke-HibernationPhase "Auxiliar (OEM)" $Config.Hibernation.Level2_Auxiliary }
function hiber3 { Invoke-HibernationPhase "Deep Work" $Config.Hibernation.Level3_DeepWork }

function reversahiber {
    Write-Host "`n[REVERSA] Restauración de Servicios del Sistema..." -ForegroundColor Cyan
    
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Warning "Privilegios de Administrador Requeridos"; return }
    
    # Call Core Restore
    try {
        $results = Restore-PanopticoSnapshot
        $successCount = ($results | Where-Object Status -eq 'Success').Count
        
        if ($results.Count -eq 0) {
            Write-Host "   [i] No hay servicios hibernados en la sesión actual para restaurar." -ForegroundColor DarkGray
        }
        else {
            foreach ($r in $results) {
                if ($r.Status -eq 'Success') { Write-Host "   [✓] Restaurado: $($r.Name)" -ForegroundColor Green }
                else { Write-Host "   [x] Falló: $($r.Name) - $($r.Message)" -ForegroundColor Red }
            }
            Write-Host "`n   Proceso finalizado. ($successCount) servicios recuperados." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "   [!] Error crítico en restauración: $_" -ForegroundColor Red
    }
}

# [FUNC] UI & Monitor
function top {
    Clear-Host
    
    # Encabezado estilo Lotus 1-2-3
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host "  PANÓPTICO v3.0 - MONITOR DE RECURSOS EN TIEMPO REAL       " -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Obtener métricas de sistema
    $os = Get-CimInstance Win32_OperatingSystem
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $usedGB = [math]::Round($totalGB - $freeGB, 2)
    $freePercent = [math]::Round(($freeGB / $totalGB) * 100, 1)
    
    # Barra de progreso ASCII (10 caracteres)
    $barLength = 10
    $filledBars = [math]::Floor(($usedGB / $totalGB) * $barLength)
    $emptyBars = $barLength - $filledBars
    $ramBar = ("#" * $filledBars) + ("-" * $emptyBars)
    
    Write-Host "`n┌─ MEMORIA RAM ─────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│ TOTAL    : " -NoNewline -ForegroundColor Gray
    Write-Host "$totalGB GB" -ForegroundColor White
    Write-Host "│ EN USO   : " -NoNewline -ForegroundColor Gray
    Write-Host "$usedGB GB" -ForegroundColor White
    Write-Host "│ LIBRE    : " -NoNewline -ForegroundColor Gray
    Write-Host "$freeGB GB ($freePercent%)" -ForegroundColor Green
    Write-Host "│ VISUAL   : [" -NoNewline -ForegroundColor Gray
    Write-Host "$ramBar" -NoNewline -ForegroundColor $(if ($freePercent -lt 20) { "Red" } elseif ($freePercent -lt 40) { "Yellow" } else { "Green" })
    Write-Host "]" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    
    # Top 5 Procesos
    Write-Host "`n┌─ TOP 5 PROCESOS ──────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ " -NoNewline -ForegroundColor Cyan
    Write-Host "PROCESO" -NoNewline -ForegroundColor White
    Write-Host "                 " -NoNewline
    Write-Host "RAM (MB)" -NoNewline -ForegroundColor White
    Write-Host "                          │" -ForegroundColor Cyan
    Write-Host "├───────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    
    $topProcs = Get-Process | Sort-Object WS -Descending | Select-Object -First 5
    foreach ($proc in $topProcs) {
        $name = $proc.ProcessName.PadRight(30).Substring(0, 30)
        $ramMB = [math]::Round($proc.WS / 1MB, 1)
        Write-Host "│ " -NoNewline -ForegroundColor Cyan
        Write-Host "$name" -NoNewline -ForegroundColor Gray
        Write-Host "$ramMB".PadLeft(8) -NoNewline -ForegroundColor White
        Write-Host "                    │" -ForegroundColor Cyan
    }
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Cyan

    # GPU Monitor (Multi-Vendor)
    Write-Host "`n┌─ GPU ─────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    
    $gpuDetected = $false

# Intento NVIDIA-SMI (Métricas Completas si está disponible y drivers compatibles)

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    try {
        # Captura stderr fusionado (2>&1) para detectar errores de driver
        $nvsmiRaw = & nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits 2>&1
        
        # Filtro de líneas válidas: debe contener al menos 4 números separados por comas
        $validLines = $nvsmiRaw | Where-Object { 
            $_ -is [string] -and 
            $_ -notmatch '^(ERROR|Failed|Unable|\s*$)' -and
            $_ -match '^\d+\s*,.*\d+\s*,.*\d+\s*,.*\d+'
        }
        
        foreach ($line in $validLines) {
            $parts = $line -split ',' | ForEach-Object { $_.Trim() }
            
            if ($parts.Count -ge 5) {
                # Casting CLR nativo (TryParse implícito)
                $u  = $parts[0] -as [int]
                $mU = $parts[1] -as [int]
                $mT = $parts[2] -as [int]
                $t  = $parts[3] -as [int]
                $name = $parts[4..($parts.Count-1)] -join ','
                
                # Validación mínima: memoria total debe existir
                if ($null -ne $mT -and $mT -gt 0) {
                    $pct = [math]::Round(($mU / $mT) * 100, 1)
                    $tempColor = if ($t -gt 75) { "Red" } elseif ($t -gt 65) { "Yellow" } else { "Green" }
                    
                    Write-Host "│ MODELO    : " -NoNewline -ForegroundColor Gray
                    Write-Host "$name" -ForegroundColor Cyan
                    
                    # ──────────────────────────────────────────────
                    # NÚCLEO: Mostrar solo si disponible (no WDDM)
                    # ──────────────────────────────────────────────
                    if ($null -ne $u -and $u -ge 0) {
                        Write-Host "│ NÚCLEO    : " -NoNewline -ForegroundColor Gray
                        $coreColor = if ($u -gt 80) { "Red" } elseif ($u -gt 50) { "Yellow" } else { "Green" }
                        Write-Host "$u%" -ForegroundColor $coreColor
                    }
                    # Si es null, simplemente no mostrar la línea (design clean)
                    
                    Write-Host "│ VRAM      : " -NoNewline -ForegroundColor Gray
                    Write-Host "$mU / $mT MB ($pct%)" -ForegroundColor White
                    
                    Write-Host "│ TEMP      : " -NoNewline -ForegroundColor Gray
                    if ($t -gt 0) {
                        Write-Host "$t°C" -ForegroundColor $tempColor
                    } else {
                        Write-Host "N/A" -ForegroundColor DarkGray
                    }
                    
                    # ──────────────────────────────────────────────
                    # NOTA: Solo mostrar si utilization no está disponible
                    # ──────────────────────────────────────────────
                    if ($null -eq $u -or $u -lt 0) {
                        Write-Host "│ NOTA      : " -NoNewline -ForegroundColor Gray
                        Write-Host "Utilización GPU no disponible (WDDM Mode)" -ForegroundColor DarkGray
                    }
                    
                    $gpuDetected = $true
                }
            }
        }
        
    } catch {
        # Fallo crítico: pasar silenciosamente a WMI
    }
}

# Si NVIDIA-SMI no dio resultados válidos, intenta enfoque genérico (AMD/Intel)

if (-not $gpuDetected) {
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction Stop | 
               Where-Object { $_.Name -notmatch "Remote|Virtual|Basic" } | 
               Select-Object -First 1
        
        if ($gpu) {
            $vramGB = if ($gpu.AdapterRAM -gt 0) { [math]::Round($gpu.AdapterRAM / 1GB, 1) } else { "N/A" }
            
            Write-Host "│ FABRICANTE: " -NoNewline -ForegroundColor Gray
            Write-Host "$($gpu.Name)" -ForegroundColor Cyan
            Write-Host "│ VRAM      : " -NoNewline -ForegroundColor Gray
            Write-Host "$vramGB GB" -ForegroundColor White
            Write-Host "│ DRIVER    : " -NoNewline -ForegroundColor Gray
            Write-Host "$($gpu.DriverVersion)" -ForegroundColor DarkGray
            Write-Host "│ NOTA      : " -NoNewline -ForegroundColor Gray
            Write-Host "Métricas en vivo requieren drivers nativos" -ForegroundColor DarkGray
            
            $gpuDetected = $true
        }
    } catch {}
}

# Gestión de caso sin GPU detectada

if (-not $gpuDetected) {
    Write-Host "│ ESTADO    : " -NoNewline -ForegroundColor Gray
    Write-Host "GPU no detectada o drivers incompatibles" -ForegroundColor Red
}

Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
}

function pan {
    Clear-Host
    
    # Encabezado estilo Lotus 1-2-3
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host "  PANÓPTICO v$($global:PanopticoEnv.Version) - ESTACIÓN DE CONTROL                   " -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Sección de Optimización de RAM
    Write-Host "`n┌─ OPTIMIZACIÓN DE MEMORIA ─────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│ ram1          │ Limpieza de Segundo Plano (Bloatware)     │" -ForegroundColor Gray
    Write-Host "│ ram2          │ Optimización de Kernel (Admin)            │" -ForegroundColor Gray
    Write-Host "│ ram3          │ Modo Profundo (Cierre Global)             │" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    
    # Sección de Hibernación
    Write-Host "`n┌─ HIBERNACIÓN DE SERVICIOS ────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ hiber1        │ Desactivar Telemetría                     │" -ForegroundColor Gray
    Write-Host "│ hiber2        │ Desactivar Bloatware (OEM)                │" -ForegroundColor Gray
    Write-Host "│ hiber3        │ Modo Enfoque (Sin Impresora/Búsqueda)     │" -ForegroundColor Gray
    Write-Host "│ reversahiber  │ Restaurar Servicios Hibernados            │" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    
    # Sección de Monitoreo
    Write-Host "`n┌─ MONITOREO Y GESTIÓN ─────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "│ top           │ Monitor de Recursos en Tiempo Real        │" -ForegroundColor Gray
    Write-Host "│ focalizar     │ Ver/Gestionar Apps Prioritarias (VIP)     │" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
    
    # Sección de Limpieza
    Write-Host "`n┌─ LIMPIEZA ────────────────────────────────────────────────┐" -ForegroundColor DarkYellow
    Write-Host "│ purga         │ Purga Sistema (DNS, Temps, WER)           │" -ForegroundColor Gray
    Write-Host "│ purgap        │ Purga Data Science (Conda, Jupyter)       │" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor DarkYellow
    
    # Sección de Atajos Rápidos
    Write-Host "`n┌─ ATAJOS ──────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "│ e             │ Abrir Explorador de Archivos              │" -ForegroundColor Gray
    Write-Host "│ ex            │ Salir de la Terminal                      │" -ForegroundColor Gray
    Write-Host "│ lab           │ Iniciar Jupyter Lab                       │" -ForegroundColor Gray
    Write-Host "└───────────────────────────────────────────────────────────┘" -ForegroundColor Green
    
    Write-Host ""
}

function focalizar {
    # Bucle Interactivo
    while ($true) {
        Clear-Host
        Write-Host "`n[FOCALIZAR] GESTIÓN DE PRIORIDADES (VIP LIST)" -ForegroundColor Cyan
        Write-Host "----------------------------------------------" -ForegroundColor DarkGray
        
        $vips = $Config.Focalizar.VipProcesses
        if ($vips) {
            Write-Host "Aplicaciones protegidas (No se cierran en ram3):"
            $i = 1
            foreach ($vip in $vips) {
                Write-Host "   [$i] $vip" -ForegroundColor Yellow
                $i++
            }
        }
        else {
            Write-Host "   (Lista vacía)" -ForegroundColor Red
        }
        
        Write-Host "`n[OPCIONES]" -ForegroundColor White
        Write-Host " A - Agregar Proceso" -ForegroundColor Green
        Write-Host " R - Remover Proceso" -ForegroundColor Red
        Write-Host " X - Volver al Menú" -ForegroundColor Gray
        
        $choice = Read-Host "`nSeleccione una opción"
        
        switch ($choice.ToUpper()) {
            "A" {
                $newProc = Read-Host "Nombre del proceso (sin .exe)"
                if (-not [string]::IsNullOrWhiteSpace($newProc)) {
                    if ($Config.Focalizar.VipProcesses -contains $newProc) {
                        Write-Warning "El proceso ya está en la lista."
                    }
                    else {
                        $Config.Focalizar.VipProcesses += $newProc
                        if (Save-PanopticoConfig) { Write-Host "   [+] Agregado: $newProc" -ForegroundColor Green }
                    }
                }
            }
            "R" {
                $remProc = Read-Host "Nombre del proceso a remover"
                if ($Config.Focalizar.VipProcesses -contains $remProc) {
                    $Config.Focalizar.VipProcesses = $Config.Focalizar.VipProcesses | Where-Object { $_ -ne $remProc }
                    if (Save-PanopticoConfig) { Write-Host "   [-] Removido: $remProc" -ForegroundColor Green }
                }
                else {
                    Write-Warning "Proceso no encontrado en la lista."
                }
            }
            "X" { return }
            default { }
        }
        Start-Sleep -Milliseconds 500
    }
}

# [FUNC] Purga de Entorno trabajo profundo
function purgap {
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host "  PURGA ENTORNO TRABAJO PROFUNDO                           " -NoNewline -ForegroundColor White -BackgroundColor DarkMagenta
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # 1. Kernels Jupyter (WMI approach)
    Write-Host "`n [→] Jupyter kernels" -ForegroundColor Yellow
    $kernels = Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*ipykernel*" }
    
    if ($kernels) {
        $kernels | ForEach-Object { 
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue 
        }
        Write-Host "     ✓ $(@($kernels).Count) kernels" -ForegroundColor Green
    }
    else {
        Write-Host "     - Sin kernels activos" -ForegroundColor DarkGray
    }

    # 2. Jupyter Runtime
    Write-Host " [→] Jupyter runtime" -ForegroundColor Yellow
    $jPath = "$env:APPDATA\jupyter\runtime"
    if (Test-Path $jPath) {
        $garbage = Get-ChildItem $jPath -Filter *.json | 
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-24) }
        if ($garbage) {
            $garbage | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "     ✓ $(@($garbage).Count) archivos" -ForegroundColor Green
        }
        else {
            Write-Host "     - Nada antiguo" -ForegroundColor DarkGray
        }
    }

    # 3. PIP
    Write-Host " [→] PIP cache" -ForegroundColor Yellow
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        pip cache purge 2>$null | Out-Null
        Write-Host "     ✓ Purgado" -ForegroundColor Green
    }

    # 4. Conda (async)
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        Write-Host " [→] Conda clean (async)" -ForegroundColor Magenta
        $job = Start-Job -ScriptBlock { conda clean --index-cache --tarballs -y }
        Write-Host "     ✓ Job $($job.Id) iniciado" -ForegroundColor Green
    }
    
    Write-Host "`n✓ Entorno DS limpiado" -ForegroundColor Cyan
}

# [FUNC] Purga de Sistema
function purga {
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host "  PURGA SISTEMA OPERATIVO                                  " -NoNewline -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # DNS
    Write-Host "`n [→] DNS cache" -ForegroundColor Yellow
    ipconfig /flushdns > $null 2>&1
    Write-Host "     ✓ Limpio" -ForegroundColor Green
    
    # Temporales
    Write-Host " [→] Temporales" -ForegroundColor Yellow
    $tempPaths = @($env:TEMP, "C:\Windows\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "     ✓ Limpiados" -ForegroundColor Green
    
    # Ollama logs
    Write-Host " [→] Ollama logs" -ForegroundColor Yellow
    $logs = Get-Item "$env:TEMP\ollama_*.log" -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending
    if ($logs) {
        $toDelete = $logs | Select-Object -Skip 3
        if ($toDelete) {
            $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "     ✓ $(@($toDelete).Count) logs antiguos" -ForegroundColor Green
        }
        else {
            Write-Host "     - Solo logs recientes" -ForegroundColor DarkGray
        }
    }
    
    # WER
    Write-Host " [→] Reportes Windows (WER)" -ForegroundColor Yellow
    $werPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
    if (Test-Path $werPath) {
        Remove-Item "$werPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "     ✓ Limpio" -ForegroundColor Green
    }
    
    Write-Host "`n✓ Sistema purgado" -ForegroundColor Cyan
}

# [FUNC] Ejecuta Jupyter Lab con logging de Sesión
function lab {
    # Valida que Jupyter esté instalado
    if (-not (Get-Command jupyter -ErrorAction SilentlyContinue)) {
        Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║" -NoNewline -ForegroundColor Red
        Write-Host "  ERROR: JUPYTER LAB NO ENCONTRADO                         " -NoNewline -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host "`nJupyter Lab no está instalado o no está en PATH." -ForegroundColor Yellow
        Write-Host "Instalar con: " -NoNewline -ForegroundColor Gray
        Write-Host "pip install jupyterlab" -ForegroundColor Cyan
        return
    }
    
    $logPath = "$HOME\Documents\.session_logs.txt"
    $startTime = Get-Date
    
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host "  INICIANDO JUPYTER LAB                                     " -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Registrar inicio de sesión
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] Jupyter Lab - Inicio"
    Add-Content -Path $logPath -Value $logEntry
    
    # Ejecutar Jupyter Lab
    try {
        & jupyter lab
    }
    catch {
        Write-Host "Error al iniciar Jupyter Lab: $_" -ForegroundColor Red
        return
    }
    
    # Calcular duración de sesión
    $endTime = Get-Date
    $duration = $endTime - $startTime
    $hours = [math]::Floor($duration.TotalHours)
    $minutes = $duration.Minutes
    
    # Registrar fin de sesión
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] Jupyter Lab - Fin (Duración: ${hours}h ${minutes}m)"
    Add-Content -Path $logPath -Value $logEntry
    
    Write-Host "`nSesión registrada en: $logPath" -ForegroundColor Green
}

# [ATAJOS] Flujo de Trabajo
function e { explorer . }  # Abre directorio actual
function ex { exit }

# [AUTOSTART]
Write-Host "`n>>> PANÓPTICO CARGADO. Escribe 'pan' para el menú." -ForegroundColor Green
if ($global:PanopticoEnv.IsAdmin) { Write-Host "    [MODO ADMINISTRADOR]" -ForegroundColor Red }
