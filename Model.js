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
    for (var i = 0; i < todayTasks.length; i++) {
        if (todayTasks[i].id === taskId) {
            todayTasks[i].isCompleted = newState;
            break;
        }
    }
    pendingCount = getPendingTodayCount();
    host.updateState();
}

function getPendingTodayCount() {
    var count = 0;
    for (var i = 0; i < todayTasks.length; i++) {
        if (!todayTasks[i].isCompleted) count++;
    }
    return count;
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

function deleteTask(taskId, callback) {
    var proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', host, "dbusProcDelete");
    proc.command = ["busctl", "--user", "call", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "DeleteTask", "s", taskId];
    proc.exited.connect(function() {
        if (proc.exitCode === 0) {
            todayTasks = todayTasks.filter(function(t) { return t.id !== taskId; });
            if (recentlyCompleted.hasOwnProperty(taskId)) {
                delete recentlyCompleted[taskId];
            }
            pendingCount = getPendingTodayCount();
            if (callback) callback(true);
        } else {
            if (callback) callback(false);
        }
        host.updateState();
        proc.destroy();
    });
    proc.running = true;
}

function getReminderTime(reminderAt) {
    if (!reminderAt || typeof reminderAt !== "string") return "";
    var parts = reminderAt.split(/[T ]/);
    if (parts.length > 1) {
        var timeParts = parts[1].split(':');
        if (timeParts.length >= 2) {
            return timeParts[0] + ":" + timeParts[1];
        }
    }
    return "";
}
