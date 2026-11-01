import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omado.panel"

  property bool daemonAvailable: false
  property int pendingCount: 0
  
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations {
      id: strings
      directory: Qt.resolvedUrl("i18n")
  }

  Component {
      id: dbusCallProcessComp
      Process {
          stdout: StdioCollector { waitForEnd: true }
      }
  }

  function createDBusProcess() {
      return dbusCallProcessComp.createObject(root);
  }

  function updateState() {
      daemonAvailable = Model.daemonAvailable;
      pendingCount = Model.pendingCount;
      if (panelLoader.item) {
          panelLoader.item.tasks = Model.getVisibleTasks();
          panelLoader.item.overdueTasks = Model.overdueTasks;
      }
  }

  function refreshTasks() {
      if (!dbusProcTasks.running) {
          dbusProcTasks.running = true;
      }
      if (!dbusProcOverdue.running) {
          dbusProcOverdue.running = true;
      }
  }

  Component.onCompleted: {
      Model.registerHost(root);
      root.refreshTasks();
      dbusMonitor.running = true;
  }

  Component.onDestruction: {
      Model.unregisterHost(root);
  }

  Process {
      id: dbusProcTasks
      command: ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "GetTasksForToday"]
      stdout: StdioCollector { id: tasksStdout; waitForEnd: true }
      onExited: function(exitCode, exitStatus) {
          if (exitCode === 0) {
              try {
                  var res = JSON.parse(tasksStdout.text);
                  Model.todayTasks = JSON.parse(res.data[0]);
                  Model.daemonAvailable = true;
                  Model.pendingCount = Model.getPendingTodayCount();
                  root.updateState();
              } catch(e) {
                  Model.daemonAvailable = false;
                  root.updateState();
              }
          } else {
              Model.daemonAvailable = false;
              root.updateState();
          }
      }
  }

  Process {
      id: dbusProcOverdue
      command: ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "GetOverdueTasks"]
      stdout: StdioCollector { id: overdueStdout; waitForEnd: true }
      onExited: function(exitCode, exitStatus) {
          if (exitCode === 0) {
              try {
                  var res = JSON.parse(overdueStdout.text);
                  Model.overdueTasks = JSON.parse(res.data[0]);
                  root.updateState();
              } catch(e) {
                  Model.overdueTasks = [];
              }
          }
      }
  }

  Process {
      id: dbusMonitor
      command: ["busctl", "--user", "monitor", "io.omarchy.OmaDo"]
      running: true
      stdout: SplitParser {
          onRead: function(data) {
              var line = String(data);
              if (line.indexOf("Member=TodayTasksChanged") !== -1 || line.indexOf("Member=TasksChanged") !== -1) {
                  root.refreshTasks();
              }
          }
      }
      onExited: function(exitCode, exitStatus) {
          monitorRestartTimer.restart();
      }
  }

  Timer {
      id: monitorRestartTimer
      interval: 2000
      repeat: false
      onTriggered: dbusMonitor.running = true
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  onOpenedChanged: {
      if (opened) {
          root.refreshTasks();
      }
  }

  // Polling de reintento: cada 30 segundos solo cuando el daemon no está disponible (AGENTS.md Regla 7)
  Timer {
      id: retryDaemonTimer
      interval: 30000
      running: !root.daemonAvailable
      repeat: true
      onTriggered: root.refreshTasks()
  }
  
  function injectPanel() {
      var target = panelLoader.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("settings" in target) target.settings = root.settings
      if ("anchorItem" in target) target.anchorItem = button
      if ("hostWidget" in target) target.hostWidget = root
      target.tasks = Model.getVisibleTasks()
      target.overdueTasks = Model.overdueTasks
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.daemonAvailable ? (root.pendingCount > 0 ? "\u2713 " + root.pendingCount : strings.t("bar.no_tasks", "\u2713 No tasks")) : "\u2014"
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 10
    verticalPadding: 8
    
    onPressed: function(mouse) {
        if (panelLoader.item) {
            panelLoader.item.toggle();
        }
    }
  }
}
