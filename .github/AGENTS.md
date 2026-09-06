# AGENTS.md — Reglas del Sistema para el Agente Desarrollador del Plugin OmaDo

> **Fase de aplicación:** Toda implementación de código del plugin (Fase 1 y Fase 2)
> **Nivel de cumplimiento:** OBLIGATORIO. Sin excepciones.
> **Audience:** Agente de IA (Antigravity / Gemini) que desarrollará el código del plugin.

---

## PREÁMBULO

El plugin `omado.panel` es un **bar-widget de Omarchy Quattro** que se integra en la barra
superior del sistema. Su única responsabilidad es visualizar las tareas del día y comunicarse
con el daemon de OmaDo via D-Bus. El agente NO implementa lógica de negocio.

**Lectura obligatoria antes de escribir cualquier línea de código:**
1. `SPECS.md` — arquitectura, diseño y comportamientos requeridos.
2. `ROADMAP.md` — hito activo y criterios de éxito.
3. `AGENTS.md` de OmaDo (`/home/nicolas/Github/omado/AGENT.md`) — filosofía del ecosistema.

**Filosofía: thin client, máxima fidelidad visual al ecosistema Omarchy.**

---

## REGLA 1 — Archivos Permitidos: Lista Cerrada y Exhaustiva

El plugin tiene exactamente los siguientes archivos fuente. No se crean otros sin justificación
en SPECS.md y aprobación explícita:

```
manifest.json       ← Contrato Omarchy Quattro — NO modificar estructura sin revisar la doc
BarWidget.qml       ← Widget en la barra — solo presentación y toggle del panel
Panel.qml           ← Panel flotante — lista de tareas, botón "Abrir OmaDo"
Model.js            ← Lógica D-Bus, estado, filtros — TODA la lógica va aquí
README.md           ← Documentación de usuario
LICENSE             ← MIT
.gitignore
```

> **No se crean archivos C++, CMakeLists.txt, ni ningún binario compilado.**
> El plugin es 100% QML + JavaScript. Cero compilación.

---

## REGLA 2 — Comunicación D-Bus: Solo como Cliente

El plugin **únicamente consume** el servicio D-Bus de OmaDo. Nunca registra servicios propios.

```js
// CORRECTO — cliente D-Bus via la API del runtime de Omarchy Quattro
// (el nombre exacto del tipo se confirma en Fase 1 inspeccionando plugins built-in)

// CORRECTO — llamadas a métodos
OmaDo.GetTasksForToday(function(tasks) { /* ... */ })
OmaDo.ToggleTask(taskId, true, function(success) { /* ... */ })
OmaDo.DeleteTask(taskId, function(success) { /* ... */ })

// INCORRECTO — registrar servicio propio
DBusConnection.registerService("io.omarchy.OmaDo.Panel")  // PROHIBIDO

// INCORRECTO — acceso a SQLite
const db = LocalStorage.openDatabaseSync("omado")  // PROHIBIDO ABSOLUTAMENTE

// INCORRECTO — llamadas HTTP propias
fetch("http://localhost:8080/tasks")  // PROHIBIDO
```

**Métodos D-Bus consumidos por el plugin (SOLO estos cuatro):**
- `GetTasksForToday()` → `aa{sv}`
- `GetTotalPendingCount()` → `i`
- `ToggleTask(taskId: s, completed: b)` → `b`
- `DeleteTask(taskId: s)` → `b`

**Señales D-Bus escuchadas:**
- `TodayTasksChanged` → trigger `refreshTasks()`
- `TasksChanged(listId: s)` → trigger `refreshTasks()`

---

## REGLA 3 — Theming: SIEMPRE via Theme.*

```qml
// CORRECTO — siempre Theme.*
Rectangle { color: Theme.surface; border.color: Theme.border }
Text { color: Theme.foreground; font.family: "iA Writer Mono" }
Rectangle {
    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.1)
}

// INCORRECTO — colores hardcodeados PROHIBIDOS
Rectangle { color: "#1a1a2e" }          // PROHIBIDO
Text { color: "white" }                 // PROHIBIDO
Text { color: "#e0e0e0" }              // PROHIBIDO — aunque sea el color del tema activo
Rectangle { color: "transparent" }     // PERMITIDO únicamente para fondos intencionalmente transparentes
```

**Variables de tema disponibles y su uso en el plugin:**

| Variable | Uso correcto |
|---|---|
| `Theme.background` | Fondo profundo del panel |
| `Theme.surface` | Fondo del panel flotante y botones |
| `Theme.foreground` | Texto principal |
| `Theme.accent` | CheckCircle completado, botón "Abrir OmaDo" |
| `Theme.border` | Bordes, separadores, texto de completadas |
| `Theme.error` | Fondo de confirmación de eliminación |

