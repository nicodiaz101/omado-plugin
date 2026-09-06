# ROADMAP.md — Hitos de Desarrollo del Plugin OmaDo Panel

> Plugin QuickShell para la barra superior de Omarchy Quattro
> **Convención:** 🔲 Pendiente · 🔄 En progreso · ✅ Completado · ⛔ Bloqueado

---

## Contexto del Proyecto

Este plugin es el **Hito 4** del proyecto OmaDo (ver `/home/nicolas/Github/omado/ROADMAP.md`).
Se desarrolla en su propio repositorio (`omado-plugin`) y consume el daemon de OmaDo via D-Bus.

**Pre-requisito obligatorio:** OmaDo daemon v0.2.0 o superior corriendo y registrado en el
session bus como `io.omarchy.OmaDo`. El daemon debe implementar los métodos especificados
en `SPECS.md §5`.

---

## Fase 1 — Fundación: Widget en Barra + Panel Básico

> **Objetivo:** Plugin instalado y funcionando en la barra de Omarchy. El usuario puede ver
> sus tareas del día, marcarlas como completadas (con el timer de 10s) y abrir OmaDo.
> **Criterio de éxito:** `omarchy-shell shell rescanPlugins` activa el plugin. El BarWidget
> muestra el conteo correcto. Clic abre el panel. Toggle del checkbox funciona via D-Bus.
> El filtro de 10s funciona correctamente para tareas recién completadas.

---

### Hito 1.1 — Scaffolding y Contrato del Plugin

- ✅ Verificar versión de Omarchy Quattro instalada y disponibilidad del sistema de plugins.
- ✅ Inspeccionar plugins built-in de Omarchy (especialmente `omarchy.clock`) para:
  - Confirmar namespace de import de Theme.
  - Confirmar API D-Bus disponible (tipo QML para proxy D-Bus).
  - Confirmar dimensiones y padding estándar de la barra.
  - Confirmar mecanismo para lanzar aplicaciones.
- ✅ Crear `manifest.json` con el contrato correcto para `bar-widget`.
- ✅ Verificar que `io.omarchy.OmaDo` está corriendo: `busctl --user list | grep OmaDo`.
- ✅ Crear directorio del plugin en `~/.config/omarchy/plugins/omado.panel/`.
- ✅ Crear `Model.js` con esqueleto de conexión D-Bus (solo `GetTotalPendingCount`).
- ✅ Crear `BarWidget.qml` mínimo que muestre texto estático.
- ✅ Ejecutar `omarchy-shell shell rescanPlugins` y confirmar que el plugin aparece en la barra.

**Criterio de completado:** El plugin carga sin errores y aparece en la barra con texto estático.

---

### Hito 1.2 — BarWidget con Badge en Tiempo Real

- ✅ Implementar en `Model.js`: `checkDaemonAvailable()` con manejo silencioso de errores.
- ✅ Implementar en `Model.js`: conexión D-Bus a `GetTotalPendingCount()`.
- ✅ Implementar en `Model.js`: timer de reintento 30s cuando daemon no disponible.
- ✅ Implementar en `Model.js`: suscripción a señal `TodayTasksChanged` → `refreshCount()`.
- ✅ Actualizar `BarWidget.qml` con los cuatro estados visuales (ver SPECS §3.1):
  - Daemon activo, tareas > 0: `○ N tareas`
  - Daemon activo, sin tareas: `○ Sin tareas` (opacidad 0.45)
  - Daemon no disponible: `—` (opacidad 0.35, sin acción al clic)
  - Cargando: `…` (animación de parpadeo suave)
- ✅ Verificar theming: todos los colores via `Theme.*`, fuente `iA Writer Mono`.
- ✅ Verificar que el badge se actualiza reactivamente cuando el daemon emite `TodayTasksChanged`.

**Criterio de completado:** Badge muestra conteo correcto. Se actualiza cuando se crean/completan
tareas desde la GUI de OmaDo sin reiniciar el plugin.

