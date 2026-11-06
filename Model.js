.pragma library

var hosts = [];
var daemonAvailable = false;
var pendingCount = 0;
var todayTasks = [];
var overdueTasks = [];
var recentlyCompleted = {}; // taskId -> { timestamp: Number, secondsLeft: Number }

function registerHost(host) {
    if (host && hosts.indexOf(host) === -1) {
        hosts.push(host);
    }
}

function unregisterHost(host) {
    var idx = hosts.indexOf(host);
    if (idx !== -1) {
        hosts.splice(idx, 1);
    }
}

function init(barWidget) {
    registerHost(barWidget);
}

function notifyHosts(methodName) {
    for (var i = 0; i < hosts.length; i++) {
        var h = hosts[i];
        if (h && typeof h[methodName] === "function") {
            try {
                h[methodName]();
            } catch (e) {
                console.warn("[omado.panel] notifyHosts error on " + methodName + ":", e);
            }
        }
    }
}

function createProcess() {
    for (var i = 0; i < hosts.length; i++) {
        var h = hosts[i];
        if (h && typeof h.createDBusProcess === "function") {
            var p = h.createDBusProcess();
            if (p) return p;
        }
    }
    return null;
}

function runDBusCall(args, callback) {
    var proc = createProcess();
    if (!proc) {
        if (callback) callback(false, null);
        return;
    }
    var baseCmd = ["busctl", "--user", "call", "--json=short", "io.omarchy.OmaDo", "/io/omarchy/OmaDo", "io.omarchy.OmaDo"];
    if (args && args.length >= 2) {
        proc.command = baseCmd.concat([args[0], args[1], "--"]).concat(args.slice(2));
    } else {
        proc.command = baseCmd.concat(args || []);
    }
    proc.exited.connect(function(exitCode, exitStatus) {
        var success = (exitCode === 0);
        var resultData = null;
        if (success && proc.stdout && proc.stdout.text) {
            try {
                var res = JSON.parse(proc.stdout.text);
                if (res && res.data && res.data.length > 0) {
                    resultData = res.data[0];
                }
            } catch(e) {
                console.warn("[omado.panel] Failed to parse D-Bus output:", e);
                success = false;
            }
        } else if (exitCode !== 0) {
            success = false;
            var err = (proc.stderr && proc.stderr.text) ? proc.stderr.text.trim() : ("exit code " + exitCode);
            console.warn("[omado.panel] D-Bus call failed:", err);
        }
        if (callback) {
            callback(success, resultData);
        }
        proc.destroy();
    });
    proc.running = true;
}

function toggleTask(taskId, currentCompleted, callback) {
    var newState = !currentCompleted;
    var bStr = newState ? "true" : "false";

    // Optimistic local update
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
    notifyHosts("updateState");

    runDBusCall(["ToggleTask", "sb", taskId, bStr], function(success, result) {
        if (!success || result !== true) {
            // Revert state if daemon rejected or failed (Regla 8)
            notifyHosts("refreshTasks");
            if (callback) callback(false);
            return;
        }
        if (callback) callback(true);
    });
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

function updateRecentlyCompleted() {
    var now = Date.now();
    var hasExpired = false;
    for (var taskId in recentlyCompleted) {
        if (!recentlyCompleted.hasOwnProperty(taskId)) continue;
        var entry = recentlyCompleted[taskId];
        var elapsed = now - entry.timestamp;
        var left = Math.max(0, Math.ceil((10000 - elapsed) / 1000));
        entry.secondsLeft = left;
        if (left <= 0) {
            delete recentlyCompleted[taskId];
            hasExpired = true;
        }
    }
    return hasExpired;
}

function hasRecentlyCompletedTasks() {
    for (var k in recentlyCompleted) {
        if (recentlyCompleted.hasOwnProperty(k)) return true;
    }
    return false;
}

function getSecondsLeft(taskId) {
    if (!recentlyCompleted.hasOwnProperty(taskId)) return 0;
    var elapsed = Date.now() - recentlyCompleted[taskId].timestamp;
    return Math.max(0, Math.ceil((10000 - elapsed) / 1000));
}

function removeRecentlyCompleted(taskId) {
    if (recentlyCompleted.hasOwnProperty(taskId)) {
        delete recentlyCompleted[taskId];
        notifyHosts("updateState");
    }
}

function createTask(rawText, addToMyDay, callback) {
    if (!rawText || rawText.trim() === "") return;
    var bStr = (addToMyDay !== false) ? "true" : "false";

    runDBusCall(["CreateTaskFromNaturalText", "sb", rawText.trim(), bStr], function(success, result) {
        var taskId = (success && typeof result === "string") ? result : "";
        var ok = (success && taskId.length > 0);
        if (ok) {
            notifyHosts("refreshTasks");
        }
        if (callback) callback(ok, taskId);
    });
}

function rescheduleTask(taskId, callback) {
    if (!taskId) return;
    runDBusCall(["RescheduleTaskForMyDay", "s", taskId], function(success, result) {
        var ok = (success && result === true);
        if (ok) {
            overdueTasks = overdueTasks.filter(function(t) { return t.id !== taskId; });
            notifyHosts("refreshTasks");
        }
        if (callback) callback(ok);
    });
}

function deleteTask(taskId, callback) {
    if (!taskId) return;
    runDBusCall(["DeleteTask", "s", taskId], function(success, result) {
        var ok = (success && result === true);
        if (ok) {
            todayTasks = todayTasks.filter(function(t) { return t.id !== taskId; });
            overdueTasks = overdueTasks.filter(function(t) { return t.id !== taskId; });
            if (recentlyCompleted.hasOwnProperty(taskId)) {
                delete recentlyCompleted[taskId];
            }
            pendingCount = getPendingTodayCount();
            notifyHosts("refreshTasks");
            if (callback) callback(true);
        } else {
            notifyHosts("refreshTasks");
            if (callback) callback(false);
        }
    });
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
        var y = parseInt(parts[0], 10);
        var m = parseInt(parts[1], 10);
        var d = parseInt(parts[2], 10);
        var dateObj = new Date(y, m - 1, d);
        if (!isNaN(dateObj.getTime())) {
            return dateObj.toLocaleDateString(Qt.locale().name, { day: "numeric", month: "numeric" });
        }
    }
    return datePart;
}
