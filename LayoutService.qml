pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var monitorLayouts: ({})
    property var availableLayouts: []
    property var availableMonitors: []

    signal layoutChanged(monitor: string, layout: string)
    signal layoutsReady()
    signal monitorsReady()

    // Mirrors layout/layout.h layouts[]
    readonly property var layoutNames: ({
        "S": "Scroller",
        "T": "Tile",
        "G": "Grid",
        "M": "Monocle",
        "K": "Deck",
        "CT": "Center Tile",
        "RT": "Right Tile",
        "VS": "Vertical Scroller",
        "VT": "Vertical Tile",
        "VG": "Vertical Grid",
        "VK": "Vertical Deck",
        "DW": "Dwindle",
        "F": "Fair",
        "VF": "Vertical Fair",
    })

    readonly property var layoutDispatchMap: ({
        "T": "tile", "S": "scroller", "G": "grid", "M": "monocle",
        "K": "deck", "CT": "center_tile", "RT": "right_tile",
        "VS": "vertical_scroller", "VT": "vertical_tile",
        "VG": "vertical_grid", "VK": "vertical_deck",
        "DW": "dwindle", "F": "fair", "VF": "vertical_fair",
    })

    function getLayoutName(code: string): string {
        return layoutNames[code] || code;
    }

    function updateLayout(monitor: string, layout: string) {
        const clean = layout ? layout.trim() : "";
        if (!clean || !monitor || monitorLayouts[monitor] === clean) return;
        monitorLayouts[monitor] = clean;
        monitorLayoutsChanged();
        root.layoutChanged(monitor, clean);
    }

    function setLayout(monitorName: string, layoutCode: string) {
        if (!monitorName || !layoutCode) return;
        const dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode;
        Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + monitorName]);
        Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName]);
        updateLayout(monitorName, layoutCode);
    }

    function setLayoutGlobally(layoutCode: string) {
        const dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode;
        availableMonitors.forEach(m => {
            Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + m]);
            Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName]);
        });
    }

    function init() {
        eventWatcher.running = true;
        monitorsQuery.running = true;
        var arr = [];
        for (var code in root.layoutNames)
            arr.push({ code: code, name: root.layoutNames[code] });
        root.availableLayouts = arr;
        root.layoutsReady();
    }

    Process {
        id: eventWatcher
        command: ["mmsg", "watch", "all-monitors"]
        running: false

        stdout: SplitParser {
            onRead: function(line: string) {
                try {
                    var json = JSON.parse(line);
                    if (json.monitors) {
                        for (var i = 0; i < json.monitors.length; i++) {
                            var m = json.monitors[i];
                            root.updateLayout(m.name, m.layout_symbol);
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: monitorsQuery
        property var tempArray: []
        command: ["mmsg", "get", "all-monitors"]
        running: false

        stdout: SplitParser {
            onRead: function(line: string) {
                try {
                    var json = JSON.parse(line);
                    if (json.monitors)
                        monitorsQuery.tempArray = json.monitors.map(m => m.name);
                } catch (e) {}
            }
        }

        onExited: function(exitCode: int) {
            if (exitCode === 0) {
                root.availableMonitors = monitorsQuery.tempArray;
                monitorsQuery.tempArray = [];
                root.monitorsReady();
            }
        }
    }
}
