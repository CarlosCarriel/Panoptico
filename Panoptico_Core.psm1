# =============================================================
# PANÓPTICO CORE v3.0 - Motor de Optimización Modular
# PowerShell 7.x | Arquitectura Orientada a Objetos
# =============================================================

# [ESTADO] Gestión de Memoria del Módulo (Cero Globales)
$script:State = @{
    ServiceSnapshot = @{}
    HibernationLog  = @()
    Config          = $null
    SessionID       = [Guid]::NewGuid().ToString()
}

# [NÚCLEO] Estado Público (Copia de Solo Lectura)
function Get-PanopticoSnapshot {
    return $script:State.ServiceSnapshot.Clone()
}

# [INVOCACIÓN NATIVA] Firma de API de Memoria (Carga Estática)
if (-not ([System.Management.Automation.PSTypeName]'WinAPI.Memory').Type) {
    $signature = @"
using System;
using System.Runtime.InteropServices;
namespace WinAPI {
    public static class Memory {
        [DllImport("psapi.dll", SetLastError=true)]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);
    }
}
"@
    try {
        Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
    }
    catch { 
        Write-Warning "PanCore: No se pudo cargar WinAPI.Memory. EmptyWorkingSet estará deshabilitado."
    }
}

# [NÚCLEO] Carga de Configuración
function Initialize-PanopticoConfig {
    param([string]$Path = "$PSScriptRoot\config.json")
    
    if (-not (Test-Path $Path)) {
        throw "Configuración no encontrada en $Path"
    }
    
    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        $script:State.Config = $content | ConvertFrom-Json
        Write-Verbose "PanCore: Configuración cargada ($($script:State.Config.Settings.Theme))"
    }
    catch {
        throw "Error al parsear config.json: $($_.Exception.Message)"
    }
    
    # Validar estructura mínima requerida
    $requiredSections = @('Settings', 'Optimization', 'Hibernation', 'Focalizar')
    foreach ($section in $requiredSections) {
        if (-not $script:State.Config.$section) {
            throw "config.json inválido: falta sección obligatoria '$section'"
        }
    }
    
    # Validar subsecciones críticas
    if (-not $script:State.Config.Optimization.Ram1_Targets) {
        throw "config.json inválido: falta 'Optimization.Ram1_Targets'"
    }
    
    return $script:State.Config
}

# [NÚCLEO] Guardar Configuración
function Save-PanopticoConfig {
    param([string]$Path = "$PSScriptRoot\config.json")
    
    if (-not $script:State.Config) { throw "No hay configuración cargada para guardar." }
    
    try {
        $json = $script:State.Config | ConvertTo-Json -Depth 5
        $json | Set-Content -Path $Path -Encoding UTF8 -Force
        Write-Verbose "PanCore: Configuración guardada en $Path"
        return $true
    }
    catch {
        throw "Error al guardar config.json: $($_.Exception.Message)"
    }
}

