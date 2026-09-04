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
              text: "PENDIENTES"
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              visible: root.tasks.length > 0
          }

          Text {
              visible: root.tasks.length === 0
              text: "No hay tareas pendientes. ¡Todo al día!"
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
              height: Math.max(0, Math.min(320, root.tasks.length * 40))
              clip: true
              model: root.tasks
              visible: root.tasks.length > 0
              
              delegate: Item {
                  id: taskItem
                  width: taskList.width
                  height: 40
                  activeFocusOnTab: true

                  Keys.onSpacePressed: Model.toggleTask(modelData.id, modelData.isCompleted)
                  Keys.onReturnPressed: Model.toggleTask(modelData.id, modelData.isCompleted)
                  Keys.onEscapePressed: root.close()

                  Rectangle {
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: taskMouse.containsMouse ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.04) : "transparent"
                      Behavior on color { ColorAnimation { duration: 80 } }
                  }

                  Rectangle {
                      visible: taskItem.activeFocus
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: "transparent"
                      border.color: theme.accent
                      border.width: 2
                  }

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

                  Text {
                      anchors.left: checkCircle.right
                      anchors.leftMargin: 10
                      anchors.right: countdownText.visible ? countdownText.left : parent.right
                      anchors.rightMargin: 15
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.title !== undefined ? modelData.title : "Tarea inválida"
                      color: modelData.isCompleted ? theme.border : root.foregroundColor
                      font.strikeout: modelData.isCompleted
                      font.pixelSize: 13
                      font.family: root.fontFamily
                      elide: Text.ElideRight
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
              }
          }

          // Footer
          Button {
              width: parent.width
              text: "Abrir OmaDo"
              foreground: root.foregroundColor
              onClicked: {
                  root.close();
                  Quickshell.execDetached(["omado"]);
              }
          }
      }
  }
}