> **Nota:** El namespace exacto del módulo de theming (`import OmaDo.Theme 1.0`,
> `import Omarchy.Theme 1.0`, etc.) se confirma en la Fase 1 inspeccionando los
> plugins built-in de Omarchy. NO asumir el namespace — leer primero.

---

## REGLA 4 — Checkboxes: Siempre Círculos, Nunca Cuadrados

```qml
// CORRECTO — CheckCircle en el plugin
Rectangle {
    id: checkCircle
    width: 16
    height: 16
    radius: width / 2   // círculo perfecto — OBLIGATORIO
    color: checked ? Theme.accent : "transparent"
    border.color: checked ? Theme.accent : Theme.border
    border.width: 1.5

    Text {
        visible: checked
        text: "\u2713"      // ✓ Unicode
        color: Theme.background
        font.family: "iA Writer Mono"
        font.pixelSize: 10
        anchors.centerIn: parent
    }

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
}

// INCORRECTO
CheckBox { }                          // PROHIBIDO (control de QtQuick.Controls)
Rectangle { radius: 0 }              // PROHIBIDO (cuadrado)
Rectangle { radius: 3 }              // PROHIBIDO (cuadrado redondeado ≠ círculo)
Rectangle { radius: 4 }              // PROHIBIDO (cualquier valor != width/2)
```

---

## REGLA 5 — Iconos: Solo Unicode, Nunca Imágenes

```qml
// CORRECTO — iconos Unicode
Text { text: "\u25CB" }   // ○  U+25CB tarea pendiente
Text { text: "\u2713" }   // ✓  U+2713 tarea completada
Text { text: "\u2715" }   // ✕  U+2715 eliminar
Text { text: "\u2014" }   // —  U+2014 daemon no disponible
Text { text: "\u2026" }   // …  U+2026 cargando

// INCORRECTO
Image { source: ":/icons/check.png" }   // PROHIBIDO
Image { source: ":/icons/close.svg" }   // PROHIBIDO
Image { source: "qrc:///icons/task.png" } // PROHIBIDO
```

---

## REGLA 6 — Confirmación de Eliminación: Inline, Sin Modales

```qml
// CORRECTO — confirmación inline dentro del ítem
// Flujo al hacer clic en ✕:
// 1. Item.state = "confirming"
// 2. Ítem muestra: "¿Eliminar «título»?" + botones [Sí] [No]
// 3. Timer 5s → si no hay respuesta → Item.state = "normal"
// 4. Clic [Sí] → OmaDo.DeleteTask(id) → animar salida del ítem
// 5. Clic [No] → Item.state = "normal"

// INCORRECTO
Dialog { ... }                  // PROHIBIDO
MessageBox { ... }              // PROHIBIDO
AlertDialog { ... }             // PROHIBIDO
Popup { modal: true }           // PROHIBIDO si es un overlay separado
```

**Implementación del timeout de cancelación automática:**
```qml
Timer {
    id: deleteCancelTimer
    interval: 5000
    repeat: false
    onTriggered: taskItem.state = "normal"
}

// Al entrar al estado "confirming":
onStateChanged: if (state === "confirming") deleteCancelTimer.start()
```

---

## REGLA 7 — Manejo del Daemon No Disponible: Silencioso

```js
// CORRECTO — silencioso, sin interrumpir al usuario
function checkDaemonAvailable() {
    try {
        const count = OmaDo.GetTotalPendingCount()
        daemonAvailable = true
        pendingCount = count
        refreshTasks()
    } catch (e) {
        daemonAvailable = false
        pendingCount = 0
        // BarWidget muestra "—" automáticamente via binding
        console.warn("[omado.panel] Daemon no disponible:", e.message)
        // NO llamar a showNotification(), NO loguear en UI
    }
}

// Timer de reintento: 30 segundos fijos
// INCORRECTO — no usar backoff exponencial, no interrumpir al usuario
showErrorDialog("OmaDo no está corriendo")   // PROHIBIDO
```

---

## REGLA 8 — Timer de 10 Segundos para Tareas Completadas

Esta es la regla de UX más crítica del plugin. La implementación debe ser exacta:

```js
// En Model.js — IMPLEMENTACIÓN OBLIGATORIA

var recentlyCompleted = {}  // { taskId: { timestamp: Number, secondsLeft: Number } }

function toggleTask(taskId, currentCompleted) {
    var newState = !currentCompleted

    // Llamada D-Bus — optimistic update posible
    OmaDo.ToggleTask(taskId, newState, function(success) {
        if (!success) {
            // Revertir el estado visual si el daemon rechazó la operación
            refreshTasks()
            return
        }
    })

    if (newState === true) {
        // Registrar como recién completada
        recentlyCompleted[taskId] = { timestamp: Date.now(), secondsLeft: 10 }
        // El componente QML conecta un Timer que decrementa secondsLeft cada segundo
        // y llama a removeRecentlyCompleted(taskId) cuando llega a 0
    } else {
        // Usuario desmarcó la tarea — limpiar estado
        if (recentlyCompleted.hasOwnProperty(taskId)) {
            delete recentlyCompleted[taskId]
        }
    }
    // Notificar al modelo QML para actualizar la vista
    recentlyCompletedChanged()
}

function isTaskVisible(task) {
    if (!task.isCompleted) return true
    return recentlyCompleted.hasOwnProperty(task.id)
}

function getSecondsLeft(taskId) {
    if (!recentlyCompleted.hasOwnProperty(taskId)) return 0
    return recentlyCompleted[taskId].secondsLeft
}
```

**Reglas adicionales del timer (no negociables):**
- El countdown se inicia SOLO cuando el usuario hace clic en el CheckCircle DENTRO DEL PANEL.
- Si `TodayTasksChanged` llega desde el daemon (ej: usuario marcó desde la GUI de OmaDo),
  las tareas completadas NO tienen el periodo de gracia — desaparecen directamente.
- Si el panel se cierra y re-abre durante los 10s, la tarea sigue visible con el tiempo restante.
- Si el usuario desmarca la tarea dentro de los 10s, se cancela el countdown.

---

## REGLA 9 — Estructura Interna de los Archivos QML

```qml
// Estructura obligatoria de cada archivo QML del plugin
import QtQuick
import QtQuick.Controls
// (el import de Theme se confirma en Fase 1)

[NombreComponente] {
    id: root

    // Bloque 1: required properties (si las hay)
    // Bloque 2: optional properties con defaults explícitos
    // Bloque 3: señales (signal ...)
    // Bloque 4: layout — anchors, width, height
    // Bloque 5: hijos visuales (Rectangle, Text, ListView, etc.)
    // Bloque 6: handlers (MouseArea, TapHandler, Keys.onXxx)
    // Bloque 7: animaciones (Behavior, Transition, NumberAnimation)
    // Bloque 8: states y transitions (State { ... })
}
```

**Un componente por archivo. PascalCase en el nombre del archivo.**

---

## REGLA 10 — Foco y Accesibilidad

```qml
// CORRECTO — todo elemento interactivo tiene foco de teclado
Item {
    id: taskItem
    activeFocusOnTab: true

    Keys.onSpacePressed: toggleTask(model.id, model.isCompleted)
    Keys.onReturnPressed: toggleTask(model.id, model.isCompleted)
    Keys.onDeletePressed: initiateDelete(model.id)

    // Indicador de foco — SIEMPRE visible cuando hay foco
    Rectangle {
        visible: taskItem.activeFocus
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.accent
        border.width: 2
        radius: parent.radius
    }
}
```

**Atajos de teclado del panel:**
- `Escape` → cierra el panel
- `Tab` / `Shift+Tab` → navega entre ítems
- `Space` / `Enter` → toggle del ítem con foco
- `Delete` → inicia flujo de eliminación del ítem con foco

NUNCA ocultar el indicador de foco. SIEMPRE `activeFocusOnTab: true` en elementos interactivos.

---

## REGLA 11 — Checklist Pre-Código (Obligatorio)

Antes de implementar cualquier feature o modificar cualquier archivo, en este orden:

1. **Leer SPECS.md completo** — ¿el behavior está especificado? Si no: detener y preguntar.
2. **Verificar ROADMAP.md** — ¿la tarea está en el hito activo? ¿no está bloqueada?
3. **Identificar el archivo correcto** — `BarWidget.qml`, `Panel.qml` o `Model.js`.
4. **Confirmar el import de Theme** — revisar plugin built-in del clock de Omarchy si hay duda.
5. **Escribir el código** — siguiendo REGLAS 3–10.
6. **Verificar manualmente** — `omarchy-shell shell rescanPlugins` y probar en barra.
7. **Actualizar ROADMAP.md** — marcar tarea como ✅.

---

## REGLA 12 — Prohibiciones Estructurales