# [NÚCLEO] Servicio de Acción Atómica
function Invoke-ServiceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Target,
        
        [Parameter(Mandatory)]
        [ValidateSet("Hibernate", "Wake")]
        [string]$Action,
        
        [switch]$Simulate
    )

    $result = [PSCustomObject]@{
        Name    = $Target.Name
        Action  = $Action
        Status  = "Pending"
        Message = ""
    }

    # Validación de Seguridad
    if ($script:State.Config) {
        if ($Target.Name -in $script:State.Config.Security.VitalServices) {
            $result.Status = "Skipped"
            $result.Message = "Protected Vital Service"
            return $result
        }
    }

    # Lógica de Ejecución
    $type = if ($Target.Type) { $Target.Type } else { "Service" }

    if ($Action -eq "Hibernate") {
        if ($type -eq "Task") {
            # --- GESTIÓN DE TAREAS (Soporte de Comodines) ---
            if ($Simulate) {
                $result.Status = "Simulated"
                $result.Message = "Desea deshabilitar la Tarea Programada (Pattern: $($Target.Name))"
            }
            else {
                try {
                    $tasks = Get-ScheduledTask -TaskName $Target.Name -ErrorAction SilentlyContinue
                    
                    if ($tasks) {
                        foreach ($t in $tasks) {
                            if ($t.State -ne "Disabled") {
                                Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null
                                
                                # Snapshot Individual
                                $script:State.ServiceSnapshot["TASK::$($t.TaskName)"] = @{
                                    Type      = "Task"
                                    PrevState = "Enabled"
                                    Timestamp = Get-Date
                                }
                            }
                        }
                        $result.Status = "Success"
                        $result.Message = "Tareas desactivadas: $(($tasks).Count)"
                    }
                    else {
                        $result.Status = "Skipped"
                        $result.Message = "Tarea no encontrada o ya deshabilitada"
                    }
                }
                catch {
                    $result.Status = "Error"
                    $result.Message = $_.Exception.Message
                }
            }
        }
        else {
            # --- GESTIÓN DE SERVICIOS ---
            try {
                $svc = Get-Service -Name $Target.Name -ErrorAction SilentlyContinue
                if (-not $svc) {
                    $result.Status = "Skipped"
                    $result.Message = "Servicio no encontrado"
                    return $result
                }

                if ($svc.Status -eq "Stopped" -and $svc.StartType -eq "Disabled") {
                    $result.Status = "Skipped"
                    $result.Message = "Ya hibernado"
                    return $result
                }

                if ($Simulate) {
                    $result.Status = "Simulated"
                    $result.Message = "Detendría y deshabilitaría $($Target.Name)"
                }
                else {
                    # Snapshot
                    if (-not $script:State.ServiceSnapshot.ContainsKey($Target.Name)) {
                        $script:State.ServiceSnapshot[$Target.Name] = @{
                            Type      = "Service"
                            StartType = $svc.StartType
                            Status    = $svc.Status
                            Timestamp = Get-Date
                        }
                    }

                    # Flujo de acción: Deshabilitar → Detener → Esperar
                    Set-Service -Name $Target.Name -StartupType Disabled -ErrorAction Stop
                    
                    if ($svc.Status -ne "Stopped") {
                        Stop-Service -Name $Target.Name -Force -NoWait -ErrorAction Stop
                        
                        # Lógica de reintento del SCM (Esperar hasta 5s)
                        $maxRetries = 10 # 10 * 500ms = 5s
                        $count = 0
                        $stopped = $false
                        
                        while ($count -lt $maxRetries) {
                            $current = Get-Service -Name $Target.Name
                            if ($current.Status -eq "Stopped") {
                                $stopped = $true
                                break
                            }
                            Start-Sleep -Milliseconds 500
                            $count++
                        }
                        
                        if (-not $stopped) {
                            throw "Servicio atascado en $($current.Status) tras 5s"
                        }
                    }
                    
                    $result.Status = "Success"
                }

            }
            catch {
                # Fallback para servicios protegidos (ej. DoSvc) usando SC.exe
                try {
                    $null = & sc.exe config $Target.Name start= disabled
                    if ($LASTEXITCODE -eq 0) {
                        Stop-Service -Name $Target.Name -Force -ErrorAction SilentlyContinue
                        $result.Status = "Success" 
                        $result.Message = "Hibernado (Vía SC.exe)"
                    }
                    else {
                        throw "SC.exe failed"
                    }
                }
                catch {
                    $result.Status = "Error"
                    $result.Message = "Acceso Denied (Ni Admin ni SC pudieron tocarlo)"
                }
            }
        }
    } 
    elseif ($Action -eq "Wake") {
        # --- RESTORE FIEL (State-Aware) ---
        $svcName = $Target.Name
        $snapshotEntry = $script:State.ServiceSnapshot[$svcName]
        
        # Determinar estado deseado (Snapshot o Default conservador)
        $targetStartType = if ($snapshotEntry -and $snapshotEntry.PrevStartType) { 
            $snapshotEntry.PrevStartType 
        }
        else { 
            "Automatic" 
        }
        
        $targetStatus = if ($snapshotEntry -and $snapshotEntry.PrevStatus) { 
            $snapshotEntry.PrevStatus 
        }
        else { 
            "Stopped"  # Conservador: no iniciar si no hay snapshot
        }
        
        Write-Verbose "Wake: $svcName → StartType:$targetStartType (Estado previo: $targetStatus)"

        $repaired = $false

        # 1. Cmdlet (Preferido)
        try {
            Set-Service -Name $svcName -StartupType $targetStartType -ErrorAction Stop
            $repaired = $true
        }
        catch {
            # 2. Registro (Fallback)
            try {
                $regStart = switch ($targetStartType) { 
                    "Automatic" { 2 } 
                    "Manual" { 3 } 
                    "Disabled" { 4 } 
                    default { 2 } 
                }
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
                Set-ItemProperty -Path $regPath -Name 'Start' -Value $regStart -ErrorAction Stop
                $repaired = $true
            }
            catch { }
        }

        # 3. SC.exe (Nuclear fallback)
        if (-not $repaired) {
            $scMode = switch ($targetStartType) { 
                "Automatic" { "auto" } 
                "Manual" { "demand" } 
                "Disabled" { "disabled" } 
                default { "auto" } 
            }
            $null = & sc.exe config $svcName start= $scMode
            if ($LASTEXITCODE -eq 0) { $repaired = $true }
        }

        # Iniciar SOLO si estaba Running
        if ($targetStatus -eq "Running") {
            # Iniciar dependencias primero
            try {
                $svcObj = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                if ($svcObj.ServicesDependedOn) {
                    foreach ($d in $svcObj.ServicesDependedOn) {
                        Start-Service -Name $d.Name -ErrorAction SilentlyContinue
                    }
                }
            }
            catch {}

            # Iniciar servicio objetivo con reintentos
            $started = $false
            $retry = 0
            while ($retry -lt 3 -and -not $started) {
                try {
                    Start-Service -Name $svcName -ErrorAction Stop
                    $started = $true
                    $result.Status = "Success"
                    $result.Message = "Restaurado ($targetStartType) e Iniciado"
                }
                catch {
                    $retry++
                    Start-Sleep -Milliseconds 500
                }
            }
            
            if (-not $started) {
                $result.Status = "Error"
                $result.Message = "Configurado en $targetStartType pero falló inicio"
            }
        }
        else {
            $result.Status = "Success"
            $result.Message = "Restaurado ($targetStartType) - Permaneció Detenido"
        }
    }

    return $result
}

