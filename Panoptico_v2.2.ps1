# =============================================================
# PANOPTICO DE INFRAESTRUCTURA - SOFTCFCA v2.2
# Elite SysAdmin Toolkit: Memory, Network, CPU, GPU, LLM
# =============================================================
$startTimer = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [INIT] Sincronización dinámica de Búfer y Ventana
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Initialize-PanopticoEnv {
    [CmdletBinding()]
    param()
    
    $envInfo = [PSCustomObject]@{
        PSVersion = $PSVersionTable.PSVersion
        IsAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Timestamp = Get-Date
    }
    
    if ($envInfo.PSVersion.Major -lt 7) {
        Write-Warning "Panóptico: Ejecutando en modo compatibilidad (PS $($envInfo.PSVersion.Major)). Algunas funciones serán más lentas."
        Start-Sleep -Seconds 1
    }
    
    return $envInfo
}
$global:PanopticoEnv = Initialize-PanopticoEnv

try {
    if ($Host.UI.RawUI.WindowSize.Width -gt 0) {
        $newWidth = $Host.UI.RawUI.WindowSize.Width
        $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($newWidth, 9999)
    }
} catch {
    # Windows Terminal / VSCode manejan buffer dinámicamente (silencio)
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [KERNEL] Definiciones Nativas (P/Invoke) - Carga Estática
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Compilamos la firma C# al inicio para evitar lag durante la ejecución.
if (-not ([System.Management.Automation.PSTypeName]'WinAPI.Memory').Type) {
    $signature = @"
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool EmptyWorkingSet(IntPtr proc);
"@
    Add-Type -MemberDefinition $signature -Name Memory -Namespace WinAPI -ErrorAction SilentlyContinue
}

$Arsenal = [ordered] @{
    "TOP"          = @{ Index = "01"; Description = "Monitor de recursos en tiempo real (RAM, GPU, Red, Disco)." }
    "MONITOR"      = @{ Index = "02"; Description = "Dashboard persistente (top en bucle)." }
    "RED"          = @{ Index = "03"; Description = "Escáner de red local (IP, Hostname, MAC)." }
    "VERSEGURIDAD" = @{ Index = "04"; Description = "Auditoría de Seguridad: Antivirus, Firewall, Puertos...," }
    "RAM1"         = @{ Index = "05"; Description = "Limpieza Rápida: GC + Bloatware superficial (Seguro)." }
    "RAM2"         = @{ Index = "06"; Description = "Limpieza Profunda: Kernel EmptyWorkingSet (Admin)." }
    "RAMOLLAMA"    = @{ Index = "07"; Description = "Limpieza Extrema: Modo dedicado para IA/LLM (Admin)." }
    "PURGA"        = @{ Index = "08"; Description = "Saneamiento OS: Temporales, DNS, Logs, WER." }
    "PURGAP"       = @{ Index = "09"; Description = "Saneamiento Dev: Conda, Pip, Jupyter Kernels." }
    "FOCALIZAR"    = @{ Index = "10"; Description = "CPU Boost: Prioridad Alta a procesos VIP (Python, Ollama)." }
    "HIBER1"       = @{ Index = "11"; Description = "Hibernación 1: Telemetría Microsoft (Reversible)." }
    "HIBER2"       = @{ Index = "12"; Description = "Hibernación 2: Servicios Auxiliares y Tareas (Reversible)." }
    "HIBER3"       = @{ Index = "13"; Description = "Hibernación 3: Deep Work (Search, Spooler, SysMain)." }
    "HIBERSTATUS"  = @{ Index = "14"; Description = "Auditoría: Ver qué servicios están hibernados actualmente." }
    "REVERSAHIBER" = @{ Index = "15"; Description = "Restauración: Despertar servicios hibernados." }
    "LAB"          = @{ Index = "16"; Description = "Incia entorno X + Jupyter Lab." }
    "OLLAMA"       = @{ Index = "17"; Description = "Controlador LLM: start | stop | status | logs | debug-on." }
    "PAN"          = @{ Index = "18"; Description = "Manual de referencia / Menú Principal." }
    " "            = @{ Index = "19"; Description = "                                        ...CARGA COMPLETA." }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [INIT] Identidad y Estética
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$priv = if ($global:PanopticoEnv.IsAdmin) { "CFCA_ADMIN" } else { "CFCA" }
$colorHeader = if ($global:PanopticoEnv.IsAdmin) { "Red" } else { "Cyan" }
$Host.UI.RawUI.WindowTitle = "PAN v2.2 | $priv Console"

# [OPTIMIZACIÓN] Usamos CIM (WMI) en lugar de Get-NetAdapter para evitar cargar módulos pesados (ahorra ~3s)
$netConf = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Select-Object -First 1
$ip = if ($netConf) { $netConf.IPAddress[0] } else { "127.0.0.1" }
$adapterName = if ($netConf) { $netConf.Description.Split('(')[0].Trim() } else { "Loopback" }

Write-Host "`n>>> SESSION: $priv | IP: $ip | ADAPTER: $adapterName <<<" -ForegroundColor $colorHeader
Write-Host "Escribe 'PAN' para ver el arsenal del Panóptico. [v2.2 - 2025]`n" -ForegroundColor DarkGray

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [GLOBALS] Ollama & Caché (Persistencia de Estado)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# v2.1: Solo inicializa si NO existen (permite reload sin perder estado)
if (-not (Get-Variable -Name OllamaJob -Scope Global -ErrorAction SilentlyContinue)) {
    $global:OllamaJob = $null
}
if (-not (Get-Variable -Name OllamaDebugMode -Scope Global -ErrorAction SilentlyContinue)) {
    $global:OllamaDebugMode = $false
}

# Rate limiting para ramlimpia-profundo (evitar thrashing)
if (-not (Get-Variable -Name LastDeepClean -Scope Global -ErrorAction SilentlyContinue)) {
    $global:LastDeepClean = (Get-Date).AddHours(-2)
}

# Caché de GPU (nvidia-smi toma ~200ms, cachear cada 5s)
if (-not (Get-Variable -Name GPUCache -Scope Global -ErrorAction SilentlyContinue)) {
    $global:GPUCache = @{ Data = $null; Timestamp = (Get-Date).AddSeconds(-10) }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [GLOBALS] Sistema de Hibernación (Persistencia de Estado)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if (-not (Get-Variable -Name HibernationLog -Scope Global -ErrorAction SilentlyContinue)) {
    $global:HibernationLog = @()
}

# Path del log persistente (Aseguramos que el directorio exista)
$hibDir = "$env:USERPROFILE\Documents\PowerShell"
if (-not (Test-Path $hibDir)) { New-Item -ItemType Directory -Path $hibDir -Force | Out-Null }
$global:HibernationLogPath = "$hibDir\panoptico_hibernacion.log"

# Snapshot de estado inicial (para rollback)
if (-not (Get-Variable -Name ServiceSnapshot -Scope Global -ErrorAction SilentlyContinue)) {
    $global:ServiceSnapshot = @{}
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] top - Monitor de Recursos (Snapshot)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function top {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║      PANÓPTICO - MONITOREO DE RECURSOS EN VIVO                          ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # ─── RAM ───
    $os = Get-CimInstance Win32_OperatingSystem
    $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $used = $total - $free
    $p = [math]::Round(($used / $total) * 100, 1)

    Write-Host "`n[RAM SISTEMA]" -ForegroundColor Yellow
    Write-Host "   Usado: $used / $total GB ($p%)" -ForegroundColor Gray
    Write-Host "   Libre: $free GB" -ForegroundColor Gray

    # ─── DISCO C: (Nuevo) ───
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotal = [math]::Round($disk.Size / 1GB, 2)
    $diskFree = [math]::Round($disk.FreeSpace / 1GB, 2)
    $diskUsed = [math]::Round($diskTotal - $diskFree, 2)
    $diskP = [math]::Round(($diskUsed / $diskTotal) * 100, 1)

    Write-Host "`n[DISCO LOCAL C:]" -ForegroundColor Yellow
    Write-Host "   Usado: $diskUsed / $diskTotal GB ($diskP%)" -ForegroundColor Gray
    Write-Host "   Libre: $diskFree GB" -ForegroundColor Gray

    # ─── GPU (con caché) ───
    Write-Host "`n[GPU NVIDIA]" -ForegroundColor Yellow
    $elapsed = (Get-Date) - $global:GPUCache.Timestamp
    if ($elapsed.TotalSeconds -gt 5 -or -not $global:GPUCache.Data) {
        try {
            $nvsmi = & nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($nvsmi) {
                $global:GPUCache.Data = $nvsmi
                $global:GPUCache.Timestamp = Get-Date
            }
        } catch {
            $global:GPUCache.Data = $null
        }
    }

    if ($global:GPUCache.Data) {
        # Soporte robusto para múltiples GPUs y CSV parsing
        $gpus = $global:GPUCache.Data | ConvertFrom-Csv -Header "Util","Used","Total","Temp"
        foreach ($gpu in $gpus) {
            $gpuUtil = [int]$gpu.Util
            $vramUsed = [int]$gpu.Used
            $vramTotal = [int]$gpu.Total
            $temp = [int]$gpu.Temp
            
            $vramUsedGB = [math]::Round($vramUsed / 1024, 2)
            $vramTotalGB = [math]::Round($vramTotal / 1024, 2)
            $vramPercent = if ($vramTotal -gt 0) { [math]::Round(($vramUsed / $vramTotal) * 100, 1) } else { 0 }

            Write-Host "   GPU: Core $gpuUtil% @ $($temp)°C" -ForegroundColor Gray
            Write-Host "        VRAM: $vramUsedGB / $vramTotalGB GB ($vramPercent%)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   (nvidia-smi no disponible o sin GPU)" -ForegroundColor DarkGray
    }

    # ─── TOP PROCESOS (con hashtable O(1)) ───
    Write-Host "`n[TOP PROCESOS - RAM]" -ForegroundColor Cyan
    Get-Process | Sort-Object WS -Descending | Select-Object -First 8 |
    Format-Table @{L="Nombre"; E={$_.ProcessName}; W=20}, `
                 @{L="RAM(MB)"; E={[math]::Round($_.WS/1MB,2)}; W=12}, `
                 @{L="Status"; E={if($_.WS -gt 1GB){"⚠️ PESADO"}else{" ✓ OK"}}; W=12}

    # ─── RED (Optimizada con hashtable O(1)) ───
    Write-Host "`n[ACTIVIDAD DE RED - TOP 5]" -ForegroundColor Magenta

    # Caché de procesos para lookup O(1) en lugar de O(N*M)
    $procHash = @{}
    Get-Process | ForEach-Object { $procHash[$_.Id] = $_.ProcessName }

    try {
        $netConns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $name = $procHash[$_.OwningProcess]
                        if ($name) { [PSCustomObject]@{ Proc = $name; Port = $_.LocalPort } }
                    } |
                    Group-Object Proc |
                    Select-Object Name, @{N="Conexiones";E={$_.Count}} |
                    Sort-Object Conexiones -Descending |
                    Select-Object -First 5

        if ($netConns) {
            $netConns | ForEach-Object {
                Write-Host "   $($_.Name): $($_.Conexiones) conexiones activas" -ForegroundColor Gray
            }
        } else {
            Write-Host "   (Sin conexiones TCP establecidas)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "   (No se pudo enumerar conexiones TCP)" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] monitor - Dashboard en Vivo
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function monitor {
    while($true) {
        Clear-Host
        top
        Write-Host "(Ctrl+C para salir)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] red - Scanner de Dispositivos en Red
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function red {
    if ($ip -eq "127.0.0.1") {
        Write-Host "Error: No hay red activa." -ForegroundColor Red
        return
    }

    $subnet = $ip.Substring(0, $ip.LastIndexOf('.'))
    Write-Host "`n[Radar] Barriendo subred $subnet.0/24..." -ForegroundColor Yellow

    # Ping sweep (Paralelo en PS7+, Secuencial en Legacy)
    if ($global:PanopticoEnv.PSVersion.Major -ge 7) {
        1..254 | ForEach-Object -Parallel {
            $target = "$using:subnet.$_"
            $ping = Test-Connection $target -Count 1 -Quiet -TimeoutSeconds 1
            if ($ping) { Write-Host "[!] Dispositivo activo en $target" -ForegroundColor Green }
        } -ThrottleLimit 100
    } else {
        Write-Host "   [i] Modo compatibilidad: Escaneo secuencial..." -ForegroundColor DarkGray
        1..254 | ForEach-Object {
            $target = "$subnet.$_"
            if (Test-Connection $target -Count 1 -Quiet) { Write-Host "[!] Dispositivo activo en $target" -ForegroundColor Green }
        }
    }

    Write-Host "`n[TABLA DE DISPOSITIVOS DETECTADOS]" -ForegroundColor Cyan

    # v1.9: Usa Get-NetNeighbor (moderno, multilenguaje) con fallback a arp -a
    try {
        $results = Get-NetNeighbor -AddressFamily IPv4 -State Reachable,Stale -ErrorAction Stop |
                   Where-Object { $_.IPAddress -like "$subnet.*" } |
                   ForEach-Object {
                       $h = try {
                           [System.Net.Dns]::GetHostEntry($_.IPAddress).HostName
                       } catch {
                           "Unknown"
                       }
                       [PSCustomObject]@{
                           IP       = $_.IPAddress
                           HostName = $h
                           MAC      = $_.LinkLayerAddress
                       }
                   }

        if ($results) {
            $results | Sort-Object IP | Format-Table -AutoSize
        } else {
            Write-Host "No se hallaron dispositivos. (Asegura que tengan conectividad)" -ForegroundColor DarkGray
        }
    } catch {
        # Fallback a arp -a si Get-NetNeighbor falla
        Write-Host "   [i] Fallback a arp -a (Get-NetNeighbor no disponible)" -ForegroundColor DarkGray

        $results = arp -a | Select-String "$subnet\." | Where-Object { $_ -notmatch "dinámico|estático|dynamic|static" } | ForEach-Object {
            $parts = $_.ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($parts.Count -ge 2) {
                $h = try { [System.Net.Dns]::GetHostEntry($parts[0]).HostName } catch { "Unknown" }
                [PSCustomObject]@{ IP = $parts[0]; HostName = $h; MAC = if ($parts.Count -gt 1) { $parts[1] } else { "N/A" } }
            }
        }

        if ($results) {
            $results | Sort-Object IP | Format-Table -AutoSize
        } else {
            Write-Host "No se hallaron dispositivos (asegúrate que tengan pantalla encendida)" -ForegroundColor Red
        }
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] ram1 - Limpieza Segura
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function ram1 {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║     LIMPIEZA RÁPIDA DE RAM (Modo Seguro)                                ║" -ForegroundColor Green
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Green

    Write-Host "`n[→] Terminando procesos bloatware..." -ForegroundColor Yellow

    $beforeRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory # KB

    $targets = "NVIDIA Share", "PhoneExperienceHost", "StartMenuExperienceHost", "TextInputHost", "Widgets", "MicrosoftEdgeUpdate", "SearchIndexer", "AcrobatNotificationClient", "Lenovo.Modern.ImController", "OneDrive", "GooglePlayGamesAgent", "EpsonScan2"
    
    $killedProcs = Get-Process -Name $targets -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru -ErrorAction SilentlyContinue
    $killedCount = if ($killedProcs) { @($killedProcs).Count } else { 0 }
    $killedNames = if ($killedProcs) { (@($killedProcs).ProcessName | Select-Object -Unique) -join ", " } else { "Ninguno" }

    Write-Host "   ✓ $killedCount procesos terminados: [$killedNames]" -ForegroundColor Green

    Write-Host "`n[→] Ejecutando recolección de basura .NET..." -ForegroundColor Yellow
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Host "   ✓ Memoria administrada liberada" -ForegroundColor Green

    # Detener servicio VPN de Bitdefender (si existe y sin admin)
    Write-Host "`n[→] Optimizando servicios de red..." -ForegroundColor Yellow
    if ($global:PanopticoEnv.IsAdmin) {
        Stop-Service -Name "bdvpnService" -ErrorAction SilentlyContinue -Force
    }
    Write-Host "   ✓ Servicios optimizados" -ForegroundColor Green

    $afterRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory # KB
    $freed = [math]::Round(($afterRAM - $beforeRAM) / 1024, 2) # KB -> MB

    Write-Host "`n✓ Limpieza exitosa" -ForegroundColor Green
    Write-Host "   Procesos terminados: $killed" -ForegroundColor Gray
    Write-Host "   RAM liberada: ~$freed MB" -ForegroundColor Gray
    Write-Host "   RAM libre ahora: $([math]::Round($afterRAM / 1MB, 2)) GB" -ForegroundColor Gray
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] ram2 - Limpieza Potente
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function ram2 {
    param([switch]$Force)
    if (-not $global:PanopticoEnv.IsAdmin) {
        Write-Host "`n[✗] REQUIERE ADMIN. (Win+X → A)" -ForegroundColor Red; return
    }

    # Rate limiting (sin cambios)
    $elapsed = (Get-Date) - $global:LastDeepClean
    if ($elapsed.TotalMinutes -lt 60 -and -not $Force) {
        Write-Host "`n[⚠] ADVERTENCIA: Última limpieza hace $([math]::Round($elapsed.TotalMinutes)) min." -ForegroundColor Yellow
        if ((Read-Host "    ¿Forzar? (s/N)") -ne 's') { return }
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   LIMPIEZA PROFUNDA DE RAM (Kernel Mode Access)      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    $beforeRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory

    # 1. Terminación de Bloatware (Lista optimizada)
    Write-Host "`n[1/4] Terminando bloatware..." -ForegroundColor Yellow
    $bloat = @("NVIDIA Share", "PhoneExperienceHost", "StartMenuExperienceHost", "TextInputHost", "Widgets", "MicrosoftEdgeUpdate", "SearchIndexer", "RuntimeBroker")
    
    $killedNames = @()
    foreach ($name in $bloat) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru -ErrorAction SilentlyContinue) {
            $killedNames += $name
        }
    }
    $killedList = if ($killedNames) { ($killedNames | Select-Object -Unique) -join ", " } else { "Ninguno" }
    Write-Host "      ✓ Bloatware eliminado: [$killedList]" -ForegroundColor Green

    # 2. EmptyWorkingSet (API Nativa - Optimización .NET)
    Write-Host "`n[2/4] Compactando memoria de procesos (EmptyWorkingSet)..." -ForegroundColor Yellow
    
    # [HACK] Acceso directo a .NET para evitar el overhead de Get-Process (20x más rápido)
    $procs = [System.Diagnostics.Process]::GetProcesses()
    $emptied = 0
    $threshold = 10MB # Umbral más bajo para mayor efectividad

    foreach ($proc in $procs) {
        try {
            # Solo intentamos limpiar si usa más de 10MB para no perder tiempo en micro-procesos
            if ($proc.WorkingSet64 -gt $threshold) {
                [WinAPI.Memory]::EmptyWorkingSet($proc.Handle) | Out-Null
                $emptied++
            }
        } catch {
            # Los procesos de sistema protegidos o zombies fallarán (es normal)
        }
    }
    Write-Host "      ✓ $emptied procesos compactados a nivel de Kernel" -ForegroundColor Green

    # 3. Garbage Collection (.NET Interno)
    Write-Host "`n[3/4] Saneamiento de .NET CLR..." -ForegroundColor Yellow
    [System.GC]::Collect([System.GC]::MaxGeneration, [System.GCCollectionMode]::Forced)
    Write-Host "      ✓ Heap liberado" -ForegroundColor Green

    $afterRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    $freed = [math]::Round(($afterRAM - $beforeRAM) / 1024, 2)
    $global:LastDeepClean = Get-Date

    Write-Host "`n✓ LIMPIEZA COMPLETADA" -ForegroundColor Green
    Write-Host "   RAM liberada: ~$freed MB" -ForegroundColor Gray
    Write-Host "   RAM libre:    $([math]::Round($afterRAM / 1MB, 2)) GB" -ForegroundColor Gray
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] ramollama - Limpieza Máxima
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function ramollama {
    param([switch]$Force)
    if (-not $global:PanopticoEnv.IsAdmin) {
        Write-Host "`n[✗] REQUIERE ADMIN. Abre PowerShell como administrador (Win+X → A)" -ForegroundColor Red
        return
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║   LIMPIEZA MÁXIMA PARA OLLAMA (Deep Learning Mode)   ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    Write-Host "`n⚠️  ADVERTENCIA: Esto puede causar lag temporal (10-20 segundos)" -ForegroundColor Yellow
    Write-Host "    Úsalo solo en sesiones de trabajo largo (4+ horas de IA/Deep Learning)" -ForegroundColor Yellow

    if (-not $Force) {
        $confirm = Read-Host "`n¿Confirmar ejecución? (s/N)"
        if ($confirm -ne 's') {
            Write-Host "[CANCELADO]" -ForegroundColor DarkGray
            return
        }
    }

    $beforeRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory # KB

    # 1. Matar procesos bloatware agresivamente
    Write-Host "`n[1/5] Terminando bloatware (modo agresivo)..." -ForegroundColor Yellow
    $aggressive = "NVIDIA Share", "PhoneExperienceHost", "StartMenuExperienceHost", "TextInputHost", "Widgets", `
                  "MicrosoftEdgeUpdate", "SearchIndexer", "RuntimeBroker", "MicrosoftEdge", "GoogleChrome", "firefox", `
                  "Teams", "Discord", "Spotify", "Calculator", "YourPhone", "OneDrive", "GooglePlayGamesAgent", "EpsonScan2", "node"
    
    $killedProcs = Get-Process -Name $aggressive -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru -ErrorAction SilentlyContinue
    $killedNames = if ($killedProcs) { (@($killedProcs).ProcessName | Select-Object -Unique) -join ", " } else { "Ninguno" }
    Write-Host "      ✓ Procesos terminados: [$killedNames]" -ForegroundColor Green

    # 2. EmptyWorkingSet masivo
    Write-Host "`n[2/5] Vaciando working sets (todos los procesos >100MB)..." -ForegroundColor Yellow
    $processes = Get-Process | Where-Object { $_.WS -gt 100MB }
    $emptied = 0
    foreach ($proc in $processes) {
        try {
            [WinAPI.Memory]::EmptyWorkingSet($proc.Handle) | Out-Null
            $emptied++
        } catch { }
    }
    Write-Host "      ✓ $emptied procesos optimizados" -ForegroundColor Green

    # 3. Garbage Collection máximo
    Write-Host "`n[3/5] Garbage Collection máximo (.NET)..." -ForegroundColor Yellow
    for ($i = 0; $i -lt 3; $i++) {
        [System.GC]::Collect([System.GC]::MaxGeneration, [System.GCCollectionMode]::Aggressive)
        [System.GC]::WaitForPendingFinalizers()
    }
    Write-Host "      ✓ Memoria liberada (ciclos: 3)" -ForegroundColor Green

    # 4. Limpiar Jupyter kernels fantasma
    Write-Host "`n[4/5] Deteniendo kernels Python/Jupyter huérfanos..." -ForegroundColor Yellow
    Get-Process -Name "python" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*ipykernel*" } | 
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "      ✓ Kernels eliminados" -ForegroundColor Green

    $afterRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory # KB
    $freed = [math]::Round(($afterRAM - $beforeRAM) / 1024, 2)

    Write-Host "`n✓ LIMPIEZA MÁXIMA COMPLETADA" -ForegroundColor Magenta
    Write-Host "   RAM liberada: ~$freed MB" -ForegroundColor Gray
    Write-Host "   RAM libre ahora: $([math]::Round($afterRAM / 1MB, 2)) GB (máximo disponible)" -ForegroundColor Gray
    Write-Host "   Procesos optimizados: $emptied" -ForegroundColor Gray
    Write-Host "`n   ⚠️  Sistema se encuentra en modo inmersivo, focalizando recursos hacia aplicaciones seleccionadas." -ForegroundColor Yellow
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] purga - Saneamiento del Sistema Operativo
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function purga {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        SANEAMIENTO INTEGRAL DEL SISTEMA              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # DNS Flush
    Write-Host "`n[→] DNS cache flush..." -ForegroundColor Yellow
    ipconfig /flushdns > $null 2>&1
    Write-Host "    [+] DNS limpio" -ForegroundColor Green

    # Ollama Logs
    Write-Host "`n[→] Limpiando Ollama logs..." -ForegroundColor Yellow
    $logDir = "$env:TEMP"
    $maxLogsKeep = 3
    $ollamaLogs = Get-Item "$logDir\ollama_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($ollamaLogs) {
        $toDelete = $ollamaLogs | Select-Object -Skip $maxLogsKeep
        if ($toDelete) {
            $deletedSize = ($toDelete | Measure-Object -Property Length -Sum).Sum / 1MB
            $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "    [+] Logs: $($toDelete.Count) eliminados ($([math]::Round($deletedSize, 2)) MB)" -ForegroundColor Green
        } else {
            Write-Host "    [+] Logs: dentro del límite" -ForegroundColor Green
        }
    }

    # User History
    Write-Host "`n[→] Eliminando historial de usuario..." -ForegroundColor Yellow
    $historyFiles = @("$HOME\.python_history", "$HOME\.bash_history", "$HOME\.node_repl_history")
    $historyDeleted = 0
    foreach ($file in $historyFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            $historyDeleted++
        }
    }
    Write-Host "    [+] Historial: $historyDeleted archivos eliminados" -ForegroundColor Green

    # Temp Files
    Write-Host "`n[→] Limpiando Temporales..." -ForegroundColor Yellow
    $tempPaths = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "    [+] Temporales limpiados" -ForegroundColor Green

    # WER
    Write-Host "`n[→] Limpiando reportes de Windows (WER)..." -ForegroundColor Yellow
    $werPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
    if (Test-Path $werPath) {
        Remove-Item "$werPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    [+] WER limpio" -ForegroundColor Green
    }

    # Recycle Bin
    Write-Host "`n[→] Vaciando Recycle Bin..." -ForegroundColor Yellow
    Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "    [+] Recycle Bin vacío" -ForegroundColor Green

    Write-Host "`n✓ SISTEMA OPERATIVO PURGADO COMPLETAMENTE" -ForegroundColor Green
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] purgap - Purga de Entorno de Datos
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function purgap {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       PURGA PROFUNDA DE ENTORNO DE DATOS             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Matar Jupyter kernels
    Write-Host "`n[→] Deteniendo motores de ejecución huérfanos..." -ForegroundColor Yellow
    Get-Process python -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*ipykernel*" } | 
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "    [+] Kernels eliminados" -ForegroundColor Green

    # Conda Clean
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        Write-Host "`n[→] Ejecutando Conda Clean (Deep Mode)..." -ForegroundColor Yellow
        conda clean --all --yes --quiet
        Write-Host "    [+] Conda saneado" -ForegroundColor Green
    }

    # Jupyter Runtime
    Write-Host "`n[→] Limpiando Jupyter runtime..." -ForegroundColor Yellow
    $jupyterRuntime = "$env:APPDATA\jupyter\runtime"
    if (Test-Path $jupyterRuntime) {
        Remove-Item "$jupyterRuntime\*" -Include *.json,*.html -Force -ErrorAction SilentlyContinue
        Write-Host "    [+] Runtime de Jupyter despejado" -ForegroundColor Green
    }

    # PIP Cache
    Write-Host "`n[→] Vaciando caché de PIP..." -ForegroundColor Yellow
    pip cache purge 2>$null
    Write-Host "    [+] PIP cache limpiado" -ForegroundColor Green

    Write-Host "`n✓ ENTORNO DE DATOS PURGADO (Cristalino)" -ForegroundColor Green
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] focalizar - CPU Boost
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function focalizar {
    param(
        [switch]$IsolateOllama
    )

    if (-not $global:PanopticoEnv.IsAdmin) {
        Write-Host "`n[✗] REQUIERE ADMIN. Abre PowerShell como administrador (Win+X → A)" -ForegroundColor Red
        return
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║     FOCALIZAR: Optimización de CPU (Priority Boost)    ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

    $cpuInfo = Get-WmiObject Win32_Processor | Select-Object -First 1
    $cores = $cpuInfo.NumberOfLogicalProcessors
    $freq = [math]::Round($cpuInfo.MaxClockSpeed / 1000, 1)

    Write-Host "`n[i] CPU Detectada: $cores cores @ $freq GHz" -ForegroundColor Gray

    if ($IsolateOllama) {
        Write-Host "`n[→] MODO AISLAMIENTO: Cores Exclusivos para Ollama" -ForegroundColor Magenta
        Write-Host "    Asignando $([math]::Round($cores/2)) cores a Ollama..." -ForegroundColor Yellow

        $ollamaProcs = Get-Process -Name ollama -ErrorAction SilentlyContinue
        if ($ollamaProcs) {
            foreach ($proc in @($ollamaProcs)) {
                try {
                    $proc.ProcessorAffinity = [IntPtr]([math]::Pow(2, [math]::Round($cores/2)) - 1)
                    Write-Host "    ✓ PID $($proc.Id) focalizado" -ForegroundColor Green
                } catch {
                    Write-Host "    ✗ Error focalizando PID $($proc.Id)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "    ⚠️  Ollama no está en ejecución" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[→] MODO PRIORIDAD: Elevando clase de procesos VIP..." -ForegroundColor Yellow
        $vipProcs = "ollama", "python", "jupyter", "brave", "excel", "nvda", "code"
        Write-Host "    Targets: $vipProcs" -ForegroundColor DarkGray
        $boostedNames = @()
        Get-Process -Name $vipProcs -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $_.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                $boostedNames += $_.ProcessName
            } catch { }
        }
        $boostedList = if ($boostedNames) { ($boostedNames | Select-Object -Unique) -join ", " } else { "Ninguno" }
        Write-Host "    ✓ Procesos boosteados (High Priority): [$boostedList]" -ForegroundColor Green
    }

    Write-Host "`n✓ CPU OPTIMIZADA PARA ENFOQUE" -ForegroundColor Yellow
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [KERNEL] Motor de Hibernación Unificado (Refactorizado)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Invoke-PanopticoHibernate {
    param(
        [Parameter(Mandatory)] [array]$Targets,
        [Parameter(Mandatory)] [string]$PhaseName
    )

    $beforeRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    Write-Host "`n[→] Ejecutando Hibernación Fase: $PhaseName..." -ForegroundColor Yellow
    
    # [SAFEGUARD] LISTA BLANCA DE PRODUCCIÓN (NO TOCAR JAMÁS)
    $VitalServices = @("ClickToRunSvc", "Dhcp", "Dnscache", "LanmanWorkstation") 
    # Nota: Spooler se mantiene en hiber3, pero si decides protegerlo, agrégalo aquí.
    # ClickToRunSvc es el motor de Office/Excel.

    $hibernated = @()

    foreach ($t in $Targets) {
        # VERIFICACIÓN DE SEGURIDAD
        if ($VitalServices -contains $t.Name) {
            Write-Host "   [ESCUDO] Saltando servicio crítico: $($t.Name)" -ForegroundColor Cyan
            continue
        }

        # --- TIPO: SERVICIO ---
        if ($t.Type -eq "Service" -or $null -eq $t.Type) {
            $svc = Get-Service -Name $t.Name -ErrorAction SilentlyContinue
            if ($svc) {
                # Snapshot (Guardar estado original)
                if (-not $global:ServiceSnapshot.ContainsKey($t.Name)) {
                    $global:ServiceSnapshot[$t.Name] = @{
                        Status = $svc.Status
                        StartType = $svc.StartType
                        Timestamp = Get-Date
                        Phase = $PhaseName
                    }
                }
                # Acción
                try {
                    Set-Service -Name $t.Name -StartupType Disabled -ErrorAction Stop
                    Stop-Service -Name $t.Name -Force -ErrorAction Stop
                    Write-Host "   ✓ $($t.Name) → Hibernado" -ForegroundColor Green
                    $hibernated += $t.Name
                } catch {
                    Write-Host "   ⚠ $($t.Name) → Falló: $($_.Exception.Message)" -ForegroundColor DarkYellow
                }
            } else {
                Write-Host "   ⊗ $($t.Name) → No encontrado" -ForegroundColor DarkGray
            }
        }
        
        # --- TIPO: TAREA PROGRAMADA ---
        elseif ($t.Type -eq "Task") {
            try {
                $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
                if ($task -and $task.State -ne "Disabled") {
                    Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                    Write-Host "   ✓ Tarea: $($t.Name) → Deshabilitada" -ForegroundColor Green
                    $hibernated += "TASK::$($t.Name)"
                    
                    $global:ServiceSnapshot["TASK::$($t.Name)"] = @{ Status = "Enabled"; StartType = "Task"; Timestamp = Get-Date; Phase = $PhaseName }
                }
            } catch { Write-Host "   ⚠ Tarea: $($t.Name) → Error" -ForegroundColor DarkYellow }
        }
    }

    $afterRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    $freed = [math]::Round(($afterRAM - $beforeRAM) / 1024, 2)

    # Logging
    $logEntry = [PSCustomObject]@{ Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Function = "hiber-$PhaseName"; Services = ($hibernated -join ", "); Status = "Completado"; RAMFreed_MB = $freed; RebootRequired = $false }
    $global:HibernationLog += $logEntry
    $logEntry | Export-Csv -Path $global:HibernationLogPath -Append -NoTypeInformation -Force

    Write-Host "`n✓ FASE $PhaseName COMPLETADA" -ForegroundColor Green
    Write-Host "   Objetivos hibernados: $($hibernated.Count)" -ForegroundColor Gray
    Write-Host "   RAM liberada: ~$freed MB" -ForegroundColor Gray
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] hiber1 - Telemetría Microsoft (Nivel 1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function hiber1 {
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Host "`n[✗] REQUIERE ADMIN." -ForegroundColor Red; return }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   HIBER-1: Telemetría Microsoft (Recupera ~200MB)    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Targets validados (telemetría MS oficial)
    $targets = @(
        @{Name="DiagTrack"; Desc="Connected User Experiences and Telemetry"},
        @{Name="diagnosticshub.standardcollector.service"; Desc="Microsoft Diagnostics Hub Standard Collector"},
        @{Name="dmwappushservice"; Desc="WAP Push Message Routing Service"},
        @{Name="WerSvc"; Desc="Windows Error Reporting Service"},
        @{Name="DusmSvc"; Desc="Data Usage (Uso de datos)"},
        @{Name="gupdate"; Desc="Google Update Service"},
        @{Name="gupdatem"; Desc="Google Update Service (Manual)"},
        @{Name="bdvpnService"; Desc="Bitdefender VPN Service"},
        @{Type="Service"; Name="EpsonScanSvc"; Desc="Epson Scanner Service"},
        @{Type="Task"; Name="*GooglePlayGames*"; Desc="Google Play Games Task"},
        @{Type="Service"; Name="OneSyncSvc"; Desc="Sync Host (OneDrive)"},
        @{Type="Service"; Name="DoSvc"; Desc="Delivery Optimization (WUDO - Port 7680)"},
        @{Type="Service"; Name="MapsBroker"; Desc="Downloaded Maps Manager"},
        @{Type="Service"; Name="CDPSvc"; Desc="Connected Devices Platform (Port 5040)"}
    )

    Invoke-PanopticoHibernate -Targets $targets -PhaseName "Light"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] hiber2 - OEM Bloatware (Nivel 2)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function hiber2 {
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Host "`n[✗] REQUIERE ADMIN." -ForegroundColor Red; return }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║   HIBER-2: Servicios Auxiliares (OEM y Terceros)     ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    $targets = @(
        @{Type="Service"; Name="LenovoVantageService"; Desc="Lenovo Vantage Service"},
        @{Type="Service"; Name="Lenovo.Modern.ImController"; Desc="Lenovo IM Controller"},
        @{Type="Service"; Name="CorsairService"; Desc="Corsair Gaming Audio Configuration"},
        @{Type="Service"; Name="AdobeARMservice"; Desc="Adobe Acrobat Update Service"},
        @{Type="Service"; Name="BraveElevationService"; Desc="Brave Update Service"},
        @{Type="Service"; Name="BraveUpdate"; Desc="Brave Update Service (Main)"},
        @{Type="Service"; Name="BraveUpdatem"; Desc="Brave Update Service (Manual)"},
        @{Type="Service"; Name="BraveVpnService"; Desc="Brave VPN Service"},
        @{Type="Service"; Name="TeamViewer"; Desc="TeamViewer Remote"},
        @{Type="Service"; Name="AnyDesk"; Desc="AnyDesk Service"}
    )

    Invoke-PanopticoHibernate -Targets $targets -PhaseName "Terceros"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] hiber3 - Modo Deep Work (Nivel 3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function hiber3 {
    if (-not $global:PanopticoEnv.IsAdmin) { Write-Host "`n[✗] REQUIERE ADMIN." -ForegroundColor Red; return }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║   HIBER-3: DEEP WORK (Indexador, Spooler, SysMain)   ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host "    [!] Desactiva búsqueda de Windows e impresión." -ForegroundColor Yellow

    $targets = @(
        @{Type="Service"; Name="WSearch"; Desc="Windows Search (Indexador)"},
        @{Type="Service"; Name="Spooler"; Desc="Print Spooler (Impresora)"},
        @{Type="Service"; Name="SysMain"; Desc="Superfetch (SysMain)"},
        @{Type="Service"; Name="Themes"; Desc="Temas de Windows"},
        @{Type="Service"; Name="TabletInputService"; Desc="Touch Keyboard"},
        @{Type="Service"; Name="WbioSrvc"; Desc="Windows Biometric Service"},
        @{Type="Service"; Name="Stisvc"; Desc="Windows Image Acquisition (Scanner)"}
    )

    Invoke-PanopticoHibernate -Targets $targets -PhaseName "DeepWork"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] verseguridad - Auditoría de Seguridad
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function verseguridad {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   PANÓPTICO - AUDITORÍA DE SEGURIDAD (Solo Lectura)      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # 1. Antivirus & EDR
    Write-Host "`n[1] Motores de Seguridad (Servicios)" -ForegroundColor Yellow
    $avServices = @("WinDefend", "bdagent", "bdvpnService", "BDAuxSrv", "BDProtSrv", "Sense", "SgrmBroker", "WdNisSvc")
    $found = $false
    foreach ($svcName in $avServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $found = $true
            $color = if ($svc.Status -eq 'Running') { "Green" } else { "DarkGray" }
            Write-Host "   → $($svc.DisplayName) [$($svc.Name)]: $($svc.Status)" -ForegroundColor $color
        }
    }
    if (-not $found) { Write-Host "   (No se detectaron servicios estándar)" -ForegroundColor DarkGray }

    # 2. Firewall
    Write-Host "`n[2] Firewall de Windows" -ForegroundColor Yellow
    try {
        Get-NetFirewallProfile | Select-Object Name, Enabled | ForEach-Object {
            $status = if ($_.Enabled) { "ACTIVO" } else { "INACTIVO" }
            $color = if ($_.Enabled) { "Green" } else { "Red" }
            Write-Host "   → Perfil $($_.Name): $status" -ForegroundColor $color
        }
    } catch {
        Write-Host "   (No disponible)" -ForegroundColor DarkGray
    }

    # 3. Exposición de Red (Listening Ports)
    Write-Host "`n[3] Puertos en Escucha (Check 0.0.0.0)" -ForegroundColor Yellow
    try {
        $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | 
                     Select-Object LocalAddress, LocalPort, OwningProcess -Unique | 
                     Sort-Object LocalPort

        if ($listening) {
            $listening | Select-Object -First 10 | ForEach-Object {
                $pName = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
                if (-not $pName) { $pName = "System/Unknown" }
                
                # Alerta visual si expone a toda la red (0.0.0.0)
                $bindColor = if ($_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "::") { "Red" } else { "Green" }
                Write-Host "   → [$($_.LocalAddress)]:$($_.LocalPort) ($pName)" -ForegroundColor $bindColor
            }
            if ($listening.Count -gt 10) { Write-Host "   ... y $($listening.Count - 10) más." -ForegroundColor DarkGray }
        }
    } catch { Write-Host "   (Requiere elevación)" -ForegroundColor DarkGray }

    # 4. Integridad Hosts
    Write-Host "`n[4] Archivo Hosts" -ForegroundColor Yellow
    $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
    if (Test-Path $hosts) {
        $lines = Get-Content $hosts -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch "^\s*#" -and $_.Trim().Length -gt 0 }
        Write-Host "   → Entradas activas: $($lines.Count)" -ForegroundColor Gray
    }

    # 5. Estado de Usuario
    Write-Host "`n[5] Contexto de Usuario" -ForegroundColor Yellow
    $u = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]$u
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Host "   → Usuario: $($u.Name)" -ForegroundColor Gray
    Write-Host "   → Privilegios Admin: $(if($isAdmin){'SÍ'}else{'NO'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] hiberstatus - Auditoría de Cambios
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function hiberstatus {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   HIBER-STATUS: Auditoría de Servicios                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    if ($global:HibernationLog.Count -eq 0) {
        Write-Host "`n[i] No hay operaciones de hibernación registradas en esta sesión." -ForegroundColor DarkGray
        
        # Intentar leer log persistente
        if (Test-Path $global:HibernationLogPath) {
            Write-Host "   Leyendo log persistente de archivo..." -ForegroundColor Yellow
            $persistentLog = Import-Csv -Path $global:HibernationLogPath
            $persistentLog | Format-Table -AutoSize
        } else {
            Write-Host "   No existe log persistente tampoco." -ForegroundColor DarkGray
        }
        return
    }

    Write-Host "`n[Log de Sesión Actual]" -ForegroundColor Yellow
    $global:HibernationLog | Format-Table -AutoSize

    Write-Host "`n[Servicios en Snapshot (Reversibles)]" -ForegroundColor Yellow
    $global:ServiceSnapshot.GetEnumerator() | ForEach-Object {
        Write-Host "   → $($_.Key): $($_.Value.Status) (Fase: $($_.Value.Phase))" -ForegroundColor Gray
    }

    Write-Host "`n[i] Log persistente guardado en:" -ForegroundColor DarkGray
    Write-Host "    $global:HibernationLogPath" -ForegroundColor DarkGray
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] reversahiber - Rollback de Cambios
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function reversahiber {
    [CmdletBinding()]
    param(
        [ValidateSet("Light", "Terceros", "DeepWork", "All")]
        [string]$Phase = "All"
    )

    if (-not $global:PanopticoEnv.IsAdmin) {
        Write-Host "`n[✗] REQUIERE ADMIN. (Win+X → A)" -ForegroundColor Red
        return
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   REVERSA-HIBER: Restaurando Servicios               ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green

    $beforeRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory

    if ($global:ServiceSnapshot.Count -eq 0) {
        Write-Host "`n[i] Snapshot de sesión vacío. Se procederá a verificación de integridad." -ForegroundColor DarkGray
    }

    Write-Host "`n[→] Revirtiendo cambios de Fase: $Phase..." -ForegroundColor Yellow

    $reverted = @()
    foreach ($entry in $global:ServiceSnapshot.GetEnumerator()) {
        $name = $entry.Key
        $snapshot = $entry.Value

        # Filtrar por fase si no es "All"
        if ($Phase -ne "All" -and $snapshot.Phase -ne $Phase) {
            continue
        }

        Write-Host "   → Revirtiendo: $name (Fase: $($snapshot.Phase))" -ForegroundColor Cyan

        # Caso especial: Exclusiones de Defender
        if ($name -eq "DefenderExclusions") {
            foreach ($path in $snapshot.Paths) {
                try {
                    Remove-MpPreference -ExclusionPath $path -ErrorAction Stop
                    Write-Host "      ✓ Exclusión removida: $path" -ForegroundColor Green
                } catch {
                    Write-Host "      ⚠ Falló remover: $path" -ForegroundColor DarkYellow
                }
            }
            $reverted += $name
            continue
        }

        # Caso especial: Registry de Defender
        if ($name -eq "WinDefend_Registry") {
            try {
                Remove-ItemProperty -Path $snapshot.RegPath -Name "DisableAntiSpyware" -ErrorAction Stop
                Write-Host "      ✓ Registro revertido (DisableAntiSpyware removido)" -ForegroundColor Green
                Write-Host "      ⚠ REBOOT REQUERIDO para aplicar" -ForegroundColor Yellow
            } catch {
                Write-Host "      ⚠ Falló revertir Registry" -ForegroundColor DarkYellow
            }
            $reverted += $name
            continue
        }

        # Caso especial: Task Scheduler (Detectado por prefijo TASK::)
        if ($name -like "TASK::*") {
            $realTaskName = $name -replace "TASK::",""
            try {
                $task = Get-ScheduledTask -TaskName $realTaskName -ErrorAction SilentlyContinue
                if ($task -and $task.State -eq "Disabled") {
                    Enable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                    Write-Host "      ✓ Task reactivada: $realTaskName" -ForegroundColor Green
                }
            } catch {
                Write-Host "      ⚠ Falló reactivar Task: $realTaskName" -ForegroundColor DarkYellow
            }
            $reverted += $name
            continue
        }

        # Servicios estándar
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Set-Service -Name $name -StartupType $snapshot.StartType -ErrorAction Stop
                if ($snapshot.Status -eq "Running") {
                    Start-Service -Name $name -ErrorAction Stop
                }
                Write-Host "      ✓ Servicio revertido: $name ($($snapshot.StartType), $($snapshot.Status))" -ForegroundColor Green
                $reverted += $name
            } catch {
                Write-Host "      ⚠ Falló revertir: $name" -ForegroundColor DarkYellow
            }
        }
    }

    # Limpiar snapshot de servicios revertidos
    if ($Phase -eq "All") {
        $global:ServiceSnapshot.Clear()
    } else {
        $toRemove = $global:ServiceSnapshot.GetEnumerator() | Where-Object {$_.Value.Phase -eq $Phase} | ForEach-Object {$_.Key}
        foreach ($key in $toRemove) {
            $global:ServiceSnapshot.Remove($key)
        }
    }

    # [INTEGRIDAD] Verificar Office (Solicitud de usuario)
    $officeSvc = Get-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue
    if ($officeSvc -and $officeSvc.Status -ne "Running") {
        Write-Host "   [!] ALERTA: Motor Office apagado. Reactivando..." -ForegroundColor Yellow
        Set-Service -Name "ClickToRunSvc" -StartupType Automatic
        Start-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue
    }

    $afterRAM = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    $consumed = [math]::Round(($beforeRAM - $afterRAM) / 1024, 2)

    # Logging
    $logEntry = [PSCustomObject]@{ Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Function = "reverter-hibernacion [$Phase]"; Services = ($reverted -join ", "); Status = "Revertido"; RAMFreed_MB = "N/A"; RebootRequired = ($Phase -eq "Antivirus-Defender") }
    $global:HibernationLog += $logEntry
    $logEntry | Export-Csv -Path $global:HibernationLogPath -Append -NoTypeInformation

    Write-Host "`n✓ REVERSIÓN COMPLETADA" -ForegroundColor Green
    Write-Host "   Servicios revertidos: $($reverted.Count) ([$($reverted -join ', ')])" -ForegroundColor Gray
    Write-Host "   Recursos re-ocupados (RAM): ~$consumed MB" -ForegroundColor Yellow
    if ($Phase -eq "Antivirus-Defender") {
        Write-Host "   ⚠ REBOOT REQUERIDO para aplicar cambios de Defender" -ForegroundColor Yellow
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] lab - Jupyter Lab
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function lab {
    $sessionStart = Get-Date
    $logPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", ".session_logs.txt")

    Write-Host "`n[!] Sesión Formativa Bootcamp Iniciada: $($sessionStart.ToString('HH:mm:ss'))" -ForegroundColor Yellow
    conda activate bootcamp 2>$null

    $workDir = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "1FORMA~1")
    if (Test-Path $workDir) {
        Set-Location $workDir
        Write-Host "[>] Lanzando Jupyter Lab..." -ForegroundColor Cyan
        jupyter lab

        $sessionEnd = Get-Date
        $duration = $sessionEnd - $sessionStart
        $logEntry = "$($sessionStart.ToString('yyyy-MM-dd HH:mm')) | Duración: $($duration.Minutes) min $($duration.Seconds) seg"
        $logEntry | Out-File -FilePath $logPath -Append
        Write-Host "`n[!] Sesión finalizada. Tiempo: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Green
    } else {
        Write-Host "[Error] Carpeta de trabajo no encontrada." -ForegroundColor Red
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] ollama - LLM Daemon (Debug/Prod modes)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function ollama {
    param(
        [ValidateSet("start","stop","status","debug-on","debug-off","logs")]
        [string]$Action = "status"
    )

    switch ($Action) {
        "debug-on" {
            $global:OllamaDebugMode = $true
            Write-Host "`n[+] DEBUG MODE ACTIVADO para Ollama" -ForegroundColor Magenta
            Write-Host "    El próximo 'ollama start' usará OLLAMA_DEBUG=1 y mostrará logs completos." -ForegroundColor DarkGray
        }

        "debug-off" {
            $global:OllamaDebugMode = $false
            Write-Host "`n[+] MODO PRODUCCIÓN ACTIVADO para Ollama" -ForegroundColor Green
            Write-Host "    El próximo 'ollama start' será silencioso (logs suprimidos)." -ForegroundColor DarkGray
        }

        "start" {
            if ($global:OllamaJob -and (Get-Job -Id $global:OllamaJob.Id -ErrorAction SilentlyContinue)) {
                Write-Host "`n[!] Ollama ya activo (Job ID: $($global:OllamaJob.Id))" -ForegroundColor Yellow
                return
            }

            if ($global:OllamaJob) {
                try { Remove-Job -Id $global:OllamaJob.Id -Force -ErrorAction SilentlyContinue } catch { }
                $global:OllamaJob = $null
            }

            $logFile = "$env:TEMP\ollama_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            $modeText = if ($global:OllamaDebugMode) { "DEBUG" } else { "PRODUCCIÓN" }

            Write-Host "`n[*] Iniciando Ollama en modo $modeText..." -ForegroundColor Cyan

            $global:OllamaJob = Start-ThreadJob {
                $env:OLLAMA_HOST = "127.0.0.1:11434"
                $env:OLLAMA_ORIGINS = "chrome-extension://*"
                $env:OLLAMA_KEEP_ALIVE = "24h"
                $env:CUDA_VISIBLE_DEVICES = "0"

                if ($using:OllamaDebugMode) { $env:OLLAMA_DEBUG = "1" }

                Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2

                ollama serve 2>&1 | Tee-Object -FilePath $using:logFile
            }

            Start-Sleep -Seconds 3
            Write-Host "[+] Ollama daemon activo (Job ID: $($global:OllamaJob.Id))" -ForegroundColor Green
            Write-Host "    Log: $logFile" -ForegroundColor DarkGray
        }

        "logs" {
            $logFile = Get-Item "$env:TEMP\ollama_*.log" -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1 -ExpandProperty FullName

            if (-not $logFile) {
                Write-Host "`n[!] Sin archivos de log encontrados." -ForegroundColor Red
                return
            }

            Write-Host "`n[*] Log file: $logFile" -ForegroundColor Cyan
            Write-Host "    (Ctrl+C para salir)" -ForegroundColor DarkGray
            Write-Host "────────────────────────────────────────────────────────" -ForegroundColor DarkGray

            Get-Content -Path $logFile -Tail 50 -Wait -Encoding UTF8
        }

        "stop" {
            Write-Host "`n[*] Deteniendo Ollama..." -ForegroundColor Yellow

            if ($global:OllamaJob) {
                Write-Host "  > Deteniendo ThreadJob (ID: $($global:OllamaJob.Id))..." -ForegroundColor DarkGray
                try {
                    $global:OllamaJob | Stop-Job -PassThru -ErrorAction Stop | Remove-Job -Force
                    Write-Host "    [+] ThreadJob eliminado" -ForegroundColor Green
                } catch {
                    Write-Host "    [!] Error deteniendo job: $_" -ForegroundColor Yellow
                }
                $global:OllamaJob = $null
            }

            Write-Host "  > Buscando procesos huérfanos (ollama.exe)..." -ForegroundColor DarkGray

            $ollamaProcs = Get-Process -Name ollama -ErrorAction SilentlyContinue
            if ($ollamaProcs) {
                $procCount = if ($ollamaProcs -is [array]) { $ollamaProcs.Count } else { 1 }
                Write-Host "    [!] $procCount proceso(s) encontrado(s)" -ForegroundColor Yellow

                foreach ($proc in @($ollamaProcs)) {
                    Write-Host "      - PID: $($proc.Id), RAM: $([math]::Round($proc.WS/1MB, 2)) MB" -ForegroundColor DarkGray
                    try {
                        Stop-Process -InputObject $proc -Force -ErrorAction Stop
                        Write-Host "        [✓] Eliminado" -ForegroundColor Green
                    } catch {
                        Write-Host "        [✗] Error: $_" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "    [+] Sin procesos ollama activos" -ForegroundColor Green
            }

            Write-Host "`n[+] Ollama completamente detenido." -ForegroundColor Green
        }

        "status" {
            # ✅ v2.1: Validar que el job aún existe
            if ($global:OllamaJob -and -not (Get-Job -Id $global:OllamaJob.Id -ErrorAction SilentlyContinue)) {
                $global:OllamaJob = $null
            }

            if (-not $global:OllamaJob) {
                Write-Host "`n[🔴] Ollama: INACTIVO (sin job)" -ForegroundColor Red
                $proc = Get-Process -Name ollama -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "     ⚠️  Proceso huérfano detectado (PID: $($proc.Id))" -ForegroundColor Yellow
                }
                return
            }

            $jobState = $global:OllamaJob.State
            $modeText = if ($global:OllamaDebugMode) { "DEBUG" } else { "PRODUCCIÓN" }

            $isReachable = $false
            try {
                $test = Test-NetConnection -ComputerName 127.0.0.1 -Port 11434 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                $isReachable = $test.TcpTestSucceeded
            } catch { }

            $statusText = if ($isReachable) { "🟢 ACTIVO" } else { "🟡 CORRIENDO (sin respuesta HTTP)" }
            $statusColor = if ($isReachable) { "Green" } else { "Yellow" }
            $modeColor = if ($global:OllamaDebugMode) { "Magenta" } else { "White" }

            Write-Host "`nOllama Status:" -ForegroundColor Cyan
            Write-Host "  State:    $statusText" -ForegroundColor $statusColor
            Write-Host "  Job:      $jobState (ID: $($global:OllamaJob.Id))" -ForegroundColor Gray
            Write-Host "  Mode:     $modeText" -ForegroundColor $modeColor
            Write-Host "  Endpoint: http://127.0.0.1:11434" -ForegroundColor DarkGray
        }
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [FUNC] pan - Menú Arsenal
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function pan {
    Clear-Host
    Write-Host "   A1    ARSENAL DE COMANDOS v2.2                                                   " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host "   _________________________________________________________________________________" -ForegroundColor Black -BackgroundColor Cyan
    Write-Host "   A2  | COMANDO        | DESCRIPCION                                               " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host "   ----|----------------|-----------------------------------------------------------" -ForegroundColor Black -BackgroundColor Cyan
    
    $i = 3
    $Arsenal.Keys | ForEach-Object {
        $command = $_
        $details = $Arsenal[$command]
        $rowID = "A$i"
        
        $desc = $details.Description
        if ($desc.Length -lt 58) { $desc = $desc.PadRight(58) }
        Write-Host ("   {0,-3} | {1,-14} | {2}" -f $rowID, $command, $desc) -ForegroundColor Black -BackgroundColor Cyan
        $i++
    }
    Write-Host "   _________________________________________________________________________________" -ForegroundColor Black -BackgroundColor Cyan

    Write-Host "`n   [FLUJOS DE TRABAJO RECOMENDADOS]                                                 " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host "   A$i.. " -NoNewline -ForegroundColor Cyan; Write-Host "MODO WEB (Brave/Docs)   " -NoNewline -ForegroundColor Gray; Write-Host ": hiber1" -ForegroundColor Gray; $i++
    Write-Host "   A$i.. " -NoNewline -ForegroundColor Cyan; Write-Host "MODO DEV (Python/Code)  " -NoNewline -ForegroundColor Gray; Write-Host ": hiber2 + focalizar" -ForegroundColor Gray; $i++
    Write-Host "   A$i.. " -NoNewline -ForegroundColor Cyan; Write-Host "MODO LLM (Ollama/Local) " -NoNewline -ForegroundColor Gray; Write-Host ": hiber3 + ramollama + focalizar -IsolateOllama" -ForegroundColor Gray; $i++
    Write-Host "   A$i.. " -NoNewline -ForegroundColor Cyan; Write-Host "RESTAURAR TODO          " -NoNewline -ForegroundColor Gray; Write-Host ": reversahiber" -ForegroundColor Gray

    Write-Host "`n   [ATAJOS] c (cls) | e (explorador) | ex (salir) | r (recarga)" -ForegroundColor Yellow
    Write-Host "   [ADMIN]  ram2, ramollama, focalizar, hiber* requieren permisos elevados." -ForegroundColor Red
    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [ATAJOS] Shortcuts de Teclado
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Limpiar colisiones
if (Get-Alias e -ErrorAction SilentlyContinue) { Remove-Item Alias:e -Force }
if (Get-Alias r -ErrorAction SilentlyContinue) { Remove-Item Alias:r -Force }
if (Get-Alias ex -ErrorAction SilentlyContinue) { Remove-Item Alias:ex -Force }

Set-Alias -Name c -Value Clear-Host

function e { explorer . }
function ex { exit }
function r {
    Write-Host "`n[!] Reiniciando PAN v2.2..." -ForegroundColor Magenta
    . $profile
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [INIT] Detección de Ollama Huérfano (Post-Reload)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if (-not $global:OllamaJob -or -not (Get-Job -Id $global:OllamaJob.Id -ErrorAction SilentlyContinue)) {
    $orphan = Get-Process -Name ollama -ErrorAction SilentlyContinue
    if ($orphan) {
        Write-Host "[⚠️  ORPHAN DETECTED] Proceso Ollama PID $($orphan.Id) sin Job asociado" -ForegroundColor Yellow
        Write-Host "    Ejecuta: ollama stop (para limpiarlo)" -ForegroundColor DarkGray
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [OPTIMIZACIÓN] Lazy Loading de Conda... truco rescatadp del foro Ruso eliminado 

# No invocamos conda al inicio. Creamos un wrapper que se auto-destruye y carga el real al usarse.
function Global:conda {
    $condaPath = [System.IO.Path]::Combine($env:USERPROFILE, "anaconda3", "Scripts", "conda.exe")
    $hookCache = "$env:TEMP\conda_hook_cache.ps1"
    
    # 1. Generar caché si no existe
    if (-not (Test-Path $hookCache)) {
        Write-Host "`n[⚡] Generando caché de Conda..." -ForegroundColor Yellow
        if (Test-Path $condaPath) {
            (& $condaPath "shell.powershell" "hook") | Out-File $hookCache -Encoding UTF8 -Force
        }
    }
    
    # 2. Cargar el hook (define la función 'conda' real localmente)
    if (Test-Path $hookCache) {
        . $hookCache
        Write-Host "    ✓ Conda activo." -ForegroundColor Green
        
        # 3. Promocionar la función 'conda' del hook al ámbito Global
        # Esto sobrescribe este wrapper y permite que 'conda activate' funcione correctamente
        Copy-Item Function:\conda Function:\Global:conda -Force
        
        # 4. Ejecutar el comando solicitado con la nueva función
        conda @args
    } else {
        # Fallback si falla el hook
        & $condaPath $args
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [BOOTSTRAP] Información Real
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$startTimer.Stop()
$loadTime = $startTimer.Elapsed.TotalMilliseconds.ToString('F0')

Write-Host "────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " ✓ Sistema Listo | Carga: $($loadTime)ms | Atajos: c, e, ex, r" -ForegroundColor DarkGray
Write-Host "────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# ═══════════════════════════════════════════════════════════
# FIN - PANÓPTICO v2.2
# ═══════════════════════════════════════════════════════════
