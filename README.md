# Panóptico v2.4 - Seguridad y "Safeguards"

## Descripción
Versión final de la arquitectura monolítica. Introduce capas de seguridad críticas antes del salto a la modularidad.

## Cambios Principales (Changelog)
- **Listas Blancas (Safeguards)**: Protección hardcodeada para servicios vitales (`Dhcp`, `Dnscache`, `ClickToRunSvc`) en la función `Invoke-PanopticoHibernate`.
- **Modo Simulación**: Parámetro `-WhatIfSimulate` interno para pruebas.
- **Refinamiento de Purga**: Mejoras en `purgap` para entornos de Data Science (Conda/Jupyter).

## Estado
- **Status**: Stable Release (Monolithic).
- **Archivo**: `Panoptico_v2.4.ps1`