# [NÚCLEO] Optimización de Memoria (RAM)
function Invoke-MemoryOptimization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(1, 2, 3)]
        [int]$Level,
        
        [switch]$Force
    )

    if (-not $script:State.Config) { throw "Configuración no cargada. Ejecute Initialize-PanopticoConfig." }
    
    $exclusions = $script:State.Config.Optimization.Ram_Exclusions
    $killedList = @()
    
    # [COMPLEMENTO] El Nivel 3 agresivo permite compactar Explorer/Svchost (Propiedad del usuario)
    if ($Level -eq 3) {
        # Reducir conjunto de seguridad para Limpieza Profunda
        $exclusions = $exclusions | Where-Object { $_ -notin @("explorer", "svchost") }
    }
    
    # Captura del WorkingSet inicial (Huella real del proceso)
    $startWS = (Get-Process | Measure-Object -Property WorkingSet -Sum).Sum

    # NIVEL 1: Cierre de Bloatware (Espacio de Usuario)
    if ($Level -ge 1) {
        $targets = $script:State.Config.Optimization.Ram1_Targets
        $procs = Get-Process | Where-Object { 
            $matchesTarget = $false
            foreach ($t in $targets) { if ($_.ProcessName -like $t) { $matchesTarget = $true; break } }
            return $matchesTarget
        }
        
        foreach ($p in $procs) {
            # Verificación de filtro de exclusión (Doble seguridad)
            if ($p.ProcessName -in $exclusions) { continue }
            
            try { 
                Stop-Process -InputObject $p -Force -ErrorAction SilentlyContinue 
                $killedList += $p.ProcessName
                Write-Verbose "Killed: $($p.ProcessName)"
            }
            catch {}
        }
        
        [System.GC]::Collect()
    }

    # NIVEL 2: EmptyWorkingSet (Kernel)
    if ($Level -ge 2 -and ([System.Management.Automation.PSTypeName]'WinAPI.Memory').Type) {
        $threshold = $script:State.Config.Settings.MemoryThresholds.Ram2_MB * 1MB
        
        # Obtener procesos candidatos
        $candidates = Get-Process | Where-Object { 
            $_.WorkingSet -gt $threshold -and 
            $_.ProcessName -notin $exclusions 
        }

        foreach ($proc in $candidates) {
            # FILTRO DE SEGURIDAD: Verificación de procesos críticos del sistema
            # La lista de exclusiones de JSON es prioritaria, pero añadimos seguridad para PID 0/4
            if ($proc.Id -in @(0, 4)) { continue }

            try {
                $handle = $proc.Handle
                $null = [WinAPI.Memory]::EmptyWorkingSet($handle)
            }
            catch {
                # Ignorar acceso denegado en procesos de sistema
            }
        }
    }
    
    # NIVEL 3: Agresivo (Apps + Compactación Profunda)
    if ($Level -eq 3) {
        $targets = $script:State.Config.Optimization.Ram3_Aggressive
        
        # [FRONTIER] Anulación VIP: Si el usuario requiere modo agresivo, incluso los VIP (como Brave) se cierran.
        # Ignoramos explícitamente Ram_Exclusions para la lista de cierre en Nivel 3.
        foreach ($t in $targets) {
            $procs = Get-Process -Name $t -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                try {
                    Stop-Process -InputObject $p -Force -ErrorAction SilentlyContinue
                    $killedList += $t
                }
                catch {}
            }
        }
        
        # [RESTAURADO & FRONTIER] Compactación Global para Nivel 3
        # Lógica: EmptyWorkingSet en TODO excepto PIDs de Kernel.
        # Esto anula Ram_Exclusions (que son para CIERRE, no para Compactación).
        if (([System.Management.Automation.PSTypeName]'WinAPI.Memory').Type) {
            $allProcs = Get-Process
            foreach ($proc in $allProcs) {
                # Excepciones críticas del Kernel (PID 0, 4) + Compresión de Memoria
                if ($proc.Id -in @(0, 4) -or $proc.ProcessName -eq "Memory Compression") { continue }
                try {
                    $null = [WinAPI.Memory]::EmptyWorkingSet($proc.Handle)
                }
                catch { }
            }
        }

        # Aggressive GC
        [System.GC]::Collect([System.GC]::MaxGeneration, [System.GCCollectionMode]::Aggressive)
    }
    
    # Calcular RAM liberada basada en el Delta del WorkingSet (Reducción de huella real)
    $endWS = (Get-Process | Measure-Object -Property WorkingSet -Sum).Sum
    $freedBytes = $startWS - $endWS
    
    # Si es negativo (overhead raro), ajustar a 0
    if ($freedBytes -lt 0) { $freedBytes = 0 }
    
    $freedMB = [math]::Round($freedBytes / 1MB, 2)
    
    return [PSCustomObject]@{
        FreedMB = $freedMB
        Killed  = ($killedList | Select-Object -Unique)
    }
}

