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

  function updateState() {
      daemonAvailable = Model.daemonAvailable;
      pendingCount = Model.pendingCount;
      if (panelLoader.item) {
          panelLoader.item.tasks = Model.getVisibleTasks();
          panelLoader.item.overdueTasks = Model.overdueTasks;
      }
  }

  function refreshTasks() {
      dbusProcTasks.running = true;
      dbusProcOverdue.running = true;
  }

  Component.onCompleted: {
      Model.init(root);
      root.refreshTasks();
      dbusMonitor.running = true;
  }

  Process {
      id: dbusProcTasks
      command: ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "GetTasksForToday"]
      stdout: StdioCollector { id: tasksStdout; waitForEnd: true }
      onExited: function(exitCode) {
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
      onExited: function(exitCode) {
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
              if (line.indexOf("TodayTasksChanged") !== -1 || line.indexOf("TasksChanged") !== -1) {
                  root.refreshTasks();
              }
          }
      }
  }

  onOpenedChanged: {
      if (opened) {
          root.refreshTasks();
      }
  }

  Timer {
      interval: 3000
      running: true
      repeat: true
      onTriggered: {
          root.refreshTasks();
      }
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
            root.refreshTasks();
            panelLoader.item.toggle();
        }
    }
  }
}
