import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    visible: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "mango-layout-switcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Component.onCompleted: {
        Config.scaling = root.screen ? root.screen.devicePixelRatio : 1.0;
        LayoutService.init();
    }

    Connections {
        target: root.screen ?? null

        function onDevicePixelRatioChanged() {
            Config.scaling = root.screen ? root.screen.devicePixelRatio : 1.0;
        }
    }

    property bool layoutsReady: false
    property bool monitorsReady: false
    readonly property bool serviceReady: layoutsReady && monitorsReady

    Connections {
        target: LayoutService

        function onLayoutsReady() { root.layoutsReady = true; }
        function onMonitorsReady() { root.monitorsReady = true; }
    }

    FileView {
        id: settingsFile

        path: Quickshell.shellDir + "/settings.json"
        watchChanges: true

        JsonAdapter {
            id: settings

            property var monitorOrder: []
        }
    }

    function saveSettings() {
        settingsFile.writeAdapter();
    }

    FontLoader {
        id: iconFont

        source: Qt.resolvedUrl("Assets/Icons/tabler-icons.ttf")
    }

    readonly property var tablerIcons: ({
        "layout-grid": "",
        "layout-sidebar": "",
        "rectangle": "",
        "carousel-horizontal": "",
        "carousel-vertical": "",
        "layout-rows": "",
        "grid-dots": "",
        "versions": "",
        "layout-sidebar-right": "",
        "layout-distribute-vertical": "",
        "layout-dashboard": "",
        "chart-funnel": "ﻵ",
        "grip-vertical": "",
        "check": "",
        "layout-collage": "",
        "layout-board-split": "",
        "layout-board": ""
    })
    readonly property var iconMap: ({
        "T": "layout-sidebar",
        "M": "rectangle",
        "S": "carousel-horizontal",
        "G": "layout-grid",
        "K": "versions",
        "RT": "layout-sidebar-right",
        "CT": "layout-distribute-vertical",
        "DW": "layout-collage",
        "F":  "layout-board-split",
        "VF": "layout-board",
        "VT": "layout-rows",
        "VS": "carousel-vertical",
        "VG": "grid-dots",
        "VK": "chart-funnel"
    })

    function icon(name: string): string {
        return tablerIcons[name] || "";
    }

    property var orderedMonitors: {
        const all = LayoutService.availableMonitors;
        const order = settings.monitorOrder;
        if (!order || !order.length) return all;
        return order.filter(m => all.includes(m))
                    .concat(all.filter(m => !order.includes(m)));
    }

    property bool applyToAll: false
    property var selectedMonitors: []

    readonly property string panelMonitor: orderedMonitors.length > 0 ? orderedMonitors[0] : ""
    readonly property var layouts: LayoutService.availableLayouts
    readonly property string activeLayout: {
        const mon = selectedMonitors.length > 0 ? selectedMonitors[0] : panelMonitor;
        return LayoutService.monitorLayouts[mon] || "";
    }

    property int keyboardFocusedIndex: -1
    property int hoveredIndex: -1
    property string lastFocusMethod: "hover"
    readonly property int gridColumns: 3

    function navigateKeyboard(direction: string) {
        const count = layouts.length;
        if (count === 0) return;

        let idx;
        if (lastFocusMethod === "hover" && hoveredIndex >= 0 && hoveredIndex < count) {
            idx = hoveredIndex;
        } else if (keyboardFocusedIndex >= 0 && keyboardFocusedIndex < count) {
            idx = keyboardFocusedIndex;
        } else {
            idx = layouts.findIndex(l => l.code === activeLayout);
            if (idx < 0) idx = 0;
        }

        const col = idx % gridColumns;
        const row = Math.floor(idx / gridColumns);

        switch (direction) {
        case "left":
            idx = col > 0 ? idx - 1 : Math.min(idx + gridColumns - 1, count - 1);
            break;
        case "right":
            idx = col < gridColumns - 1 && idx + 1 < count ? idx + 1 : row * gridColumns;
            break;
        case "up":
            idx = row > 0
                ? idx - gridColumns
                : Math.min((Math.ceil(count / gridColumns) - 1) * gridColumns + col, count - 1);
            break;
        case "down":
            idx = idx + gridColumns < count ? idx + gridColumns : col;
            break;
        }

        keyboardFocusedIndex = idx;
        lastFocusMethod = "keyboard";
    }

    function applyFocusedLayout() {
        if (keyboardFocusedIndex >= 0 && keyboardFocusedIndex < layouts.length) {
            applyLayout(layouts[keyboardFocusedIndex].code);
        }
    }

    function applyMonitorReorder(from: int, to: int) {
        if (from === to) return;
        const arr = orderedMonitors.slice();
        arr.splice(to, 0, arr.splice(from, 1)[0]);
        settings.monitorOrder = arr;
        saveSettings();
    }

    function toggleMonitor(name: string) {
        selectedMonitors = selectedMonitors.includes(name)
            ? selectedMonitors.filter(m => m !== name)
            : selectedMonitors.concat([name]);
    }

    function applyLayout(code: string) {
        if (applyToAll) {
            LayoutService.setLayoutGlobally(code);
        } else if (selectedMonitors.length > 0) {
            selectedMonitors.forEach(m => LayoutService.setLayout(m, code));
        } else {
            LayoutService.setLayout(panelMonitor, code);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    Loader {
        id: panelLoader

        anchors.centerIn: parent
        active: root.serviceReady

        onLoaded: {
            item.forceActiveFocus();
            const idx = root.layouts.findIndex(l => l.code === root.activeLayout);
            if (idx >= 0) {
                root.keyboardFocusedIndex = idx;
                root.lastFocusMethod = "keyboard";
            }
        }

        sourceComponent: Rectangle {
            id: panelContent

            width: Config.sp(Config.panelWidth)
            height: Math.max(
                panelLayout.implicitHeight + Config.sp(Config.panelMargin) * 2,
                Config.sp(Config.panelMargin) * 2
            )
            color: Config.cSurface
            radius: Config.sp(Config.panelRadius)
            border.width: 1
            border.color: Config.cOutline
            focus: true

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true; }
            }

            Keys.onPressed: function(event) {
                const k = event.key;
                if (k === Qt.Key_H || k === Qt.Key_Left) {
                    root.navigateKeyboard("left");
                } else if (k === Qt.Key_L || k === Qt.Key_Right) {
                    root.navigateKeyboard("right");
                } else if (k === Qt.Key_J || k === Qt.Key_Down) {
                    root.navigateKeyboard("down");
                } else if (k === Qt.Key_K || k === Qt.Key_Up) {
                    root.navigateKeyboard("up");
                } else if ((k === Qt.Key_Return || k === Qt.Key_Space) && root.keyboardFocusedIndex >= 0) {
                    root.applyFocusedLayout();
                } else {
                    Qt.quit();
                }
                event.accepted = true;
            }

            ColumnLayout {
                id: panelLayout

                anchors {
                    fill: parent
                    margins: Config.sp(Config.panelMargin)
                }
                spacing: Config.sp(Config.spacingL)

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight + Config.sp(Config.headerPadding)
                    color: Config.cSurfaceVariant
                    radius: Config.sp(Config.headerRadius)

                    RowLayout {
                        id: headerRow

                        anchors.centerIn: parent
                        width: parent.width - Config.sp(Config.headerPadding)
                        spacing: Config.sp(Config.spacingM)

                        Text {
                            text: root.icon("layout-grid")
                            font.family: iconFont.name
                            font.pixelSize: Config.fs(Config.fsBase)
                            color: Config.cPrimary
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Switch Layout"
                            font.pixelSize: Config.fs(Config.fsBase)
                            font.weight: Font.Bold
                            color: Config.cFgSurface
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.sp(Config.spacingM)

                    Text {
                        Layout.fillWidth: true
                        text: "Apply to all monitors"
                        font.pixelSize: Config.fs(Config.fsBase)
                        font.weight: Font.Medium
                        color: Config.cFgVariant
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        id: toggler

                        implicitWidth: Config.sp(Config.toggleWidth)
                        implicitHeight: Config.sp(Config.toggleHeight)
                        radius: Config.sp(Config.toggleHeight) / 2
                        color: root.applyToAll ? Config.cPrimary : Config.cSurface
                        border.width: 1
                        border.color: Config.cOutline

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Rectangle {
                            readonly property real margin: Config.sp(2)

                            width: Config.sp(Config.toggleKnob)
                            height: Config.sp(Config.toggleKnob)
                            radius: width / 2
                            color: root.applyToAll ? Config.cFgPrimary : Config.cPrimary
                            border.width: Config.sp(2)
                            border.color: Config.cSurface
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.applyToAll ? parent.width - width - margin : margin

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyToAll = !root.applyToAll;
                                if (!root.applyToAll && root.selectedMonitors.length === 0) {
                                    root.selectedMonitors = [root.panelMonitor];
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.sp(Config.spacingS)
                    opacity: root.applyToAll ? 0.6 : 1.0
                    enabled: !root.applyToAll

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Config.sp(Config.spacingS)

                        Text {
                            Layout.fillWidth: true
                            text: "Select monitors"
                            font.pixelSize: Config.fs(Config.fsBase)
                            font.weight: Font.Medium
                            color: Config.cFgVariant
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: root.icon("grip-vertical")
                            font.family: iconFont.name
                            font.pixelSize: Config.fs(Config.fsBase)
                            color: Config.cFgVariant
                            opacity: 0.5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item {
                        id: dragArea

                        property int draggedIndex: -1
                        property int dropTargetIndex: -1
                        property bool dragging: false
                        property bool pendingDrag: false
                        property point startPos: Qt.point(0, 0)
                        readonly property real threshold: Config.sp(8)

                        Layout.fillWidth: true
                        implicitHeight: chipFlow.implicitHeight

                        function chipRect(i: int): rect {
                            const c = chipRepeater.itemAt(i);
                            if (!c) return Qt.rect(0, 0, 0, 0);
                            const p = c.mapToItem(chipFlow, 0, 0);
                            return Qt.rect(p.x, p.y, c.width, c.height);
                        }

                        function computeDropIndex(mx: real, my: real): int {
                            const count = root.orderedMonitors.length;
                            let best = draggedIndex;
                            let bestDist = Infinity;
                            for (let i = 0; i < count; i++) {
                                if (i === draggedIndex) continue;
                                const r = chipRect(i);
                                if (!r.width) continue;
                                const dist = Math.hypot(mx - (r.x + r.width / 2), my - (r.y + r.height / 2));
                                if (dist < bestDist) {
                                    bestDist = dist;
                                    best = mx < r.x + r.width / 2 ? i : i + 1;
                                }
                            }
                            if (best > draggedIndex) best--;
                            return Math.max(0, Math.min(count - 1, best));
                        }

                        function reset() {
                            draggedIndex = dropTargetIndex = -1;
                            dragging = pendingDrag = false;
                            dropGhost.visible = false;
                        }

                        Rectangle {
                            id: dropIndicator

                            width: Config.sp(2)
                            height: Config.sp(Config.chipHeight)
                            radius: Config.sp(1)
                            color: Config.cPrimary
                            visible: dragArea.dragging && dragArea.dropTargetIndex !== -1
                            z: 10

                            SequentialAnimation on opacity {
                                running: dropIndicator.visible
                                loops: Animation.Infinite

                                NumberAnimation { to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 0.5; duration: 350; easing.type: Easing.InOutQuad }
                            }

                            Behavior on x {
                                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                            }

                            Behavior on y {
                                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            id: dropGhost

                            width: ghostLabel.implicitWidth + Config.sp(Config.chipPadding)
                            height: Config.sp(Config.chipHeight)
                            radius: Config.sp(Config.chipRadius)
                            color: Config.cPrimary
                            opacity: 0.85
                            visible: false
                            z: 20

                            Text {
                                id: ghostLabel

                                anchors.centerIn: parent
                                font.pixelSize: Config.fs(Config.fsSmall)
                                font.weight: Font.Medium
                                color: Config.cFgPrimary
                            }
                        }

                        Flow {
                            id: chipFlow

                            width: parent.width
                            spacing: Config.sp(Config.spacingS)

                            Repeater {
                                id: chipRepeater

                                model: root.orderedMonitors

                                delegate: Rectangle {
                                    id: chip

                                    required property int index
                                    required property string modelData

                                    readonly property bool selected: root.applyToAll || root.selectedMonitors.includes(modelData)
                                    readonly property bool beingDragged: dragArea.draggedIndex === index && dragArea.dragging

                                    width: beingDragged
                                        ? chipInner.implicitWidth + Config.sp(Config.chipPadding) - Config.sp(4)
                                        : chipInner.implicitWidth + Config.sp(Config.chipPadding)
                                    height: Config.sp(Config.chipHeight)
                                    radius: Config.sp(Config.chipRadius)
                                    color: selected ? Config.cPrimary : Config.cSurfaceVariant
                                    border.width: 1
                                    border.color: selected ? Config.cPrimary : Config.cOutline
                                    opacity: beingDragged ? 0.35 : 1.0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }

                                    Behavior on width {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    RowLayout {
                                        id: chipInner

                                        anchors.centerIn: parent
                                        spacing: Config.sp(Config.spacingS)

                                        Text {
                                            text: root.icon("grip-vertical")
                                            font.family: iconFont.name
                                            font.pixelSize: Config.fs(Config.fsChip)
                                            color: chip.selected ? Qt.alpha(Config.cFgPrimary, 0.6) : Config.cFgVariant
                                            opacity: 0.7
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            visible: chip.selected
                                            text: root.icon("check")
                                            font.family: iconFont.name
                                            font.pixelSize: Config.fs(Config.fsChip)
                                            color: Config.cFgPrimary
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            text: modelData
                                            font.pixelSize: Config.fs(Config.fsChip)
                                            font.weight: Font.Medium
                                            color: chip.selected ? Config.cFgPrimary : Config.cFgSurface
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: chipFlow
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            hoverEnabled: dragArea.pendingDrag || dragArea.dragging
                            cursorShape: dragArea.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                            onPressed: function(mouse) {
                                dragArea.startPos = Qt.point(mouse.x, mouse.y);
                                dragArea.dragging = false;
                                dragArea.pendingDrag = false;
                                for (let i = 0; i < root.orderedMonitors.length; i++) {
                                    const c = chipRepeater.itemAt(i);
                                    if (!c) continue;
                                    const p = c.mapToItem(chipFlow, 0, 0);
                                    if (mouse.x >= p.x && mouse.x <= p.x + c.width
                                            && mouse.y >= p.y && mouse.y <= p.y + c.height) {
                                        dragArea.draggedIndex = i;
                                        dragArea.pendingDrag = true;
                                        mouse.accepted = true;
                                        return;
                                    }
                                }
                                mouse.accepted = false;
                            }

                            onPositionChanged: function(mouse) {
                                if (!dragArea.pendingDrag) return;
                                const dx = mouse.x - dragArea.startPos.x;
                                const dy = mouse.y - dragArea.startPos.y;
                                if (!dragArea.dragging && Math.hypot(dx, dy) > dragArea.threshold) {
                                    dragArea.dragging = true;
                                    const item = chipRepeater.itemAt(dragArea.draggedIndex);
                                    ghostLabel.text = item ? item.modelData : "";
                                    dropGhost.visible = true;
                                }
                                if (!dragArea.dragging) return;
                                dropGhost.x = mouse.x - dropGhost.width / 2;
                                dropGhost.y = mouse.y - dropGhost.height / 2 - Config.sp(4);
                                const newDrop = dragArea.computeDropIndex(mouse.x, mouse.y);
                                dragArea.dropTargetIndex = newDrop;
                                const count = root.orderedMonitors.length;
                                if (newDrop >= 0) {
                                    const ref = chipRepeater.itemAt(Math.min(newDrop, count - 1));
                                    if (ref) {
                                        const rp = ref.mapToItem(chipFlow, 0, 0);
                                        dropIndicator.x = newDrop < count
                                            ? rp.x - dropIndicator.width - Config.sp(2)
                                            : rp.x + ref.width + Config.sp(2);
                                        dropIndicator.y = rp.y + (ref.height - dropIndicator.height) / 2;
                                    }
                                }
                            }

                            onReleased: {
                                if (dragArea.dragging) {
                                    const to = dragArea.dropTargetIndex;
                                    if (to !== -1 && to !== dragArea.draggedIndex) {
                                        root.applyMonitorReorder(dragArea.draggedIndex, to);
                                    }
                                } else if (dragArea.pendingDrag) {
                                    const released = chipRepeater.itemAt(dragArea.draggedIndex);
                                    if (released) root.toggleMonitor(released.modelData);
                                }
                                dragArea.reset();
                            }

                            onCanceled: dragArea.reset()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "transparent"

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.1; color: Config.cOutline }
                        GradientStop { position: 0.9; color: Config.cOutline }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Config.sp(Config.spacingS)
                    columns: root.gridColumns
                    columnSpacing: Config.sp(Config.spacingS)
                    rowSpacing: Config.sp(Config.spacingS)

                    Repeater {
                        model: root.layouts

                        delegate: Rectangle {
                            id: layoutBtn

                            required property var modelData
                            required property int index

                            readonly property bool active: {
                                if (root.selectedMonitors.length === 0) return modelData.code === root.activeLayout;
                                if (root.selectedMonitors.length === 1) return modelData.code === (LayoutService.monitorLayouts[root.selectedMonitors[0]] || "");
                                return false;
                            }
                            property bool hovered: false
                            readonly property bool isFocused: root.lastFocusMethod === "keyboard"
                                ? index === root.keyboardFocusedIndex
                                : hovered

                            Layout.fillWidth: true
                            Layout.preferredHeight: Config.sp(Config.layoutBtnHeight)
                            height: Config.sp(Config.layoutBtnHeight)
                            radius: Config.sp(Config.layoutBtnRadius)
                            color: active ? Config.cPrimary : Config.cSurfaceVariant
                            border.width: isFocused && !active ? 2 : 1
                            border.color: active ? Config.cPrimary : isFocused ? Config.cPrimary : Config.cOutline

                            Behavior on border.color {
                                ColorAnimation { duration: 120 }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Config.sp(3)

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.icon(root.iconMap[modelData.code] || "")
                                    font.family: iconFont.name
                                    font.pixelSize: Config.fs(Config.layoutIconSize)
                                    color: layoutBtn.active ? Config.cFgPrimary : Config.cFgSurface
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.name
                                    font.pixelSize: Config.fs(Config.layoutLabelSize)
                                    font.weight: Font.Medium
                                    color: layoutBtn.active ? Config.cFgPrimary : Config.cFgSurface
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    layoutBtn.hovered = true;
                                    root.hoveredIndex = index;
                                    root.lastFocusMethod = "hover";
                                }
                                onExited: {
                                    layoutBtn.hovered = false;
                                    if (root.hoveredIndex === index) root.hoveredIndex = -1;
                                }
                                onClicked: root.applyLayout(modelData.code)
                            }
                        }
                    }
                }
            }
        }
    }
}