---

### Hito 1.3 — Panel Flotante con Lista de Tareas

- ✅ Implementar en `Model.js`: `refreshTasks()` via `GetTasksForToday()`.
- ✅ Implementar en `Model.js`: `isTaskVisible(task)` — filtro de completadas.
- ✅ Crear `Panel.qml` con estructura base:
  - Header "Tareas de hoy" (texto `Theme.foreground` opacidad 0.5, pixelSize: 11).
  - `ListView` con `clip: true` y `ScrollBar.vertical`.
  - Separador horizontal 1px `Theme.border`.
  - Botón "Abrir OmaDo" (ver SPECS §3.4).
- ✅ Implementar ítems de tarea en la lista:
  - `CheckCircle` (16px, `radius: width/2`) — círculo ○ → ✓ con animación 150ms.
  - Título: `Theme.foreground`, `iA Writer Mono`, `font.pixelSize: 13`, `elide: Text.ElideRight`.
  - Título completado: `Theme.border` + `font.strikeout: true`.
  - Hover: fondo sutil `Qt.rgba(..., 0.04)`.
- ✅ Implementar toggle del panel al clic en BarWidget.
- ✅ Implementar cierre al clic fuera del panel.
- ✅ Implementar cierre con tecla `Escape`.
- ✅ Verificar posicionamiento: panel aparece debajo del BarWidget sin salirse de la pantalla.

**Criterio de completado:** Panel abre y cierra correctamente. Lista muestra las tareas del día.
Los CheckCircles son círculos perfectos (no cuadrados). El botón "Abrir OmaDo" es visible.

---

### Hito 1.4 — Toggle de Tareas + Timer de 10 Segundos

- ✅ Implementar en `Model.js`: `toggleTask(taskId, currentCompleted)` con llamada D-Bus `ToggleTask`.
- ✅ Implementar en `Model.js`: diccionario `recentlyCompleted` con timestamp por tarea.
- ✅ Implementar en `Model.js`: `getSecondsLeft(taskId)` para el countdown display.
- ✅ Implementar en `Panel.qml`: Timer de 1s que decrementa `secondsLeft` de tareas completadas.
- ✅ Implementar en `Panel.qml`: Timer de 10s que elimina la tarea de `recentlyCompleted` y llama `refreshTasks()`.
- ✅ Implementar display del countdown: texto `"Ns"` a la derecha del ítem completado
  (`Theme.foreground` opacidad 0.35, `iA Writer Mono`, pixelSize: 11).
- ✅ Verificar que tareas completadas desde la GUI de OmaDo (señal D-Bus) NO tienen timer de gracia.
- ✅ Verificar que desmarcar una tarea dentro de los 10s cancela el countdown.
- ✅ Verificar comportamiento al cerrar/abrir el panel durante los 10s.

**Criterio de completado:** El flujo completo funciona: marcar tarea → permanece visible 10s con
countdown → desaparece con animación suave. El badge del BarWidget se actualiza instantáneamente.

---

### Hito 1.5 — Botón "Abrir OmaDo" + Accesibilidad

- ✅ Implementar acción del botón "Abrir OmaDo" con el mecanismo confirmado en Hito 1.1.
- ✅ Verificar que el panel se cierra antes de lanzar OmaDo.
- ✅ Implementar navegación por teclado:
  - `Tab` / `Shift+Tab` entre ítems de la lista.
  - `Space` / `Enter` para toggle del ítem con foco.
  - `Escape` para cerrar el panel.
- ✅ Agregar `activeFocusOnTab: true` en todos los elementos interactivos.
- ✅ Agregar `FocusRect` (2px `Theme.accent`) en todos los elementos con foco.
- ✅ Verificar animaciones: apertura/cierre del panel (120ms/80ms), hover en ítems (80ms).

**Criterio de completado:** El plugin es completamente usable con teclado. Las animaciones son
sutiles y no interfieren con la usabilidad.

