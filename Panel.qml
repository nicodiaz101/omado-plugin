import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omado.panel"
  ipcTarget: "omado.panel"

  property var anchorItem: null
  property var hostWidget: null

  property var tasks: []

  QtObject {
      id: theme
      readonly property color background: "#111c18"
      readonly property color surface: "#23372B"
      readonly property color foreground: "#C1C497"
      readonly property color accent: "#509475"
      readonly property color border: "#53685B"
      readonly property color error: "#FF5345"
  }

  readonly property color foregroundColor: bar ? bar.foreground : theme.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"

  Timer {
      interval: 1000
      running: root.opened
      repeat: true
      onTriggered: {
          var updated = false;
          for (var taskId in Model.recentlyCompleted) {
              Model.recentlyCompleted[taskId].secondsLeft--;
              if (Model.recentlyCompleted[taskId].secondsLeft <= 0) {
                  Model.removeRecentlyCompleted(taskId);
                  updated = true;
              }
          }
          if (updated) {
              root.tasks = Model.getVisibleTasks();
          }
      }
  }

  PopupCard {
      id: popup
      anchorItem: root.anchorItem
      owner: root
      bar: root.bar
      open: root.opened
      
      contentWidth: popup.fittedContentWidth(340)
      contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight)

      Column {
          id: mainColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(8)
          
          
          PanelHero {
              title: "OmaDo"
              meta: "TODAY TASKS"
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              iconComponent: Component {
                  Text {
                      text: "✓"
                      color: theme.accent
                      font.pixelSize: Style.font.display
                  }
              }
          }


          PanelSectionHeader {
              text: "PENDING TASKS"
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              visible: root.tasks.length > 0
          }

          Text {
              visible: root.tasks.length === 0
              text: "No pending tasks. All caught up!"
              color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.5)
              font.pixelSize: 13
              font.family: root.fontFamily
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
              topPadding: 20
              bottomPadding: 20
          }

          // Task List
          ListView {
              id: taskList
              width: parent.width
              height: Math.max(0, Math.min(320, taskList.contentHeight > 0 ? taskList.contentHeight : root.tasks.length * 40))
              clip: true
              model: root.tasks
              visible: root.tasks.length > 0
              
              delegate: Item {
                  id: taskItem
                  width: taskList.width
                  readonly property string reminderTime: Model.getReminderTime(modelData.reminderAt)
                  readonly property bool hasReminder: reminderTime !== ""
                  height: hasReminder ? 46 : 38
                  activeFocusOnTab: true
                  state: "normal"

                  Keys.onSpacePressed: if (state === "normal") Model.toggleTask(modelData.id, modelData.isCompleted)
                  Keys.onReturnPressed: if (state === "normal") Model.toggleTask(modelData.id, modelData.isCompleted)
                  Keys.onDeletePressed: if (state === "normal") taskItem.state = "confirming"
                  Keys.onEscapePressed: {
                      if (state === "confirming") {
                          taskItem.state = "normal";
                      } else {
                          root.close();
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
                          color: modelData.isCompleted ? theme.accent : "transparent"
                          border.color: modelData.isCompleted ? theme.accent : theme.border
                          border.width: 1.5

                          Behavior on color { ColorAnimation { duration: 150 } }
                          Behavior on border.color { ColorAnimation { duration: 150 } }

                          Text {
                              visible: modelData.isCompleted
                              text: "\u2713"
                              color: theme.background
                              font.pixelSize: 10
                              anchors.centerIn: parent
                          }

                          MouseArea {
                              anchors.fill: parent
                              anchors.margins: -5
                              onClicked: {
                                  taskItem.forceActiveFocus();
                                  Model.toggleTask(modelData.id, modelData.isCompleted);
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
                              text: modelData.title !== undefined ? modelData.title : "Invalid task"
                              color: modelData.isCompleted ? theme.border : root.foregroundColor
                              font.strikeout: modelData.isCompleted
                              font.pixelSize: 13
                              font.family: root.fontFamily
                              elide: Text.ElideRight
                          }

                          Rectangle {
                              id: reminderPill
                              visible: taskItem.hasReminder
                              width: reminderRow.implicitWidth + 10
                              height: 16
                              radius: 8
                              color: modelData.isCompleted
                                     ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                     : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                              border.color: modelData.isCompleted
                                            ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.25)
                                            : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.35)
                              border.width: 1

                              Row {
                                  id: reminderRow
                                  anchors.centerIn: parent
                                  spacing: 3

                                  Text {
                                      text: "\u25F7"
                                      color: modelData.isCompleted ? theme.border : theme.accent
                                      font.pixelSize: 9
                                      anchors.verticalCenter: parent.verticalCenter
                                  }

                                  Text {
                                      text: taskItem.reminderTime
                                      color: modelData.isCompleted ? theme.border : theme.accent
                                      font.pixelSize: 10
                                      font.family: root.fontFamily
                                      font.weight: Font.Medium
                                      anchors.verticalCenter: parent.verticalCenter
                                  }
                              }
                          }
                      }

                      Text {
                          id: countdownText
                          anchors.right: parent.right
                          anchors.rightMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                          text: Model.recentlyCompleted[modelData.id] ? Model.recentlyCompleted[modelData.id].secondsLeft + "s" : ""
                          visible: modelData.isCompleted && Model.recentlyCompleted[modelData.id] !== undefined
                          color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.35)
                          font.pixelSize: 11
                          font.family: root.fontFamily
                      }

                      // Delete button (✕) visible on hover
                      Text {
                          id: deleteBtn
                          visible: taskMouse.containsMouse && !modelData.isCompleted
                          anchors.right: parent.right
                          anchors.rightMargin: 15
                          anchors.verticalCenter: parent.verticalCenter
                          text: "\u2715"
                          color: deleteMouse.containsMouse ? theme.error : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.4)
                          font.pixelSize: 12

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
                          text: "Delete \"" + (modelData.title || "") + "\"?"
                          color: theme.error
                          font.pixelSize: 12
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
                                  text: "Yes"
                                  color: yesMouse.containsMouse ? theme.background : theme.error
                                  font.pixelSize: 11
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
                                      Model.deleteTask(modelData.id);
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
                                  text: "No"
                                  color: root.foregroundColor
                                  font.pixelSize: 11
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
              text: "Open OmaDo"
              foreground: root.foregroundColor
              onClicked: {
                  root.close();
                  Quickshell.execDetached(["omado"]);
              }
          }
      }
  }
}
