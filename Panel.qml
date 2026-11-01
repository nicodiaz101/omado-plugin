import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omado.panel"
  ipcTarget: "omado.panel"

  property var anchorItem: null
  property var hostWidget: null

  property var tasks: []
  property var overdueTasks: []

  property int countdownTick: 0

  Commons.Translations {
      id: strings
      directory: Qt.resolvedUrl("i18n")
  }

  QtObject {
      id: theme
      readonly property color background: Commons.Color.background
      readonly property color surface: Commons.Color.popups.background
      readonly property color foreground: Commons.Color.popups.text
      readonly property color accent: Commons.Color.accent
      readonly property color border: Commons.Color.muted
      readonly property color error: Commons.Color.urgent
  }

  readonly property color foregroundColor: bar ? bar.foreground : theme.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"

  function submitNewTask() {
      var txt = newTaskInput.text.trim();
      if (txt.length === 0) return;
      Model.createTask(txt, true, function(success, taskId) {
          if (success) {
              newTaskInput.text = "";
          }
      });
  }

  Timer {
      interval: 1000
      running: true
      repeat: true
      onTriggered: {
          root.countdownTick++;
          if (Model.hasRecentlyCompletedTasks()) {
              var hasExpired = Model.updateRecentlyCompleted();
              if (hasExpired) {
                  root.tasks = Model.getVisibleTasks();
              }
          }
      }
  }

  KeyboardPanel {
      id: popup
      anchorItem: root.anchorItem
      owner: root.hostWidget || root
      bar: root.bar
      open: root.opened
      centerOnBar: false
      focusTarget: newTaskInput
      
      contentWidth: popup.fittedContentWidth(Style.space(340))
      contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight)

      Column {
          id: mainColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(8)

          PanelHero {
              title: strings.t("panel.title", "OmaDo")
              meta: strings.t("panel.meta", "TODAY'S TASKS")
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              iconComponent: Component {
                  Text {
                      text: "\u2713"
                      color: theme.accent
                      font.pixelSize: Style.font.display
                  }
              }
          }

          // Quick Task Creation (Natural Language)
          Row {
              width: parent.width
              height: 32
              spacing: 6

              TextField {
                  id: newTaskInput
                  width: parent.width - 34
                  height: 32
                  placeholderText: strings.t("panel.add_task_placeholder", "Add a task for today...")
                  foreground: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  activeFocusOnTab: true
                  selectByMouse: true

                  onAccepted: root.submitNewTask()
                  Keys.onEscapePressed: function(event) {
                      if (text.length > 0) {
                          text = "";
                          event.accepted = true;
                      } else {
                          root.close();
                          event.accepted = true;
                      }
                  }
              }

              Rectangle {
                  id: addBtn
                  width: 28
                  height: 32
                  radius: Style.cornerRadius
                  color: (addMouse.containsMouse || addBtn.activeFocus) ? theme.accent : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                  border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4)
                  border.width: 1
                  activeFocusOnTab: true

                  Keys.onReturnPressed: function(event) {
                      root.submitNewTask();
                      event.accepted = true;
                  }
                  Keys.onSpacePressed: function(event) {
                      root.submitNewTask();
                      event.accepted = true;
                  }

                  Rectangle {
                      visible: addBtn.activeFocus
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: "transparent"
                      border.color: theme.accent
                      border.width: 1.5
                  }

                  Text {
                      anchors.centerIn: parent
                      text: "+"
                      color: (addMouse.containsMouse || addBtn.activeFocus) ? theme.background : theme.accent
                      font.pixelSize: Style.font.heading
                      font.bold: true
                      font.family: root.fontFamily
                  }

                  MouseArea {
                      id: addMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.submitNewTask()
                  }
              }
          }

          // Overdue Tasks Section (if any)
          Column {
              width: parent.width
              spacing: Style.space(4)
              visible: root.overdueTasks.length > 0

              PanelSectionHeader {
                  text: strings.t("panel.overdue_tasks", "OVERDUE TASKS") + " (" + root.overdueTasks.length + ")"
                  foreground: theme.error
                  fontFamily: root.fontFamily
              }

              ListView {
                  id: overdueList
                  width: parent.width
                  height: Math.min(110, root.overdueTasks.length * 36)
                  clip: true
                  model: root.overdueTasks

                  delegate: Item {
                      id: overdueItem
                      required property var modelData
                      required property int index
                      width: overdueList.width
                      height: 34

                      Rectangle {
                          anchors.fill: parent
                          radius: Style.cornerRadius
                          color: overdueHover.hovered ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.08) : "transparent"
                      }

                      HoverHandler {
                          id: overdueHover
                      }

                      Text {
                          id: overdueBullet
                          text: "\u25CB"
                          color: theme.error
                          font.pixelSize: Style.font.body
                          anchors.left: parent.left
                          anchors.leftMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                      }

                      Column {
                          anchors.left: overdueBullet.right
                          anchors.leftMargin: 10
                          anchors.right: rescheduleBtn.left
                          anchors.rightMargin: 8
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 1

                          Text {
                              width: parent.width
                              text: overdueItem.modelData.title !== undefined ? overdueItem.modelData.title : ""
                              textFormat: Text.PlainText
                              color: root.foregroundColor
                              font.pixelSize: Style.font.body
                              font.family: root.fontFamily
                              elide: Text.ElideRight
                          }

                          Text {
                              text: Model.getFormattedDueDate(overdueItem.modelData.dueDate)
                              color: theme.error
                              font.pixelSize: Style.font.caption
                              font.family: root.fontFamily
                              visible: text !== ""
                          }
                      }

                      Rectangle {
                          id: rescheduleBtn
                          anchors.right: parent.right
                          anchors.rightMargin: 12
                          anchors.verticalCenter: parent.verticalCenter
                          width: reschedText.implicitWidth + 12
                          height: 22
                          radius: Style.cornerRadius
                          color: (reschedMouse.containsMouse || rescheduleBtn.activeFocus) ? theme.accent : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                          border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.35)
                          border.width: 1
                          activeFocusOnTab: true

                          Keys.onReturnPressed: function(event) {
                              Model.rescheduleTask(overdueItem.modelData.id);
                              event.accepted = true;
                          }
                          Keys.onSpacePressed: function(event) {
                              Model.rescheduleTask(overdueItem.modelData.id);
                              event.accepted = true;
                          }

                          Rectangle {
                              visible: rescheduleBtn.activeFocus
                              anchors.fill: parent
                              radius: Style.cornerRadius
                              color: "transparent"
                              border.color: theme.accent
                              border.width: 1.5
                          }

                          Text {
                              id: reschedText
                              anchors.centerIn: parent
                              text: "+ " + strings.t("panel.add_to_my_day", "My Day")
                              color: (reschedMouse.containsMouse || rescheduleBtn.activeFocus) ? theme.background : theme.accent
                              font.pixelSize: Style.font.caption
                              font.weight: Font.Medium
                              font.family: root.fontFamily
                          }

                          MouseArea {
                              id: reschedMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                  Model.rescheduleTask(overdueItem.modelData.id);
                              }
                          }
                      }
                  }
              }
          }

          // Today's Tasks Section Header
          PanelSectionHeader {
              text: strings.t("panel.pending_tasks", "PENDING TASKS")
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              visible: root.tasks.length > 0
          }

          // Empty state text
          Text {
              visible: root.tasks.length === 0 && root.overdueTasks.length === 0
              text: strings.t("panel.no_pending_tasks", "No pending tasks. All caught up!")
              color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.5)
              font.pixelSize: Style.font.subtitle
              font.family: root.fontFamily
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
              topPadding: 16
              bottomPadding: 16
          }

          // Task List
          ListView {
              id: taskList
              width: parent.width
              height: Math.max(0, Math.min(280, taskList.contentHeight > 0 ? taskList.contentHeight : root.tasks.length * 40))
              clip: true
              model: root.tasks
              visible: root.tasks.length > 0
              
              delegate: Item {
                  id: taskItem
                  required property var modelData
                  required property int index
                  width: taskList.width
                  readonly property string reminderTime: Model.getReminderTime(modelData.reminderAt)
                  readonly property bool hasReminder: reminderTime !== ""
                  height: hasReminder ? 46 : 38
                  activeFocusOnTab: true
                  state: "normal"

                  Keys.onReturnPressed: function(event) {
                      if (state === "normal") {
                          Model.toggleTask(modelData.id, modelData.isCompleted);
                          event.accepted = true;
                      } else if (state === "confirming") {
                          deleteCancelTimer.stop();
                          Model.deleteTask(modelData.id);
                          event.accepted = true;
                      }
                  }
                  Keys.onSpacePressed: function(event) {
                      if (state === "normal") {
                          Model.toggleTask(modelData.id, modelData.isCompleted);
                          event.accepted = true;
                      } else if (state === "confirming") {
                          deleteCancelTimer.stop();
                          Model.deleteTask(modelData.id);
                          event.accepted = true;
                      }
                  }
                  Keys.onDeletePressed: function(event) {
                      if (state === "normal") {
                          taskItem.state = "confirming";
                          event.accepted = true;
                      }
                  }
                  Keys.onEscapePressed: function(event) {
                      if (state === "confirming") {
                          taskItem.state = "normal";
                          event.accepted = true;
                      } else {
                          root.close();
                          event.accepted = true;
                      }
                  }
                  Keys.onPressed: function(event) {
                      if (state === "confirming") {
                          if (event.key === Qt.Key_Y) {
                              deleteCancelTimer.stop();
                              Model.deleteTask(modelData.id);
                              event.accepted = true;
                          } else if (event.key === Qt.Key_N) {
                              deleteCancelTimer.stop();
                              taskItem.state = "normal";
                              event.accepted = true;
                          }
                      }
                  }

                  Timer {
                      id: deleteCancelTimer
                      interval: 5000
                      repeat: false
                      onTriggered: taskItem.state = "normal"
                  }

                  onStateChanged: {
                      if (state === "confirming") deleteCancelTimer.restart();
                      else deleteCancelTimer.stop();
                  }

                  Rectangle {
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: taskItem.state === "confirming" ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.12)
                             : (taskMouse.containsMouse ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.04) : "transparent")
                      Behavior on color { ColorAnimation { duration: 80 } }
                  }

                  Rectangle {
                      visible: taskItem.activeFocus
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: "transparent"
                      border.color: taskItem.state === "confirming" ? theme.error : theme.accent
                      border.width: 2
                  }

                  // Normal task row
                  Item {
                      id: normalContent
                      anchors.fill: parent
                      visible: taskItem.state === "normal"

                      MouseArea {
                          id: taskMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: {
                              taskItem.forceActiveFocus();
                          }
                      }

                      Rectangle {
                          id: checkCircle
                          width: 16
                          height: 16
                          radius: width / 2
                          anchors.left: parent.left
                          anchors.leftMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                          color: taskItem.modelData.isCompleted ? theme.accent : "transparent"
                          border.color: taskItem.modelData.isCompleted ? theme.accent : theme.border
                          border.width: 1.5

                          Behavior on color { ColorAnimation { duration: 150 } }
                          Behavior on border.color { ColorAnimation { duration: 150 } }

                          Text {
                              visible: taskItem.modelData.isCompleted
                              text: "\u2713"
                              color: theme.background
                              font.pixelSize: Style.font.caption
                              anchors.centerIn: parent
                          }

                          MouseArea {
                              anchors.fill: parent
                              anchors.margins: -5
                              onClicked: {
                                  taskItem.forceActiveFocus();
                                  Model.toggleTask(taskItem.modelData.id, taskItem.modelData.isCompleted);
                              }
                          }
                      }

                      Column {
                          anchors.left: checkCircle.right
                          anchors.leftMargin: 10
                          anchors.right: deleteBtn.visible ? deleteBtn.left : (countdownText.visible ? countdownText.left : parent.right)
                          anchors.rightMargin: 10
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 2

                          Text {
                              width: parent.width
                              text: taskItem.modelData.title !== undefined ? taskItem.modelData.title : ""
                              textFormat: Text.PlainText
                              color: taskItem.modelData.isCompleted ? theme.border : root.foregroundColor
                              font.strikeout: taskItem.modelData.isCompleted
                              font.pixelSize: Style.font.subtitle
                              font.family: root.fontFamily
                              elide: Text.ElideRight
                          }

                          Rectangle {
                              id: reminderPill
                              visible: taskItem.hasReminder
                              width: reminderRow.implicitWidth + 10
                              height: 16
                              radius: 8
                              color: taskItem.modelData.isCompleted
                                     ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                     : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                              border.color: taskItem.modelData.isCompleted
                                            ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.25)
                                            : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.35)
                              border.width: 1

                              Row {
                                  id: reminderRow
                                  anchors.centerIn: parent
                                  spacing: 3

                                  Text {
                                      text: "\u25F7"
                                      color: taskItem.modelData.isCompleted ? theme.border : theme.accent
                                      font.pixelSize: 9
                                      anchors.verticalCenter: parent.verticalCenter
                                  }

                                  Text {
                                      text: taskItem.reminderTime
                                      color: taskItem.modelData.isCompleted ? theme.border : theme.accent
                                      font.pixelSize: Style.font.caption
                                      font.family: root.fontFamily
                                      font.weight: Font.Medium
                                      anchors.verticalCenter: parent.verticalCenter
                                  }
                              }
                          }
                      }

                      Text {
                          id: countdownText
                          property int _tick: root.countdownTick
                          anchors.right: parent.right
                          anchors.rightMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                          text: Model.recentlyCompleted[taskItem.modelData.id] ? Model.getSecondsLeft(taskItem.modelData.id) + "s" : ""
                          visible: taskItem.modelData.isCompleted && Model.recentlyCompleted[taskItem.modelData.id] !== undefined
                          color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.35)
                          font.pixelSize: Style.font.bodySmall
                          font.family: root.fontFamily
                      }

                      // Delete button (✕) visible on hover
                      Text {
                          id: deleteBtn
                          visible: taskMouse.containsMouse && !taskItem.modelData.isCompleted
                          anchors.right: parent.right
                          anchors.rightMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                          text: "\u2715"
                          color: deleteMouse.containsMouse ? theme.error : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.4)
                          font.pixelSize: Style.font.body

                          MouseArea {
                              id: deleteMouse
                              anchors.fill: parent
                              anchors.margins: -6
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                  taskItem.forceActiveFocus();
                                  taskItem.state = "confirming";
                              }
                          }
                      }
                  }

                  // Confirming delete row (Inline)
                  Item {
                      id: confirmContent
                      anchors.fill: parent
                      visible: taskItem.state === "confirming"

                      Text {
                          anchors.left: parent.left
                          anchors.leftMargin: 15
                          anchors.right: confirmActions.left
                          anchors.rightMargin: 8
                          anchors.verticalCenter: parent.verticalCenter
                          text: strings.t("panel.delete_confirm", "Delete \"%1\"?").arg(taskItem.modelData.title || "")
                          textFormat: Text.PlainText
                          color: theme.error
                          font.pixelSize: Style.font.body
                          font.family: root.fontFamily
                          elide: Text.ElideRight
                      }

                      Row {
                          id: confirmActions
                          anchors.right: parent.right
                          anchors.rightMargin: 12
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 6

                          Rectangle {
                              width: 38
                              height: 24
                              radius: Style.cornerRadius
                              color: yesMouse.containsMouse ? theme.error : Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.25)

                              Text {
                                  anchors.centerIn: parent
                                  text: strings.t("panel.yes", "Yes")
                                  color: yesMouse.containsMouse ? theme.background : theme.error
                                  font.pixelSize: Style.font.bodySmall
                                  font.bold: true
                                  font.family: root.fontFamily
                              }

                              MouseArea {
                                  id: yesMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                      deleteCancelTimer.stop();
                                      Model.deleteTask(taskItem.modelData.id);
                                  }
                              }
                          }

                          Rectangle {
                              width: 34
                              height: 24
                              radius: Style.cornerRadius
                              color: noMouse.containsMouse ? Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.15) : "transparent"
                              border.color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.25)

                              Text {
                                  anchors.centerIn: parent
                                  text: strings.t("panel.no", "No")
                                  color: root.foregroundColor
                                  font.pixelSize: Style.font.bodySmall
                                  font.family: root.fontFamily
                              }

                              MouseArea {
                                  id: noMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                      deleteCancelTimer.stop();
                                      taskItem.state = "normal";
                                  }
                              }
                          }
                      }
                  }
              }
          }

          // Footer
          Button {
              width: parent.width
              text: strings.t("panel.open_omado", "Open OmaDo")
              foreground: root.foregroundColor
              onClicked: {
                  root.close();
                  Quickshell.execDetached(["omado"]);
              }
          }
      }
  }
}