---

### Hito 1.6 — Posición Configurable en la Barra

- ✅ Verificar mecanismo de settings del manifest (`settings.position`) con la documentación de Omarchy.
- ✅ Implementar lectura de la posición configurada por el usuario.
- ✅ Verificar que el plugin aparece correctamente en las tres posiciones: `left`, `center`, `right`.
- ✅ Verificar que el panel flotante se posiciona correctamente según la sección elegida.

**Criterio de completado:** El usuario puede cambiar la posición del plugin en la configuración de Omarchy
y el widget aparece en la posición correcta sin reiniciar el shell.

---

## Fase 2 — Eliminación de Tareas + Pulido

> **Objetivo:** El usuario puede eliminar tareas desde el panel con confirmación inline.
> El plugin está listo para publicación en el marketplace de Omarchy.
> **Criterio de éxito:** Eliminación con confirmación 5s funciona. El plugin pasa la validación
> del manifest de Omarchy para publicación.
> **Pre-requisito:** Método `DeleteTask` disponible en OmaDo daemon.

---

### Hito 2.1 — Exponer DeleteTask en el DaemonService de OmaDo

OmaDo v1.0 ya tiene `LocalRepository::deleteTask(id)` implementado. Solo falta exponerlo
via D-Bus en el `DaemonService`. Esta tarea se hace en el repositorio de OmaDo.

- ✅ Agregar a `DaemonService.h`:
  ```cpp
  Q_SCRIPTABLE bool DeleteTask(const QString &taskId);
  ```
- ✅ Implementar en `DaemonService.cpp`:
  ```cpp
  bool DaemonService::DeleteTask(const QString &taskId) {
      if (!m_repository) return false;
      auto taskFuture = m_repository->fetchTaskById(taskId);
      Task t = taskFuture.result();
      if (t.id.isEmpty()) return false;
      auto future = m_repository->deleteTask(taskId);
      bool ok = future.result();
      if (ok) {
          emit TasksChanged(t.listId);
          emit TodayTasksChanged();
      }
      return ok;
  }
  ```
- ✅ Actualizar `io.omarchy.OmaDo.xml` agregando el método `DeleteTask`.
- ✅ Verificar con `busctl`: `busctl --user call io.omarchy.OmaDo /io/omarchy/OmaDo io.omarchy.OmaDo DeleteTask s "test-id"`.

**Criterio de completado:** `DeleteTask` responde en el bus D-Bus y el daemon emite `TodayTasksChanged` al completar.

---

### Hito 2.2 — Eliminación con Confirmación Inline

*(Ejecutar solo cuando Hito 2.1 está desbloqueado)*

- ✅ Implementar en `Model.js`: `deleteTask(taskId)` con llamada D-Bus `DeleteTask`.
- ✅ Implementar botón `✕` en cada ítem de tarea (visible solo en hover).
- ✅ Implementar estado `"confirming"` en el ítem:
  - Fondo: `Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)`.
  - Texto: `"¿Eliminar «título»?"` en `Theme.error`.
  - Botones inline: `[Sí]` y `[No]`.
- ✅ Implementar Timer 5s de auto-cancelación de confirmación.
- ✅ Implementar animación de salida del ítem al confirmar eliminación.
- ✅ Verificar que la eliminación se refleja en el badge del BarWidget.
- ✅ Verificar que `TodayTasksChanged` se emite por el daemon tras la eliminación.
- ✅ Agregar `Delete` key como atajo para iniciar el flujo de eliminación del ítem con foco.

**Criterio de completado:** Eliminación funciona end-to-end con confirmación inline de 5s.
No hay modales. El ítem desaparece con animación suave al confirmar.

---

### Hito 2.3 — Pulido Visual y Consistencia

- ✅ Revisión final de toda la UI contra los plugins built-in de Omarchy:
  - Padding, spacing y dimensiones.
  - Comportamiento de hover en todos los elementos.
  - Consistencia de fuentes y tamaños.
