import QtQuick
import Quickshell
import Quickshell.Io
import "lib/system_metrics.js" as Metrics

// Read procfs directly: no monitoring daemon or recurring shell processes.
Scope {
    id: root

    property bool active: true
    property int refreshInterval: 1000
    property real cpuUsage: -1
    property real memoryUsed: 0
    property real memoryTotal: 0
    readonly property real memoryUsage: memoryTotal > 0 ? memoryUsed / memoryTotal : -1
    property var previousCpu: null

    onActiveChanged: {
        if (!active) {
            previousCpu = null;
            cpuUsage = -1;
        }
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        preload: root.active
        printErrors: false
        onLoaded: {
            if (!root.active) return;
            const sample = Metrics.parseCpu(cpuFile.text());
            const usage = Metrics.cpuUsage(root.previousCpu, sample);
            root.previousCpu = sample;
            root.cpuUsage = usage === null ? -1 : usage;
        }
        onLoadFailed: {
            root.previousCpu = null;
            root.cpuUsage = -1;
        }
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        preload: root.active
        printErrors: false
        onLoaded: {
            if (!root.active) return;
            const memory = Metrics.parseMemory(memoryFile.text());
            root.memoryUsed = memory ? memory.used : 0;
            root.memoryTotal = memory ? memory.total : 0;
        }
        onLoadFailed: {
            root.memoryUsed = 0;
            root.memoryTotal = 0;
        }
    }

    Timer {
        interval: root.refreshInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memoryFile.reload();
        }
    }
}
