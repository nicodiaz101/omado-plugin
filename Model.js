.pragma library

var host = null;
var daemonAvailable = false;
var pendingCount = 0;
var todayTasks = [];
var recentlyCompleted = {};

function init(barWidget) {
    host = barWidget;
}

function toggleTask(taskId, currentCompleted) {
    var newState = !currentCompleted;
    var bStr = newState ? "true" : "false";
    
    var proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', host, "dbusProcToggle");
    proc.command = ["busctl", "--user", "call", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "ToggleTask", "sb", taskId, bStr];
    proc.exited.connect(function() {
        // Optimistically we just ignore failure for now, 
        // if it fails it will resync on the broadcast
        proc.destroy();
    });
    proc.running = true;

    if (newState === true) {
        recentlyCompleted[taskId] = { timestamp: Date.now(), secondsLeft: 10 };
    } else {
        if (recentlyCompleted.hasOwnProperty(taskId)) {
            delete recentlyCompleted[taskId];
        }
    }
    host.updateState();
}

function isTaskVisible(task) {
    if (!task.isCompleted) return true;
    return recentlyCompleted.hasOwnProperty(task.id);
}

function getVisibleTasks() {
    var visible = [];
    for (var i=0; i<todayTasks.length; i++) {
        if (isTaskVisible(todayTasks[i])) visible.push(todayTasks[i]);
    }
    return visible;
}

function removeRecentlyCompleted(taskId) {
    if (recentlyCompleted.hasOwnProperty(taskId)) {
        delete recentlyCompleted[taskId];
        host.updateState();
    }
}
