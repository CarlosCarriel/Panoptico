# Panóptico v2.2 — Windows Optimization & AI Workspace Toolkit

**Panóptico** es una suite personalizada de utilidades en PowerShell diseñada para centralizar el monitoreo de hardware y la optimización de recursos en estaciones de trabajo Windows. Está optimizada para flujos de trabajo de Ciencia de Datos, Desarrollo y ejecución de LLMs locales (Ollama).

> **Nota de Realidad:** Este es un proyecto de optimización de entorno personal. No reemplaza herramientas de monitoreo empresarial, sino que potencia la agilidad del administrador directamente desde la terminal.

---

## Funcionalidades Core

### 1. Monitoreo Integrado
* **Métricas en un vistazo:** RAM, VRAM (NVIDIA), CPU y conectividad de red mediante comandos ligeros (`TOP`, `MONITOR`).
* **Auditoría de Seguridad:** Verificación rápida de estado de Firewall, Antivirus y puertos activos (`VERSEGURIDAD`).

### 2. Gestión de Memoria y Servicios (Hibernación)
Panóptico permite definir "perfiles de carga" mediante la desactivación temporal de servicios no críticos:
* **Modo WEB/DEV/LLM:** Tres niveles de profundidad para liberar recursos, desde telemetría básica hasta servicios críticos de sistema.
* **Limpieza Kernel-Level:** Implementación de `EmptyWorkingSet` vía C# (P/Invoke) para liberación efectiva de RAM física.

### 3. Orquestación de IA Local
* Controlador para **Ollama** (start/stop/logs) con detección de procesos huérfanos.
* Priorización de procesos (`FOCALIZAR`) para asegurar ciclos de CPU a hilos de inferencia o compilación.

---

## Instalación Pragmática

Para integrar Panóptico sin afectar tu configuración actual, sigue estos pasos:

1. **Clona el repositorio:**
   ```powershell
   git clone [https://github.com/CarlosCarriel/Panoptico.git](https://github.com/CarlosCarriel/Panoptico.git)
2. Integra en tu Perfil: Añade esta línea a tu $PROFILE para cargar las funciones automáticamente cada vez que abras PowerShell:
    ```powershell
   . "C:\Ruta\A\Tu\Archivo\Panoptico_v2.2.ps1"

## Caja de herramientas (Diccionario)

El sistema se opera mediante comandos cortos diseñados para la agilidad en consola. Algunos requieren privilegios de Administrador para interactuar con el Kernel o servicios del sistema.

| COMANDO | DESCRIPCIÓN | NIVEL |
| :--- | :--- | :--- |
| **TOP** | Monitor de recursos en tiempo real (RAM, GPU, Red, Disco). | Usuario |
| **MONITOR** | Dashboard persistente (Ejecución de `TOP` en bucle). | Usuario |
| **RED** | Escáner de red local (Muestra IP, Hostname y MAC). | Usuario |
| **VERSEGURIDAD** | Auditoría de Seguridad: Antivirus, Firewall, Puertos activos. | Usuario |
| **RAM1** | Limpieza Rápida: Garbage Collection + Bloatware superficial (Seguro). | Usuario |
| **RAM2** | Limpieza Profunda: Kernel `EmptyWorkingSet` (Libera RAM física). | **Admin** |
| **RAMOLLAMA** | Limpieza Extrema: Modo dedicado para cargas pesadas de IA/LLM. | **Admin** |
| **PURGA** | Saneamiento OS: Limpieza de Temporales, DNS, Logs y WER. | **Admin** |
| **PURGAP** | Saneamiento Dev: Limpieza de artefactos en Conda, Pip y Jupyter. | **Admin** |
| **FOCALIZAR** | CPU Boost: Asigna Prioridad Alta a procesos VIP (Python, Ollama). | **Admin** |
| **HIBER1** | Hibernación Nivel 1: Desactiva Telemetría de Microsoft. | **Admin** |
| **HIBER2** | Hibernación Nivel 2: Servicios Auxiliares y Tareas programadas. | **Admin** |
| **HIBER3** | Hibernación Nivel 3: Deep Work (Search, Spooler, SysMain). | **Admin** |
| **HIBERSTATUS** | Auditoría: Lista qué servicios están hibernados actualmente. | Usuario |
| **REVERSAHIBER** | Restauración: Despierta y normaliza todos los servicios. | **Admin** |
| **LAB** | Inicializa entorno de trabajo X + Jupyter Lab. | Usuario |
| **OLLAMA** | Controlador LLM: `start` \| `stop` \| `status` \| `logs` \| `debug-on`. | Usuario |
| **PAN** | Manual de referencia y Menú Principal de Panóptico. | Usuario |

---

## Arquitectura y Rendimiento  
Para evitar latencia en el arranque (startup), Panóptico implementa:  

Lazy Loading para Conda: No carga el entorno de Python hasta que se invoca el comando conda.  

CIM Instances: Consultas de red un 60% más rápidas que los cmdlets estándar.  

GPU Caching: La telemetría de NVIDIA se cachea por 5 segundos para evitar bloqueos por llamadas constantes  

## Seguridad y Rollback  
Snapshots: Antes de cualquier cambio en servicios (HIBER), el script captura el estado actual.  

Logs de Auditoría: Registro persistente en ~/Documents/PowerShell/panoptico_hibernacion.log.  

Detección de Huérfanos: Alerta si procesos de IA quedan activos en segundo plano sin control.  

## Licencia
Este proyecto está bajo la licencia MIT.

*Panóptico v2.2 - 2026 | Desarrollado para optimización de flujos de trabajo de alto rendimiento.*
