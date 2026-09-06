# SPECS.md — Especificaciones Técnicas: Plugin de Panel OmaDo para Omarchy

> Plugin QuickShell para la barra superior de Omarchy Quattro que expone las tareas del día via D-Bus
> **Stack:** QML · Quickshell Plugin API · D-Bus (Qt6::DBus) · Omarchy Quattro shell

---

## 1. Visión General

El plugin `omado.panel` es un **bar-widget** nativo de Omarchy Quattro que se integra a la barra
superior del sistema y se comunica exclusivamente con el daemon de OmaDo (`io.omarchy.OmaDo`)
vía D-Bus. No contiene lógica de negocio propia ni acceso directo a datos.

### Principio Arquitectural Fundamental: Thin Client D-Bus

```
┌─────────────────────────────────────────────────────────────────────┐
│                      omado.panel (plugin)                           │
│         Bar widget QML puro — solo presentación y UX                │
│         Sin acceso a SQLite · Sin lógica de negocio propia          │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ D-Bus session bus
                            │ io.omarchy.OmaDo
┌───────────────────────────▼─────────────────────────────────────────┐
│                  OmaDo daemon (omado --daemon)                      │
│          Fuente de verdad · SQLite · Notificaciones · Sync          │
└─────────────────────────────────────────────────────────────────────┘
```

**El plugin NO tiene base de datos, NO hace llamadas de red, NO contiene modelos C++.**
Todo CRUD pasa por el daemon. Si el daemon no está corriendo, el widget muestra estado de error silencioso.

---

## 2. Contrato del Plugin con Omarchy Quattro

El plugin es de tipo **`bar-widget`** según la especificación de plugins de Omarchy.

### 2.1 Estructura de Archivos Obligatoria

```
~/.config/omarchy/plugins/omado.panel/
├── manifest.json          # Identificación, kind, configuración del widget
├── BarWidget.qml          # Widget compacto en la barra (icono + badge)
├── Panel.qml              # Panel flotante con lista de tareas del día
└── Model.js               # Lógica D-Bus, estado y filtros (JavaScript puro)
```

> **Regla:** El entrypoint QML se llama exactamente `BarWidget.qml`. El panel flotante se llama
> `Panel.qml`. Estos nombres son impuestos por el runtime de Omarchy Quattro (ver plugin contract).

### 2.2 manifest.json

```json
{
  "schemaVersion": 1,
  "id": "omado.panel",
  "name": "OmaDo Tasks",
  "version": "1.0.0",
  "author": "omacom-io",
  "license": "MIT",
  "description": "Tareas del día de OmaDo en la barra superior de Omarchy.",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "BarWidget.qml"
  },
  "barWidget": {
    "displayName": "OmaDo Tasks",
    "category": "Productivity",
    "allowMultiple": false,
    "defaultSection": "right"
  },
  "settings": {
    "position": {
      "type": "enum",
      "values": ["left", "center", "right"],
      "default": "right",
      "label": "Posición en la barra"
    }
  }
}
```

**Campos clave:**
- `defaultSection`: El usuario puede elegir `left`, `center` o `right` en la configuración del plugin.
- `allowMultiple: false` — solo una instancia activa a la vez.
- `kinds: ["bar-widget"]` — tipo de plugin correcto para un elemento en la barra.

---

## 3. Diseño Visual — Filosofía Omarchy

El plugin **hereda el lenguaje visual de OmaDo y de Omarchy Quattro**:

| Propiedad | Valor |
|---|---|
| Fuente | `iA Writer Mono` (misma que OmaDo) |
| Colores | `Theme.*` de Omarchy — NUNCA hardcodeados |
| Checkboxes | Círculos perfectos (`radius: width / 2`) — nunca cuadrados |
| Iconos | Solo caracteres Unicode — sin PNG ni SVG externos |
| Bordes | `Theme.border` — sin sombras pesadas |
| Radio de esquinas | 6–8px en superficies, 0 en items de lista |
| Densidad de información | Mínima — cada elemento tiene un propósito |

### 3.1 BarWidget — Widget en la Barra

El widget compacto que aparece en la barra muestra:

```
┌──────────────────────────────┐
│  ○  3 tareas                 │
└──────────────────────────────┘
```

- **Ícono:** Círculo vacío `○` (Unicode U+25CB) como indicador visual de "tareas pendientes".
  Si el daemon no está corriendo: `—` (guion largo U+2014).
