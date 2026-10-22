.pragma library

var host = null;
var daemonAvailable = false;
var pendingCount = 0;
var todayTasks = [];
var overdueTasks = [];
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
    if (host) host.updateState();
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
    for (var i = 0; i < todayTasks.length; i++) {
        if (isTaskVisible(todayTasks[i])) visible.push(todayTasks[i]);
    }
    return visible;
}

function removeRecentlyCompleted(taskId) {
    if (recentlyCompleted.hasOwnProperty(taskId)) {
        delete recentlyCompleted[taskId];
        if (host) host.updateState();
    }
}

function createTask(rawText, addToMyDay, callback) {
    if (!rawText || rawText.trim() === "") return;
    var bStr = (addToMyDay !== false) ? "true" : "false";
    var proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', host, "dbusProcCreate");
    proc.command = ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "CreateTaskFromNaturalText", "sb", rawText.trim(), bStr];

    var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { waitForEnd: true }', proc, "dbusProcCreateCollector");
    proc.stdout = collector;

    proc.exited.connect(function() {
        var success = (proc.exitCode === 0);
        var taskId = "";
        if (success) {
            try {
                var res = JSON.parse(collector.text);
                taskId = res.data[0];
            } catch(e) {}
            if (host && host.refreshTasks) {
                host.refreshTasks();
            }
        }
        if (callback) callback(success, taskId);
        proc.destroy();
    });
    proc.running = true;
}

function rescheduleTask(taskId, callback) {
    if (!taskId) return;
    var proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', host, "dbusProcReschedule");
    proc.command = ["busctl", "--user", "call", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "RescheduleTaskForMyDay", "s", taskId];
    proc.exited.connect(function() {
        var success = (proc.exitCode === 0);
        if (success) {
            overdueTasks = overdueTasks.filter(function(t) { return t.id !== taskId; });
            if (host && host.refreshTasks) {
                host.refreshTasks();
            } else if (host) {
                host.updateState();
            }
        }
        if (callback) callback(success);
        proc.destroy();
    });
    proc.running = true;
}

function deleteTask(taskId, callback) {
    var proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', host, "dbusProcDelete");
    proc.command = ["busctl", "--user", "call", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo", "DeleteTask", "s", taskId];
    proc.exited.connect(function() {
        if (proc.exitCode === 0) {
            todayTasks = todayTasks.filter(function(t) { return t.id !== taskId; });
            overdueTasks = overdueTasks.filter(function(t) { return t.id !== taskId; });
            if (recentlyCompleted.hasOwnProperty(taskId)) {
                delete recentlyCompleted[taskId];
            }
            pendingCount = getPendingTodayCount();
            if (callback) callback(true);
        } else {
            if (callback) callback(false);
        }
        if (host) host.updateState();
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

function getFormattedDueDate(dueDate) {
    if (!dueDate || typeof dueDate !== "string") return "";
    var datePart = dueDate.split(/[T ]/)[0];
    var parts = datePart.split("-");
    if (parts.length === 3) {
        return parts[1] + "/" + parts[2];
    }
    return datePart;
}