- ✅ Probar con al menos 3 temas de Omarchy diferentes (cambiar `colors.toml`).
- ✅ Verificar que el plugin se recarga correctamente cuando cambia el tema.
- ✅ Probar con 0, 1, 5, 10 y 15+ tareas (caso borde del scroll).
- ✅ Verificar comportamiento cuando el daemon se detiene y se reinicia con el panel abierto.
- ✅ Verificar comportamiento en múltiples monitores (si aplica en el entorno del usuario).

**Criterio de completado:** El plugin es visualmente indistinguible de los plugins built-in
de Omarchy. Ningún regresión visual tras cambios de tema.

---

### Hito 2.4 — Documentación y Publicación

- ✅ Escribir `README.md` con:
  - Descripción del plugin y captura de pantalla.
  - Requisitos: OmaDo daemon v0.2.0+, Omarchy Quattro.
  - Instrucciones de instalación manual.
  - Configuración de posición en la barra.
  - Solución de problemas frecuentes.
- ✅ Actualizar `manifest.json` con versión final y metadata para el marketplace.
- ✅ Verificar validación del manifest con `omarchy plugin validate`.
- ✅ Crear tag `v1.0.0` en el repositorio.
- ✅ Preparar submission al marketplace de Omarchy Quattro plugins.

**Criterio de completado:** Plugin publicado o listo para publicación. README completo y preciso.

---

## Tabla de Versiones

| Versión | Fase completada | Funcionalidades | Estado |
|---|---|---|---|
| v0.1.0-alpha | Fase 1, Hitos 1.1–1.3 | Widget en barra + panel básico | 🔲 |
| v0.2.0-alpha | Fase 1, Hito 1.4 | Timer 10s para completadas | 🔲 |
| v0.3.0-alpha | Fase 1, Hitos 1.5–1.6 | Accesibilidad + posición configurable | 🔲 |
| v1.0.0 | Fase 2, Hitos 2.1–2.4 | Eliminación + pulido + publicación | 🔲 |

---

## Dependencias Externas (Tracking)

| Dependencia | Repositorio | Estado | Descripción |
|---|---|---|---|
| OmaDo daemon v1.0 | `/home/nicolas/Github/omado` | ✅ Completo | OmaDo v1.0 finalizado con todas las funciones base |
| Método `DeleteTask` en D-Bus | `/home/nicolas/Github/omado` | 🔲 Tarea puntual | `LocalRepository.deleteTask()` existe — solo falta exponerlo en `DaemonService` |
| Omarchy Quattro plugin system | Sistema instalado | 🔲 Por verificar | Verificar en Hito 1.1 |

---

## Notas de Desarrollo

### Inspección de Referencia (Hito 1.1 — obligatorio leer antes de codificar)

```bash
# Localizar el plugin del reloj como referencia principal
find /usr/share/omarchy ~/.config/omarchy -name "BarWidget.qml" 2>/dev/null

# Listar todos los plugins disponibles
find /usr/share/omarchy ~/.config/omarchy -name "manifest.json" 2>/dev/null

# Verificar servicio D-Bus de OmaDo
busctl --user list | grep -i omado
busctl --user introspect io.omarchy.OmaDo /io/omarchy/OmaDo 2>/dev/null

# Instalar y recargar el plugin durante desarrollo
mkdir -p ~/.config/omarchy/plugins/omado.panel
cp -r . ~/.config/omarchy/plugins/omado.panel/
omarchy-shell shell rescanPlugins
```

### Archivo de Referencia de Omarchy Shell

Consultar siempre antes de asumir APIs o comportamientos:
`https://github.com/omacom/omarchy/blob/quattro/shell/README.md`

### Principio de Desarrollo Iterativo

Verificar manualmente el resultado en la barra tras cada hito. Los hitos deben completarse
en orden — no avanzar al siguiente si el criterio de completado del anterior no está satisfecho.