- **Badge:** Número de tareas pendientes del día. Si `count = 0`: texto `"Sin tareas"`.
  Si `count > 9`: mostrar `"9+"`.
- **Fondo:** `transparent` en estado normal. `Theme.surface` con borde `Theme.border` al hover.
- **Texto:** `Theme.foreground`, `font.pixelSize: 12`.
- **Clic izquierdo:** Abre/cierra `Panel.qml`.
- **Ancho:** dinámico según el texto, con padding horizontal de 10px.

**Estados del BarWidget:**

| Estado | Visualización |
|---|---|
| Daemon activo, tareas > 0 | `○  N tareas` en `Theme.foreground` |
| Daemon activo, sin tareas | `○  Sin tareas` en `Theme.foreground` opacidad 0.45 |
| Daemon no disponible | `—` en `Theme.foreground` opacidad 0.35, sin acción al clic |
| Cargando (primera conexión) | `…` parpadeando suavemente |

### 3.2 Panel Flotante — Lista de Tareas del Día

Al hacer clic en el BarWidget, aparece un panel flotante (`Panel.qml`) con las tareas de hoy:

```
┌────────────────────────────────────────────┐
│  Tareas de hoy                             │  ← Header (texto pequeño, opacidad 0.5)
├────────────────────────────────────────────┤
│  ○  Preparar presentación                  │
│  ○  Llamar al cliente                      │
│  ✓  Reunión de equipo              [10s]   │  ← tarea recién completada, timer visible
│  ○  Revisar pull requests                  │
│                                            │
│  ─────────────────────────────────────────│  ← separador
│  [  Abrir OmaDo  ]                         │  ← botón primario
└────────────────────────────────────────────┘
```

**Dimensiones del panel:**
- **Ancho:** 320px fijo.
- **Alto:** dinámico, máximo `min(tasks.length * 44 + 100, 480)px`.
- **Posición:** anclado debajo del BarWidget, alineado según la sección (izquierda/centro/derecha).
- **Fondo:** `Theme.surface` con `border.color: Theme.border`, `radius: 8`.
- **Separador antes del botón:** 1px `Theme.border`.

### 3.3 Item de Tarea en el Panel

Cada tarea se muestra como un ítem de 40px de altura:

```
┌──────────────────────────────────────────────────┐
│  [○]  Nombre de la tarea               [✕]       │
└──────────────────────────────────────────────────┘
```

- **CheckCircle `[○]`:** Círculo vacío de 16px. Al completar: `Theme.accent` con ✓.
  Animación suave con `Behavior on color { ColorAnimation { duration: 150 } }`.
- **Título:** `Theme.foreground`, `font.pixelSize: 13`, `iA Writer Mono`, elide a la derecha.
  Al completar: `Theme.border` (atenuado) + `font.strikeout: true`.
- **Botón eliminar `[✕]`:** Solo visible en hover del ítem (opacidad 0 → 1 con `Behavior`).
  Icono Unicode `✕` en `Theme.foreground` opacidad 0.5. Al clic: confirmación inline (ver §4.4).
- **Hover:** Fondo sutil `Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)`.

### 3.4 Botón "Abrir OmaDo"

Ubicado al final del panel, siempre visible:

```qml
// Botón primario secundario (no de acento agresivo)
Rectangle {
    width: parent.width - 24
    height: 32
    color: mouseArea.containsMouse
           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
           : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
    radius: 6
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: "Abrir OmaDo"
        color: Theme.accent
        font.family: "iA Writer Mono"
        font.pixelSize: 12
    }
}
```

**Acción:** `Qt.openUrlExternally("omado://")` o `Quickshell.execDetached(["omado"])` según la API
disponible en el runtime de Omarchy. Ver §6 para el mecanismo exacto.

---

## 4. Comportamiento e Interacciones

### 4.1 Apertura y Cierre del Panel

- **Clic en BarWidget:** Toggle del panel (abre si cerrado, cierra si abierto).
- **Clic fuera del panel:** Cierra el panel automáticamente.
- **Tecla `Escape`:** Cierra el panel si está abierto.
- **El panel NO tiene header de ventana ni botón de cierre** — es un popup flotante.

### 4.2 Filtro de Tareas Completadas

Las tareas completadas **no se muestran en la lista del panel**, con una sola excepción:

> **Regla de los 10 segundos:** Una tarea que el usuario acaba de marcar como completada
> **dentro del panel** permanece visible durante exactamente **10 segundos** antes de desaparecer.
> Durante ese tiempo se muestra con estilo "completada" (texto tachado, opacidad reducida)
> y un indicador visual del tiempo restante.

**Implementación del timer de 10s:**

```js
// En Model.js
function toggleTask(taskId, currentCompleted) {
    var newState = !currentCompleted
    OmaDo.ToggleTask(taskId, newState)
    if (newState === true) {
        // Agregar a la lista de "recién completadas"
        recentlyCompleted[taskId] = Date.now()
        // Limpiar de la lista visible a los 10 segundos
        Qt.callLater(function() {
            delete recentlyCompleted[taskId]
            refreshTasks()
        }, 10000)
    }
}

function isTaskVisible(task) {
    if (!task.isCompleted) return true
    // Mostrar si fue completada en los últimos 10 segundos DESDE ESTA SESIÓN DEL PANEL
    return recentlyCompleted.hasOwnProperty(task.id)
}
```

**Indicador de tiempo restante:** Un texto pequeño a la derecha del ítem completado mostrando
los segundos restantes: `"9s"`, `"8s"`, etc. en `Theme.foreground` opacidad 0.35.

### 4.3 Reactividad — Señales D-Bus

El panel se actualiza automáticamente cuando el daemon emite:

- `TodayTasksChanged` → refrescar toda la lista (`Model.js: refreshTasks()`)
- `TasksChanged(listId)` → si `listId` corresponde a listas especiales (My Day, Tasks): refrescar

El refresco es no-bloqueante: el estado anterior permanece visible mientras llega el nuevo.

### 4.4 Eliminación de Tareas — Sin Diálogos Modales

La eliminación NO usa `Dialog`, `MessageBox` ni ningún modal. La confirmación es **inline**:

Al hacer clic en `✕` de un ítem:

1. El ítem cambia visualmente: fondo `Theme.error` con opacidad 0.1, texto en `Theme.error`.
2. Aparecen dos botones inline dentro del mismo ítem: `[Sí]` y `[No]`.
3. Si el usuario no responde en **5 segundos**: la acción se cancela automáticamente.
4. Si confirma: se llama a `DeleteTask(taskId)` via D-Bus y el ítem desaparece con animación de salida suave.

```
┌──────────────────────────────────────────────────┐
│  ¿Eliminar «Preparar presentación»?  [Sí] [No]   │
└──────────────────────────────────────────────────┘
```

### 4.5 Scroll en la Lista

Si hay más tareas que el espacio disponible, la lista hace scroll internamente:

- `ListView` con `clip: true` y `ScrollBar.vertical` visible solo al hacer scroll.
- Sin scroll horizontal.
- El botón "Abrir OmaDo" siempre está anclado al fondo, fuera del área de scroll.

---

## 5. Comunicación D-Bus

### 5.1 Interfaz Consumida

El plugin es un **cliente** del servicio `io.omarchy.OmaDo`. No registra ningún servicio propio.

**Servicio:** `io.omarchy.OmaDo`
**Path:** `/io/omarchy/OmaDo`
**Interfaz:** `io.omarchy.OmaDo`

```xml
<!-- Contrato consumido por el plugin -->
<interface name="io.omarchy.OmaDo">

  <!-- Señales reactivas -->
  <signal name="TasksChanged">
    <arg name="listId" type="s" direction="out"/>
  </signal>
  <signal name="TodayTasksChanged"/>

  <!-- Métodos utilizados por el plugin -->
  <method name="GetTasksForToday">
    <arg type="aa{sv}" direction="out"/>
  </method>

  <method name="GetTotalPendingCount">
    <arg type="i" direction="out"/>
  </method>

  <method name="ToggleTask">
    <arg name="taskId"    type="s" direction="in"/>
    <arg name="completed" type="b" direction="in"/>
    <arg type="b" direction="out"/>
  </method>

  <!-- NUEVO — requiere parche en OmaDo DaemonService -->
  <method name="DeleteTask">
    <arg name="taskId" type="s" direction="in"/>
    <arg type="b" direction="out"/>
  </method>

</interface>
```

### 5.2 Método DeleteTask — Estado

