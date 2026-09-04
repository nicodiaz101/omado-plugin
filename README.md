# OmaDo Panel Widget

Official **OmaDo** bar-widget for the **Omarchy** desktop environment (Quattro / Quickshell).

Displays your daily tasks ("My Day") directly in the system's top bar, featuring real-time reactive D-Bus integration with the OmaDo daemon.

---

## Features

- **Native Thin Client**: 100% QML and JavaScript with zero compilation requirements.
- **Reactive D-Bus**: Communicates with `io.omarchy.OmaDo` and listens to real-time broadcast signals (`TodayTasksChanged`, `TasksChanged`).
- **Omarchy Quattro Design**: Implements native system components (`PanelHero`, `PopupCard`, `PanelSectionHeader`), adhering to the active theme palette and typography.
- **Quick Actions**:
  - Live pending tasks counter directly in the top bar.
  - Complete tasks with a single click from the dropdown panel.
  - 10-second visual grace period countdown when completing tasks inside the panel.
  - Direct shortcut to launch the full OmaDo application.

---

## Requirements

- [Omarchy](https://github.com/omacom/omarchy) running the Quattro shell.
- [OmaDo](https://github.com/nicodiaz101/omado) v1.0 or later with its background daemon running.

---

## Installation

1. Clone this repository or copy the directory into Omarchy's plugin path:
   ```bash
   mkdir -p ~/.config/omarchy/plugins/omado.panel
   cp -r * ~/.config/omarchy/plugins/omado.panel/
   ```

2. Add the widget to your bar layout in `~/.config/omarchy/shell.json` (e.g., inside the `center` or `right` array):
   ```json
   {
     "id": "omado.panel"
   }
   ```

3. Reload the Omarchy top bar:
   ```bash
   omarchy-restart-shell
   ```

---

## Project Structure

```text
├── manifest.json       # Omarchy Quattro plugin contract
├── BarWidget.qml       # Top bar entry widget and reactive D-Bus monitor
├── Panel.qml           # Dropdown floating panel displaying tasks list
├── Model.js            # Local state management, D-Bus calls, and task visibility filters
├── Theme.qml           # Theme color and style mapping
├── SPECS.md            # Technical specifications
├── AGENTS.md           # System rules and development guidelines
└── ROADMAP.md          # Development roadmap and milestones
```

---

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the [LICENSE](LICENSE) file for details.