# [NÚCLEO] Ayudante de Restauración de Snapshot
function Restore-PanopticoSnapshot {
    $keys = $script:State.ServiceSnapshot.Keys | Sort-Object
    $results = @()
    
    foreach ($k in $keys) {
        $entry = $script:State.ServiceSnapshot[$k]
        
        # Manejo de Tareas Programadas
        if ($k -like "TASK::*") {
            $taskName = $k -replace "TASK::", ""
            $prevState = $entry.PrevState
            
            $res = [PSCustomObject]@{ 
                Name    = $taskName
                Type    = "Task"
                Action  = "Restore"
                Status  = "Pending"
                Message = ""
            }
            
            # Solo habilitar si estaba habilitada originalmente
            if ($prevState -in @("Ready", "Running")) {
                try {
                    Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
                    $res.Status = "Success"
                    $res.Message = "Rehabilitada"
                }
                catch {
                    $res.Status = "Error"
                    $res.Message = $_.Exception.Message
                }
            }
            else {
                $res.Status = "Skipped"
                $res.Message = "Estaba $prevState - no se rehabilita"
            }
            
            $results += $res
        }
        # Manejo de Servicios
        elseif ($entry.Type -eq 'Service' -or $null -eq $entry.Type) {
            $dummyTarget = [PSCustomObject]@{ Name = $k; Type = 'Service' }
            # Invoke-ServiceAction ahora usa lógica Wake mejorada
            $res = Invoke-ServiceAction -Target $dummyTarget -Action Wake
            $results += $res
        }
    }
    return $results
}

# [NÚCLEO] Ayudante de Exportación
Export-ModuleMember -Function Initialize-PanopticoConfig, Save-PanopticoConfig, Invoke-ServiceAction, Invoke-MemoryOptimization, Restore-PanopticoSnapshot, Get-PanopticoSnapshot
