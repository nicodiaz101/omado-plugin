# OmaDo-plugin

> Official bar-widget plugin for the **Omarchy** desktop shell, integrating seamlessly with the **OmaDo** task daemon via D-Bus.

Displays your daily tasks ("My Day") directly in your top status bar with instant reactive updates, inline completion, reminder badges, and fast access to OmaDo.

> [!IMPORTANT]
> **This plugin is a companion bar-widget and REQUIRES [OmaDo](https://github.com/nicodiaz101/omado) to be installed and running.**  
> It acts as a thin client over D-Bus. It does not store tasks or perform cloud sync on its own; all task data, SQLite storage, and Microsoft To Do synchronization are managed by the OmaDo background service.

---

## Features

- **Native Thin Client**: 100% pure QML and JavaScript. Zero external compilation required.
- **Reactive D-Bus Integration**: Consumes the `io.omarchy.OmaDo` session bus service. Automatically syncs on `TodayTasksChanged` and `TasksChanged` signals.
- **Omarchy Quattro Visual Language**:
  - Uses native Omarchy components (`PopupCard`, `PanelHero`, `PanelSectionHeader`).
  - Follows dynamic system theming (`Theme.*`) and typography.
  - Minimalist circular checkboxes (`radius: width / 2`) and clean Unicode iconography.
- **Task Management in the Bar**:
  - **Live Counter**: Displays current pending tasks (e.g. `✓ 3`) or status in the bar.
  - **Reminder Badges**: Shows a styled pill with the scheduled reminder time (`◷ 15:00`) under task titles.
  - **10-Second Grace Period**: Marking a task complete keeps it visible for 10 seconds with a countdown timer before dismissing, allowing easy undo.
  - **Inline Delete**: Click `✕` to prompt a non-blocking confirmation directly in the task row (auto-cancels after 5s).
  - **App Launcher**: Single click button to launch the full OmaDo desktop app.

---

## Requirements

1. **Omarchy**
2. **[OmaDo](https://github.com/nicodiaz101/omado) (v1.1+)**: The core application and daemon must be installed.
   - The OmaDo background daemon must be active so the plugin can communicate over D-Bus. If for some reason the installer of OmaDo do not add the autostart, you can add it by yourself:
     ```bash
     # Enable and start the OmaDo daemon user service
     systemctl --user enable --now omado.service

     # Or run the daemon directly
     omado --daemon &
     ```
   - *Note: If OmaDo is not installed or the daemon is stopped, the widget silently displays a dash (`—`) in the bar until the daemon becomes available.*

---

## Installation

```bash
omarchy plugin add https://github.com/nicodiaz101/omado-plugin.git --enable
```
*(Alias: `omarchy plugin install https://github.com/nicodiaz101/omado-plugin.git --enable`)*

When prompted, select where to place the widget on your bar (`left`, `center`, or `right` — default is `center`).

---

## Managing the Plugin

- **Update to the latest version**:
  ```bash
  omarchy plugin update omado.panel
  ```
  *(Or run `omarchy plugin update` to update all git-managed plugins)*

- **Move widget position in the bar**:
  ```bash
  omarchy bar move omado.panel --section center
  ```

- **Temporarily disable**:
  ```bash
  omarchy plugin disable omado.panel
  ```

- **Re-enable**:
  ```bash
  omarchy plugin enable omado.panel
  ```

- **Uninstall**:
  ```bash
  omarchy plugin remove omado.panel
  ```

---

## Manual Installation (Local Development)

If you are developing or testing local changes:

1. Clone or copy into the user plugins directory:
   ```bash
   git clone https://github.com/nicodiaz101/omado-plugin.git ~/.config/omarchy/plugins/omado.panel
   ```

2. Validate the plugin manifest:
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/omado.panel
   ```

3. Reload plugins and enable:
   ```bash
   omarchy-shell shell rescanPlugins
   omarchy plugin enable omado.panel
   ```

Any edits saved in `~/.config/omarchy/plugins/omado.panel/` are hot-reloaded automatically by `omarchy-shell`.

---

## Architecture & File Structure

```text
omado-plugin/
├── manifest.json       # Omarchy Quattro plugin contract (ID: omado.panel)
├── BarWidget.qml       # Top bar widget (counter badge, click-toggle, D-Bus listeners)
├── Panel.qml           # Floating popup card (task list, reminder pill, inline delete)
├── Model.js            # State store, D-Bus method invocations, countdown & filters
├── Theme.qml           # Palette fallback mapping
├── README.md           # User & installation documentation
├── SPECS.md            # Technical specifications
├── AGENTS.md           # AI Agent guidelines and rules
└── ROADMAP.md          # Feature roadmap and milestones
```

---

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the [LICENSE](LICENSE) file for details.
