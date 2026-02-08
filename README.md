# Panóptico v3.0 - Sistema de Optimización de Recursos

> **Estética Retro-Profesional Lotus 1-2-3** | PowerShell 7.x | Arquitectura Modular

Sistema avanzado de gestión de memoria RAM y servicios de Windows con interfaz estilo años 80 y funcionalidad moderna.

---

## Características Principales

###  Interfaz Lotus 1-2-3
- Marcos ASCII dobles (`╔═══╗`)
- Paleta retro: Cyan/Yellow/White sobre DarkBlue
- Barra visual de RAM: `[#######---] 43.1%`
- Diseño tabular tipo hoja de cálculo

### Optimización de Memoria
- **RAM1**: Limpieza de bloatware en segundo plano
- **RAM2**: Compactación de Working Set (requiere Admin)
- **RAM3**: Modo profundo con confirmación interactiva

### Hibernación de Servicios
- **Hiber1**: Telemetría (Windows, Google, etc.)
- **Hiber2**: Bloatware OEM (Lenovo, Adobe, Brave)
- **Hiber3**: Modo enfoque (impresora, búsqueda, temas)
- **Reversahiber**: Restauración inteligente con triple fallback

### Monitoreo en Tiempo Real
- Monitor `top` con estadísticas de RAM y GPU
- Detección automática de NVIDIA GPU
- Colores dinámicos según temperatura y uso

---

##  Instalación

### Requisitos
- Windows 10/11
- PowerShell 7.x
- Permisos de Administrador (para funciones avanzadas)

### Instalación Rápida
```powershell
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/panoptico.git
cd panoptico

# 2. Cargar Panóptico
. .\Panoptico.ps1

# 3. Ver menú
pan
```

### Configuración Opcional
Editar `config.json` para personalizar:
- Procesos a eliminar (`Ram1_Targets`)
- Aplicaciones VIP protegidas (`VipProcesses`)
- Servicios a hibernar (`Hibernation`)

---

## Sobre elUso

### Comandos Principales
```powershell
pan           # Menú principal
top           # Monitor de recursos
ram1          # Limpieza ligera
ram2          # Compactación (Admin)
ram3          # Modo profundo (Admin)
hiber1        # Hibernar telemetría (Admin)
hiber2        # Hibernar bloatware (Admin)
hiber3        # Modo enfoque (Admin)
reversahiber  # Restaurar servicios (Admin)
focalizar     # Ver apps protegidas
```

### Atajos
```powershell
e             # Abrir explorador
ex            # Salir
lab           # Jupyter Lab (con logging)
```

---

## Estructura del Proyecto

```
Panóptico/
├── Panoptico.ps1           # Interfaz de usuario y comandos
├── Panoptico_Core.psm1     # Motor de optimización
├── config.json             # Configuración editable
├── deploy.ps1              # Script de despliegue
└── README.md               # Este archivo
```

---

## Arquitectura v3.0

### Cambios Disruptivos
- **Núcleo Modular**: Lógica separada en `Panoptico_Core.psm1`
- **Configuración JSON**: Sin hardcoding, todo editable
- **Estado Encapsulado**: Variables privadas, no globales
- **Restauración Robusta**: Triple fallback (Cmdlet → Registro → SC.exe)

### Mejoras Técnicas
- Gestión de memoria basada en `WorkingSet` delta (más preciso)
- Compactación global en RAM3 (incluso Explorer/Svchost)
- Validación de seguridad (servicios vitales protegidos)
- Logging de sesiones Jupyter en `.session_logs.txt`

---

## Ejemplo de Uso

### Escenario: Liberar RAM antes de trabajar
```powershell
# 1. Ver estado actual
top

# 2. Limpieza ligera
ram1

# 3. Si necesitas más, compactación
ram2

# 4. Hibernar servicios innecesarios
hiber1
hiber2

# 5. Verificar mejora
top
```

### Resultado Esperado
- **Antes**: 70% RAM usada
- **Después**: 20-35% RAM usada
- **Liberado**: ~3-6 GB

---

## Novedades v3.0