- NO crear archivos C++ ni CMakeLists.txt.
- NO usar `LocalStorage` (HTML5) ni ningún acceso a base de datos directamente.
- NO usar `XMLHttpRequest` ni `fetch()` para llamadas de red propias.
- NO registrar un servicio D-Bus propio.
- NO lanzar una segunda instancia de Quickshell.
- NO usar `QProcess` ni `shell()` — solo `Quickshell.execDetached`.
- NO hardcodear colores ni fuentes.
- NO usar `Dialog`, `MessageBox`, `Popup` modal para confirmaciones.
- NO ignorar el estado de error del daemon — mostrar `"—"` en el BarWidget.
- NO actualizar el ROADMAP.md en mitad de una tarea — solo al completarla.
- NO implementar lógica de sincronización con MS To Do — eso le corresponde al daemon.
- NO acceder a `~/.local/share/omado/omado.db` directamente — todo via D-Bus.

---

## REGLA 13 — Inspección Obligatoria de Plugins Built-in

**Antes de iniciar la Fase 1**, el agente DEBE localizar e inspeccionar los plugins built-in:

```bash
# Buscar plugins del sistema
find /usr/share/omarchy ~/.config/omarchy -name "manifest.json" 2>/dev/null
find /usr/share/omarchy ~/.config/omarchy -name "BarWidget.qml" 2>/dev/null

# Leer el plugin del reloj como referencia
cat $(find /usr/share/omarchy -path "*/omarchy.clock/BarWidget.qml" 2>/dev/null)
```

Información crítica a extraer de los plugins built-in:
1. **Namespace del import de Theme** — ¿`OmaDo.Theme 1.0`? ¿`Omarchy.Theme 1.0`?
2. **API de D-Bus disponible** — ¿`DBusServiceProxy`? ¿Otra?
3. **Dimensiones y padding de la barra** — altura de la barra, padding vertical de items.
4. **Posicionamiento del panel flotante** — ¿cómo se ancla relativo al BarWidget?
5. **API para lanzar apps** — ¿`Quickshell.execDetached`? ¿Otra?

Consultar también: `https://github.com/omacom/omarchy/blob/quattro/shell/README.md`

> Esta inspección es OBLIGATORIA. El plugin debe ser visualmente indistinguible de los
> plugins built-in de Omarchy en términos de estilo y comportamiento.

---

## REGLA 14 — Coordinación con OmaDo: Método DeleteTask

OmaDo v1.0 está finalizado. `LocalRepository::deleteTask(id)` existe e implementa la eliminación
completa en SQLite. Lo único pendiente es exponerlo en el `DaemonService` via D-Bus.

**Verificación antes de implementar la eliminación en el plugin:**
```bash
# Confirmar que DeleteTask está disponible en el bus
busctl --user introspect io.omarchy.OmaDo /io/omarchy/OmaDo io.omarchy.OmaDo 2>/dev/null | grep DeleteTask
```

**Si DeleteTask aparece en el resultado:** implementar la eliminación en el plugin (Fase 2, Hito 2.2).

**Si DeleteTask NO aparece:** el Hito 2.1 del ROADMAP aún no está completo. Completarlo en el
repositorio de OmaDo primero (`DaemonService.h/.cpp` + `io.omarchy.OmaDo.xml`), luego continuar.

El plugin **nunca** simula la eliminación localmente — siempre espera confirmación del daemon.

---

## Apéndice: Referencias Rápidas

| Necesidad | Solución en el plugin |
|---|---|
| Timer one-shot (10s) | `Timer { interval: 10000; repeat: false; onTriggered: ... }` |
| Timer periódico (30s retry) | `Timer { interval: 30000; running: !daemonAvailable; onTriggered: ... }` |
| Timer countdown (1s steps) | `Timer { interval: 1000; repeat: true; onTriggered: secondsLeft-- }` |
| Círculo checkbox | `Rectangle { radius: width / 2 }` |
| Color con opacidad | `Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.1)` |
| Animación suave | `Behavior on color { ColorAnimation { duration: 150 } }` |
| Fade animado | `Behavior on opacity { NumberAnimation { duration: 80 } }` |
| Scroll en lista | `ListView { clip: true; ScrollBar.vertical: ScrollBar { } }` |
| Abrir OmaDo | `Quickshell.execDetached(["omado"])` |
| Unicode círculo vacío | `"\u25CB"` (○) |
| Unicode check | `"\u2713"` (✓) |
| Unicode eliminar | `"\u2715"` (✕) |
| Unicode dash | `"\u2014"` (—) |
| Unicode ellipsis | `"\u2026"` (…) |