OmaDo v1.0 incluye `deleteTask(id)` en `LocalRepository` pero el `DaemonService` aún no lo
expone via D-Bus. Debe agregarse el slot `Q_SCRIPTABLE bool DeleteTask(const QString &taskId)`
al `DaemonService` antes de implementar la eliminación en el plugin.

> **Acción requerida (única vez):** Agregar `DeleteTask` a `DaemonService.h/.cpp` y regenerar
> `io.omarchy.OmaDo.xml`. Una vez hecho, el plugin puede implementar eliminación completa.

### 5.3 Mapa de Campos — GetTasksForToday

El método `GetTasksForToday()` devuelve `aa{sv}` (array de QVariantMap). Campos consumidos:

| Campo D-Bus | Tipo | Uso en el plugin |
|---|---|---|
| `id` | `s` (String) | Identificador para `ToggleTask` y `DeleteTask` |
| `title` | `s` (String) | Texto del ítem en la lista |
| `isCompleted` | `b` (Bool) | Estado del CheckCircle |
| `importance` | `s` (String) | `"high"` → indicador de importancia |
| `dueDate` | `s` (String, ISO 8601) | Mostrar si es fecha pasada (overdue) |

Campos ignorados por el plugin: `body`, `remoteId`, `recurrence`, `reminderAt`, `steps`.

### 5.4 Manejo de Errores D-Bus

Si el daemon no responde o no está en el bus:

- El `BarWidget` muestra `—` (estado desconectado).
- El panel no se abre al hacer clic.
- El plugin reintenta la conexión automáticamente cada **30 segundos**.
- No se muestran diálogos de error ni mensajes al usuario (comportamiento silencioso).

---

## 6. Apertura de la Aplicación OmaDo

El botón "Abrir OmaDo" usa el mecanismo nativo de Omarchy para lanzar la aplicación GUI.

**Método preferido:** `Quickshell.execDetached(["omado"])`

**Fallback:** `Qt.openUrlExternally("omado://open")`

> **Nota:** El mecanismo exacto se confirma durante la Fase 1 consultando la API del runtime instalado.
> OmaDo debe registrar el esquema URI `omado://` en su `.desktop` si se usa el fallback.

---

## 7. Estructura Detallada de Archivos

```
omado-plugin/
├── manifest.json              # Contrato del plugin con Omarchy Quattro
├── BarWidget.qml              # Widget compacto en la barra
├── Panel.qml                  # Panel flotante con lista de tareas
├── Model.js                   # Lógica D-Bus, estado, filtros
│
├── SPECS.md                   # Este archivo
├── AGENTS.md                  # Reglas del agente IA
├── ROADMAP.md                 # Hitos de desarrollo
│
├── README.md                  # Documentación de usuario
├── LICENSE                    # MIT
└── .gitignore
```

### 7.1 Responsabilidades por Archivo

#### `BarWidget.qml`
- Muestra el badge/contador en la barra.
- Gestiona el toggle de visibilidad del panel.
- Detecta clic y hover.
- Lee `pendingCount` y `daemonAvailable` de `Model.js`.

#### `Panel.qml`
- Panel flotante con `ListView` de tareas del día.
- Importa `Model.js` para acceder a los datos y acciones.
- Contiene los ítems de tarea con CheckCircle y botón `✕`.
- Contiene el botón "Abrir OmaDo".
- Gestiona animaciones de entrada/salida.

#### `Model.js`
- Singleton de estado: `tasks`, `pendingCount`, `daemonAvailable`, `recentlyCompleted`.
- Conexiones D-Bus: proxy al servicio `io.omarchy.OmaDo`.
- Lógica de filtrado (`isTaskVisible`).
- Lógica del timer de 10s para tareas recién completadas.
- Lógica de reintento de conexión (30s).
- Funciones exportadas: `refreshTasks()`, `toggleTask(id, completed)`, `deleteTask(id)`.

---

## 8. Restricciones Absolutas

Las siguientes restricciones son **no negociables** para este plugin.

| Prohibido | Alternativa correcta |
|---|---|
| Acceso directo a SQLite | Todo via D-Bus al daemon |
| `QProcess` o `execSync` | `Quickshell.execDetached` o D-Bus |
| Colores hardcodeados | `Theme.*` siempre |
| Checkboxes cuadrados | `Rectangle { radius: width / 2 }` |
| PNG/SVG para iconos de UI | Solo Unicode (○, ✓, ✕) |
| `Dialog`, `MessageBox`, `Alert` | Confirmación inline en el ítem |
| Múltiples instancias del plugin | `allowMultiple: false` en manifest |
| Segunda instancia de Quickshell | El plugin corre en el proceso principal |
| Fuentes distintas a iA Writer Mono | Fuente única del ecosistema |
| Scroll horizontal | Solo scroll vertical con `ScrollBar` |

