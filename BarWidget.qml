import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omado.panel"

  property bool daemonAvailable: false
  property int pendingCount: 0
  
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function updateState() {
      daemonAvailable = Model.daemonAvailable;
      pendingCount = Model.pendingCount;
      if (panelLoader.item) {
          panelLoader.item.tasks = Model.getVisibleTasks();
      }
  }

  Component.onCompleted: {
      Model.init(root);
      dbusProcCount.running = true;
      dbusMonitor.running = true;
  }

  Process {
      id: dbusProcCount
      command: ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "GetTotalPendingCount"]
      stdout: StdioCollector { id: countStdout; waitForEnd: true }
      onExited: function(exitCode) {
          if (exitCode === 0) {
              try {
                  var res = JSON.parse(countStdout.text);
                  Model.pendingCount = res.data[0];
                  Model.daemonAvailable = true;
              } catch(e) {
                  Model.daemonAvailable = false;
                  Model.pendingCount = 0;
              }
          } else {
              Model.daemonAvailable = false;
              Model.pendingCount = 0;
          }
          root.updateState();
      }
  }

  Process {
      id: dbusProcTasks
      command: ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "GetTasksForToday"]
      stdout: StdioCollector { id: tasksStdout; waitForEnd: true }
      onExited: function(exitCode) {
          if (exitCode === 0) {
              try {
                  var res = JSON.parse(tasksStdout.text);
                  // Since GetTasksForToday now returns a JSON string in D-Bus (signature 's')
                  // res.data[0] is that string. We need to parse it to get the tasks array.
                  Model.todayTasks = JSON.parse(res.data[0]);
                  root.updateState();
              } catch(e) {
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
                  dbusProcCount.running = true;
                  if (panelLoader.item && panelLoader.item.opened) {
                      dbusProcTasks.running = true;
                  }
              }
          }
      }
  }

  Timer {
      interval: 30000
      running: !root.daemonAvailable
      repeat: true
      onTriggered: dbusProcCount.running = true
  }
  
  function injectPanel() {
      var target = panelLoader.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("settings" in target) target.settings = root.settings
      if ("anchorItem" in target) target.anchorItem = button
      if ("hostWidget" in target) target.hostWidget = root
      target.tasks = Model.todayTasks
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
    text: root.daemonAvailable ? (root.pendingCount > 0 ? "\u2713 " + root.pendingCount : "\u2713 Sin tareas") : "\u2014"
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 10
    verticalPadding: 8
    
    onPressed: function(mouse) {
        if (root.daemonAvailable && panelLoader.item) {
            panelLoader.item.toggle();
            if (panelLoader.item.opened) {
                dbusProcTasks.running = true;
            }
        }
    }
  }
}
