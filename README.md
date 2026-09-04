# OmaDo Panel Widget

Bar-widget oficial de **OmaDo** para el entorno de escritorio **Omarchy** (Quattro / Quickshell).

Muestra el estado de tus tareas del día ("Mi Día") directamente en la barra superior del sistema, con integración reactiva en tiempo real vía D-Bus con el daemon de OmaDo.

---

## Características

- **Thin Client Nativo**: 100% QML y JavaScript sin dependencias compiladas.
- **D-Bus Reactivo**: Se comunica con `io.omarchy.OmaDo` y escucha señales en tiempo real (`TodayTasksChanged`, `TasksChanged`).
- **Diseño Omarchy Quattro**: Utiliza componentes nativos del sistema (`PanelHero`, `PopupCard`, `PanelSectionHeader`) adaptándose a la paleta y tipografía del tema activo.
- **Acciones Rápidas**:
  - Visualización del conteo de tareas pendientes en la barra.
  - Marcar tareas como completadas directamente desde el panel.
  - Período de gracia visual con cuenta regresiva de 10s al completar una tarea.
  - Acceso directo para abrir la aplicación completa OmaDo.

---

## Requisitos

- [Omarchy](https://github.com/omacom/omarchy) con shell Quattro.
- [OmaDo](https://github.com/nicodiaz101/omado) v1.0 o superior con el servicio de daemon activo.

---

## Instalación

1. Clona este repositorio o copia la carpeta dentro del directorio de plugins de Omarchy:
   ```bash
   mkdir -p ~/.config/omarchy/plugins/omado.panel
   cp -r * ~/.config/omarchy/plugins/omado.panel/
   ```

2. Añade el widget a tu layout en `~/.config/omarchy/shell.json` (por ejemplo, en la sección `center` o `right`):
   ```json
   {
     "id": "omado.panel"
   }
   ```

3. Recarga la barra superior:
   ```bash
   omarchy-restart-shell
   ```

---

## Estructura del Proyecto

```text
├── manifest.json       # Contrato de integración del plugin con Omarchy Quattro
├── BarWidget.qml       # Presentación en la barra superior y monitor de señales D-Bus
├── Panel.qml           # Panel flotante desplegable con la lista de tareas
├── Model.js            # Estado local, llamadas a D-Bus y lógica de visibilidad
├── Theme.qml           # Mapeo de colores y estilos
├── SPECS.md            # Especificaciones técnicas completas
├── AGENTS.md           # Reglas del sistema y lineamientos de desarrollo
└── ROADMAP.md          # Plan de desarrollo e hitos
```

---

## Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