---

## 9. Sistema de Theming

El plugin consume el singleton `Theme` de Omarchy Quattro directamente. No necesita implementar
`ThemeReader` propio — el shell lo inyecta automáticamente.

**Variables de tema usadas por el plugin:**

| Variable | Uso |
|---|---|
| `Theme.background` | Fondo profundo del panel |
| `Theme.surface` | Fondo del panel flotante y botones |
| `Theme.foreground` | Texto principal |
| `Theme.accent` | CheckCircle completado, botón "Abrir OmaDo" |
| `Theme.border` | Bordes del panel, separadores, texto de completadas |
| `Theme.error` | Fondo de confirmación de eliminación |

> **Nota de implementación:** El import exacto del módulo de theming se confirma revisando los
> plugins built-in de Omarchy durante la Fase 1.

---

## 10. Animaciones y Transiciones

Las animaciones deben ser **sutiles y rápidas**, en línea con la filosofía Omarchy:

| Elemento | Animación | Duración |
|---|---|---|
| Apertura del panel | `Behavior on opacity + y-offset` | 120ms ease-out |
| Cierre del panel | Fade out | 80ms |
| CheckCircle toggle | `ColorAnimation` | 150ms |
| Tarea desapareciendo (post 10s) | Fade out + height → 0 | 200ms |
| Botón eliminar (hover) | `OpacityAnimator` | 100ms |
| Hover en ítem | `ColorAnimation` en background | 80ms |

---

## 11. Dependencias y Requisitos del Sistema

| Requisito | Versión mínima | Notas |
|---|---|---|
| Omarchy Quattro | Quattro stable | Runtime del plugin |
| Quickshell | Última estable | Motor QML del shell |
| OmaDo daemon | v0.2.0 (Hito 2 completado) | Servicio D-Bus requerido |
| `io.omarchy.OmaDo` | Interface v1 + `DeleteTask` | Requiere parche en OmaDo |
| Qt 6 | 6.x (incluido en Omarchy) | Via runtime del shell |

El plugin **no tiene dependencias de sistema adicionales**.

---

## Apéndice A — Wireframe Detallado

```
┌──── BARRA SUPERIOR DE OMARCHY ────────────────────────────────────────────┐
│  [apps]  [workspaces]    [reloj]    [notificaciones]  [○ 3 tareas]  [...]  │
└───────────────────────────────────────────────────────────────────────────┘
                                                         │ clic
                                                         ▼
                                          ┌──────────────────────────┐
                                          │ Tareas de hoy            │
                                          ├──────────────────────────┤
                                          │ ○  Preparar pres.   [✕]  │
                                          │ ○  Llamar cliente   [✕]  │
                                          │ ✓  Reunión eq.  9s  [✕]  │
                                          │ ○  Revisar PRs      [✕]  │
                                          │                          │
                                          │ ─────────────────────── │
                                          │   [ Abrir OmaDo ]        │
                                          └──────────────────────────┘
```

## Apéndice B — Flujo de Datos

```
Arranque del shell
    └─ Model.js: checkDaemonAvailable()
            ├─ [OmaDo no disponible] → daemonAvailable = false → BarWidget: "—"
            │                        → retry timer 30s
            └─ [OmaDo disponible] → GetTotalPendingCount() → BarWidget: "○ N tareas"
                                  → GetTasksForToday() → Panel.qml: ListView

Usuario marca tarea como completada
    └─ Model.js: toggleTask(id, true)
            ├─ ToggleTask(id, true) via D-Bus → daemon actualiza SQLite
            ├─ recentlyCompleted[id] = now
            ├─ Tarea sigue visible 10s (con estilo completada + countdown)
            └─ [10s] → delete recentlyCompleted[id] → refreshTasks() → tarea desaparece

Daemon emite TodayTasksChanged (ej: desde la GUI de OmaDo)
    └─ Model.js: refreshTasks()
            └─ GetTasksForToday() → actualiza lista en Panel.qml reactivamente
```