### Arquitectura
- **Modularización completa**: Migración de archivo monolítico (v2.x) a arquitectura de 3 capas
  - `Panoptico_Core.psm1`: Motor de optimización
  - `Panoptico.ps1`: Interfaz de usuario
  - `config.json`: Configuración centralizada
- **Configuración JSON**: Sistema de configuración editable sin tocar código (nueva funcionalidad)
- **Gestión de estado**: Variables encapsuladas, eliminación de globales inseguras

### Estética
- Interfaz retro-profesional inspirada en Lotus 1-2-3
- Barra ASCII de RAM con colores dinámicos
- Diseño tabular tipo hoja de cálculo

### Funcionalidades Restauradas
- Comando `lab` con logging automático (presente en v2.x, eliminado en refactorización, ahora restaurado)
- Aliases de flujo de trabajo (`e`, `ex`)

### Funcionalidades Removidas (v2.x → v3.0)
- `purga`, `purgagp` y comandos similares (simplificados en `ram1/ram2/ram3`)

### Mejoras Técnicas
- Monitor GPU mejorado (NVIDIA)
- Validación de dependencias (Jupyter, config.json)
- Protección contra doble carga
- Comentarios en español técnico



---

## 📊 Sobre la Medición de RAM

### Diferencias entre Herramientas

Es normal observar **valores ligeramente diferentes** al medir RAM entre:
- **Panóptico (`top`)**: Usa `Win32_OperatingSystem` (WMI)
- **Administrador de Tareas**: Usa API de kernel en tiempo real
- **Monitor de Rendimiento** (`perfmon.msc`): Usa contadores de rendimiento

### ¿Por qué las diferencias?

1. **Momento de captura**: Cada herramienta toma la medición en microsegundos diferentes
2. **Método de cálculo**: 
   - WMI: `TotalVisibleMemorySize - FreePhysicalMemory`
   - Task Manager: Incluye memoria comprimida y caché
   - Perfmon: Contadores específicos (`\Memory\Available Bytes`)
3. **Granularidad**: Algunas herramientas redondean, otras muestran decimales

### Valores Típicos de Variación

- **Diferencia esperada**: ±100-300 MB entre herramientas
- **Diferencia aceptable**: Hasta 500 MB (3-5% en sistemas de 16GB)
- **Diferencia preocupante**: >1 GB (posible memory leak)

### Recomendación

Para medir **liberación de RAM**:
1. Usar **siempre la misma herramienta** (ej: `top` antes y después)
2. Esperar 10-15 segundos después de ejecutar comandos
3. Comparar **tendencias**, no valores absolutos

**Ejemplo válido**:
```
Antes (top):  10.5 GB usado
Después (top): 6.2 GB usado
Liberado:      4.3 GB
```

**Ejemplo inválido**:
```
Antes (Task Manager): 10.5 GB
Después (top):         6.8 GB  ❌ (herramientas diferentes)
```

---

## ⚠️ Advertencias


- **RAM3**: Cierra aplicaciones activas (requiere confirmación)
- **Hibernación**: Algunos servicios pueden afectar funcionalidad (reversible con `reversahiber`)
- **Admin**: Funciones avanzadas requieren permisos elevados

---

## 🤝 Contribuciones

Este es un proyecto personal de optimización. Si encuentras bugs o tienes sugerencias:
1. Abre un Issue
2. Describe el problema/mejora
3. Incluye logs si es posible

---

## 📜 Licencia

MIT License - Úsalo libremente, modifícalo, compártelo.

---

## Agradecimientos

Inspirado en:
- ¿jugaste Doom en los 90? Yo sí, en un 486 de 4mb en ram y para que eso fuera posible, debíamos interrumpir la carga del sistema (iniciando MS-DOS...) con F5/F8, de esa forma liberábamos la RAM suficiente para ese y otros juegos. Eso, de alguna manera, me recuerda que, ajustando las tuercas, siempre puedes obtener mejor rendimiento.
- Lotus 1-2-3 (estética retro)
- Herramientas clásicas de optimización DOS/Windows

---

**Versión**: 3.0.0 (Lotus Edition)  
**Última actualización**: 2026-02-07  
**Autor**: Carlos Carriel Álvarez
