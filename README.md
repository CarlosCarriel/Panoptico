# Panóptico v2.3 - Optimizaciones de Red

## Descripción
Mejora significativa en el rendimiento de los módulos de red y diagnóstico.

## Cambios Principales (Changelog)
- **Escáner de Red Paralelo**: Implementación de `ForEach-Object -Parallel` para escaneos de subred más rápidos (PowerShell 7+).
- **Monitor de GPU Persistente**: Se añade caché a la lectura de `nvidia-smi` para evitar lag en el loop de `monitor`.
- **Top Procesos O(1)**: Optimización de tablas hash para reducir el uso de CPU del propio script.

## Estado
- **Status**: Obsoleto (Legacy).
- **Archivo**: `Panoptico_v2.3.ps1`
