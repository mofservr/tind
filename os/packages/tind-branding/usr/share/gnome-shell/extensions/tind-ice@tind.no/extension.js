// Tind Ice v6: the light "midday" rules in stylesheet.css are all prefixed with .tind-light; this puts
// that class on the shell's top actor whenever the colour scheme is not "prefer-dark", so
// Settings > Appearance switches the whole shell between night and midday. It also puts
// .tind-accent-<slot> (GNOME's accent-color) on the same actor so the shell follows the accent picker.
// A style class updates live; loading and unloading stylesheets at runtime does not (Dash to Dock makes
// GNOME Shell replace the theme object).
//
// Default accent: Tind teal ("green" slot) in the dark theme, alpenglow ("pink" slot) in the light theme.
// When the theme changes and the accent is still the other theme's default, it is swapped; any other
// accent the user picked is left alone.
//
// 2026-10-27: hotkey work (docs: tind-hotkeys). (1) The top bar shows the workspaces as numbers instead of dots;
// the active one is bold in the accent colour, empty ones are dimmed. (2) Super+Ctrl+1..0 activate the dock's
// icons (Dash to Dock's own hotkeys stay off, so we register the keys ourselves and call the dock's own
// activate from an idle callback, where the held Ctrl is no longer in the current event, so it focuses instead of
// opening a new window). (3) Small permanent numbers left of each dock icon, and the running dots under the icon.
// All of (2) and (3) reach into Dash to Dock's private code, so everything is in try/catch and logs "tind-ice:".
//
// 2026-10-19: the GTK accent file is now written for GTK 3 as well (~/.config/gtk-3.0), and the shell
// stylesheet overrides the tile preview, text selection in shell entries, switches etc. (ACCENTS part 2).
//
// 2026-10-21: Firefox and Thunderbird ignore the GTK 3 colours above. On GNOME (theme "Adwaita") they use
// the accent the settings portal reports, which is GNOME's stock colour for the slot (stock green for our
// teal), for selections, focus rings, checkboxes and buttons. Their ui.* colour prefs override that, so the
// accent is also written as a managed block in user.js of every Firefox and Thunderbird profile. Mozilla
// apps read user.js at start, so a running Firefox keeps its colour until it is restarted.
//
// 2026-10-21 (later): links in Firefox's address-bar suggestions (URL line, "Switch to Tab") still used GNOME's
// stock blue. They take the system link colour, so the managed block also sets ui.-moz-hyperlinktext (and the
// active and visited ones) and the GTK 3 file sets link_color. The accent itself is used on the dark theme; on the
// light theme it is darkened and on the dark theme lightened so text stays readable.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const LIGHT = 'tind-light';
const DARK_DEFAULT = 'green';
const LIGHT_DEFAULT = 'pink';
// GTK 4 / libadwaita apps (Settings included) take their accent from libadwaita's own fixed colour table,
// not from the --accent-<slot> variables, so the ring around the Light/Dark preview, switches, checkboxes
// and so on stayed in GNOME's old colours. User CSS can override @accent_bg_color, but only with one fixed
// value, so this file is rewritten whenever the accent changes: ~/.config/gtk-4.0/tind-accent.css, pulled
// in by an @import line at the top of ~/.config/gtk-4.0/gtk.css. Apps started after a change pick it up;
// an app that is already open keeps the colour it started with.
const ACCENT_HEX = {
    blue: '#19685F', teal: '#21857A', green: '#138677', yellow: '#68C4B7', orange: '#A2DBD2',
    red: '#FED2CB', pink: '#EC5179', purple: '#E27E75', slate: '#C25D59',
};
const ACCENT_FG_WHITE = ['blue', 'teal', 'green'];
const GTK_IMPORT = '@import url("tind-accent.css");';
const MOZ_PROFILE_ROOTS = ['.mozilla/firefox', '.thunderbird', '.config/mozilla/firefox', '.config/thunderbird'];
const MOZ_BEGIN = '// BEGIN tind-accent (managed by the Tind shell theme; rewritten at login and when the accent changes)';
const MOZ_END = '// END tind-accent';
const D2D_UUID = 'dash-to-dock@micxgx.gmail.com';
const SLOTS = ['blue', 'teal', 'green', 'yellow', 'orange', 'red', 'pink', 'purple', 'slate'];

export default class TindIce extends Extension {
    enable() {
        this._settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
        this._sigScheme = this._settings.connect('changed::color-scheme', () => { this._swapDefault(); this._sync(); });
        this._sigAccent = this._settings.connect('changed::accent-color', () => this._sync());
        this._sync();
        this._enableWorkspaceNumbers();
        this._enableDockHotkeys();
        this._enableDockNumbers();
    }

    _dark() {
        return this._settings.get_string('color-scheme') === 'prefer-dark';
    }

    _swapDefault() {
        const accent = this._settings.get_string('accent-color');
        if (this._dark() && accent === LIGHT_DEFAULT)
            this._settings.set_string('accent-color', DARK_DEFAULT);
        else if (!this._dark() && accent === DARK_DEFAULT)
            this._settings.set_string('accent-color', LIGHT_DEFAULT);
    }

    _sync() {
        if (this._dark())
            Main.uiGroup.remove_style_class_name(LIGHT);
        else
            Main.uiGroup.add_style_class_name(LIGHT);
        const accent = this._settings.get_string('accent-color');
        for (const s of SLOTS)
            Main.uiGroup.remove_style_class_name(`tind-accent-${s}`);
        const slot = SLOTS.includes(accent) ? accent : DARK_DEFAULT;
        Main.uiGroup.add_style_class_name(`tind-accent-${slot}`);
        this._writeGtkAccent(slot);
        this._accentText = this._dark() ? this._lighten(ACCENT_HEX[slot], 0.35) : this._darken(ACCENT_HEX[slot], 0.25);
        global._tindAccentText = this._accentText;
        this._updateWorkspaceNumbers();
    }

    // ---- numbered workspaces in the top bar ---------------------------------------------------------
    _enableWorkspaceNumbers() {
        try {
            const wm = global.workspace_manager;
            this._wsBox = new St.BoxLayout({ style_class: 'tind-ws', y_align: Clutter.ActorAlign.CENTER });
            this._wsLabels = [];
            this._wsWindowSigs = new Map();
            const activities = Main.panel.statusArea.activities;
            // GNOME's own dot indicator is the Activities button's only child (a WorkspaceIndicators, itself a
            // BoxLayout): hide it and put our box next to it, in the button, so it keeps the button's padding and hover.
            this._wsHidden = [];
            for (const child of activities.get_children()) {
                this._wsHidden.push([child, child.visible]);
                child.hide();
            }
            activities.add_child(this._wsBox);
            this._wsSigs = [
                [wm, wm.connect('notify::n-workspaces', () => this._rebuildWorkspaceNumbers())],
                [wm, wm.connect('active-workspace-changed', () => this._updateWorkspaceNumbers())],
                [wm, wm.connect('workspace-added', () => this._rebuildWorkspaceNumbers())],
                [wm, wm.connect('workspace-removed', () => this._rebuildWorkspaceNumbers())],
            ];
            this._rebuildWorkspaceNumbers();
        } catch (e) {
            console.warn(`tind-ice: workspace numbers not available: ${e.message}`);
        }
    }

    _rebuildWorkspaceNumbers() {
        try {
            if (!this._wsBox)
                return;
            const wm = global.workspace_manager;
            for (const [ws, id] of this._wsWindowSigs)
                for (const sid of id) ws.disconnect(sid);
            this._wsWindowSigs.clear();
            this._wsBox.destroy_all_children();
            this._wsLabels = [];
            for (let i = 0; i < wm.n_workspaces; i++) {
                const label = new St.Label({ text: `${i + 1}`, style_class: 'tind-ws-num', y_align: Clutter.ActorAlign.CENTER });
                this._wsBox.add_child(label);
                this._wsLabels.push(label);
                const ws = wm.get_workspace_by_index(i);
                this._wsWindowSigs.set(ws, [
                    ws.connect('window-added', () => this._updateWorkspaceNumbers()),
                    ws.connect('window-removed', () => this._updateWorkspaceNumbers()),
                ]);
            }
            this._updateWorkspaceNumbers();
        } catch (e) {
            console.warn(`tind-ice: workspace numbers: ${e.message}`);
        }
    }

    _updateWorkspaceNumbers() {
        try {
            if (!this._wsLabels)
                return;
            const wm = global.workspace_manager;
            const active = wm.get_active_workspace_index();
            this._wsLabels.forEach((label, i) => {
                const ws = wm.get_workspace_by_index(i);
                const empty = !ws || ws.list_windows().filter(w => !w.is_on_all_workspaces()).length === 0;
                label.remove_style_class_name('tind-ws-active');
                label.remove_style_class_name('tind-ws-empty');
                if (i === active) {
                    label.add_style_class_name('tind-ws-active');
                    label.set_style(this._accentText ? `color: ${this._accentText};` : null);
                } else {
                    label.set_style(null);
                    if (empty)
                        label.add_style_class_name('tind-ws-empty');
                }
            });
        } catch (e) {
            console.warn(`tind-ice: workspace numbers: ${e.message}`);
        }
    }

    _disableWorkspaceNumbers() {
        try {
            for (const [obj, id] of this._wsSigs ?? [])
                obj.disconnect(id);
            for (const [ws, ids] of this._wsWindowSigs ?? [])
                for (const sid of ids) ws.disconnect(sid);
            this._wsBox?.destroy();
            for (const [child, vis] of this._wsHidden ?? [])
                if (vis) child.show();
        } catch (e) {
            console.warn(`tind-ice: workspace numbers cleanup: ${e.message}`);
        }
        this._wsSigs = this._wsWindowSigs = this._wsBox = this._wsLabels = this._wsHidden = null;
    }

    // ---- Dash to Dock: Super+Ctrl+# and permanent numbers ----------------------------------------------
    async _dockManager() {
        const ext = Main.extensionManager.lookup(D2D_UUID);
        if (!ext || !ext.dir)
            return null;
        const mod = await import(ext.dir.get_child('extension.js').get_uri());
        return mod.dockManager ?? null;
    }

    _enableDockHotkeys() {
        this._hotkeyNames = [];
        this._dockHotkeysAsync();
    }

    async _dockHotkeysAsync() {
        try {
            const ext = Main.extensionManager.lookup(D2D_UUID);
            if (!ext || !ext.dir)
                return;
            // Debian's package installs the schema system-wide (no schemas/ folder inside the extension)
            const d2dSettings = new Gio.Settings({ schema_id: 'org.gnome.shell.extensions.dash-to-dock' });
            this._d2dSettings = d2dSettings;
            if (d2dSettings.get_boolean('hot-keys')) {
                console.warn('tind-ice: dash-to-dock hot-keys are on; Tind leaves the number keys to it');
                return;
            }
            for (let n = 1; n <= 10; n++) {
                const name = `app-hotkey-${n}`;
                Main.wm.addKeybinding(name, d2dSettings, Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
                    Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW, () => this._activateDockApp(n - 1));
                this._hotkeyNames.push(name);
            }
        } catch (e) {
            console.warn(`tind-ice: dock hotkeys not available: ${e.message}`);
        }
    }

    _activateDockApp(index) {
        // idle: the key press is no longer the current event, so a held Ctrl does not mean "new window"
        GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._dockManager().then(mgr => {
                if (!mgr)
                    return;
                let dock = mgr.mainDock;
                if (mgr._allDocks?.length > 1) {
                    const [x, y] = global.get_pointer();
                    const idx = global.display.get_monitor_index_for_rect(new Meta.Rectangle({ x, y, width: 1, height: 1 }));
                    dock = mgr.getDockByMonitor(idx) ?? dock;
                }
                const fn = dock.activateApp ?? dock._activateApp;
                fn.call(dock, index);
            }).catch(e => console.warn(`tind-ice: dock hotkey: ${e.message}`));
            return GLib.SOURCE_REMOVE;
        });
    }

    _enableDockNumbers() {
        this._dockNumbersAsync();
    }

    async _dockNumbersAsync() {
        try {
            const mgr = await this._dockManager();
            if (!mgr || !this._settings)
                return;
            this._dockMgr = mgr;
            this._styleDocks = () => {
                try {
                    for (const dock of mgr._allDocks ?? [mgr.mainDock]) {
                        const dash = dock?.dash;
                        if (!dash)
                            continue;
                        if (!dash._tindWrapped) {
                            const orig = dash._updateNumberOverlay.bind(dash);
                            dash._tindOrigUpdate = dash._updateNumberOverlay;
                            dash._updateNumberOverlay = () => { orig(); this._styleDashNumbers(dash); };
                            dash._tindWrapped = true;
                        }
                        dash._updateNumberOverlay();
                    }
                } catch (e) {
                    console.warn(`tind-ice: dock numbers: ${e.message}`);
                }
            };
            this._dockReadySig = mgr.connect?.('docks-ready', () => this._styleDocks());
            this._styleDocks();
        } catch (e) {
            console.warn(`tind-ice: dock numbers not available: ${e.message}`);
        }
    }

    _styleDashNumbers(dash) {
        for (const icon of dash.getAppIcons()) {
            try {
                if (icon._numberOverlayOrder > -1) {
                    icon._numberOverlayLabel.set_style('font-size: 9px; font-weight: normal; width: 12px; height: 12px; ' +
                        'border-radius: 0; background-color: transparent; color: #F2F2F2; text-align: center;');
                    icon._numberOverlayLabel.add_style_class_name('tind-dock-num');
                    icon._numberOverlayBin.set({ x_align: Clutter.ActorAlign.START, y_align: Clutter.ActorAlign.CENTER });
                    icon._numberOverlayBin.show();
                } else {
                    icon._numberOverlayBin.hide();
                }
                // the running dots: Dash to Dock draws them for a bottom dock and rotates them 90 degrees for a left dock
                for (const ind of icon._indicator?._indicators ?? []) {
                    const area = ind._area;
                    if (!area)
                        continue;
                    if (area._tindRot === undefined)
                        area._tindRot = area.rotation_angle_z;
                    area.rotation_angle_z = 0;
                    icon._tindAreas = icon._tindAreas ?? new Set();
                    icon._tindAreas.add(area);
                }
            } catch (e) {
                console.warn(`tind-ice: dock icon style: ${e.message}`);
            }
        }
    }

    _disableDock() {
        try {
            for (const name of this._hotkeyNames ?? [])
                Main.wm.removeKeybinding(name);
            if (this._dockReadySig && this._dockMgr)
                this._dockMgr.disconnect(this._dockReadySig);
            for (const dock of this._dockMgr?._allDocks ?? []) {
                const dash = dock?.dash;
                if (dash?._tindWrapped) {
                    dash._updateNumberOverlay = dash._tindOrigUpdate;
                    dash._tindWrapped = false;
                    for (const icon of dash.getAppIcons()) {
                        icon._numberOverlayBin?.hide();
                        icon._numberOverlayLabel?.remove_style_class_name('tind-dock-num');
                        for (const area of icon._tindAreas ?? [])
                            if (area._tindRot !== undefined)
                                area.rotation_angle_z = area._tindRot;
                    }
                }
            }
        } catch (e) {
            console.warn(`tind-ice: dock cleanup: ${e.message}`);
        }
        this._hotkeyNames = []; this._dockMgr = null; this._dockReadySig = null; this._styleDocks = null;
        this._d2dSettings = null;
    }

    _writeGtkAccent(slot) {
        const fg = ACCENT_FG_WHITE.includes(slot) ? '#FFFFFF' : '#14110F';
        const hex = ACCENT_HEX[slot];
        const link = this._dark() ? this._lighten(hex, 0.35) : this._darken(hex, 0.25);
        // GTK 4 / libadwaita: accent_* colours. GTK 3 (Firefox, Thunderbird, Terminal, LibreOffice, ...):
        // Adwaita for GTK 3 paints selections, focus rings and switches from theme_selected_*.
        this._writeGtkDir('gtk-4.0',
            `@define-color accent_bg_color ${hex};\n@define-color accent_fg_color ${fg};\n`);
        this._writeGtkDir('gtk-3.0',
            `@define-color accent_bg_color ${hex};\n@define-color accent_fg_color ${fg};\n` +
            `@define-color accent_color ${hex};\n` +
            `@define-color link_color ${link};\n@define-color visited_link_color ${link};\n` +
            `@define-color theme_selected_bg_color ${hex};\n@define-color theme_selected_fg_color ${fg};\n` +
            `@define-color selected_bg_color ${hex};\n@define-color selected_fg_color ${fg};\n`);
        this._writeMozillaPrefs(hex, fg, link);
    }

    _lighten(hex, amount) {
        const n = parseInt(hex.slice(1), 16);
        const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => Math.round(v + (255 - v) * amount));
        return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
    }

    _darken(hex, amount) {
        const n = parseInt(hex.slice(1), 16);
        const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => Math.round(v * (1 - amount)));
        return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
    }

    // Firefox / Thunderbird: colour prefs in user.js (see the 2026-10-21 note at the top).
    _writeMozillaPrefs(hex, fg, link) {
        const pairs = [
            ['ui.accentcolor', hex], ['ui.accentcolortext', fg],
            ['ui.highlight', hex], ['ui.highlighttext', fg],
            ['ui.selecteditem', hex], ['ui.selecteditemtext', fg],
            ['ui.-moz_menuhover', hex], ['ui.-moz_menuhovertext', fg],
            ['ui.-moz-hyperlinktext', link], ['ui.-moz-activehyperlinktext', link], ['ui.-moz-visitedhyperlinktext', link],
        ];
        const block = `${MOZ_BEGIN}\n${pairs.map(([k, v]) => `user_pref("${k}", "${v}");`).join('\n')}\n${MOZ_END}\n`;
        const home = GLib.get_home_dir();
        for (const root of MOZ_PROFILE_ROOTS) {
            try {
                const rootDir = Gio.File.new_for_path(GLib.build_filenamev([home, root]));
                if (!rootDir.query_exists(null))
                    continue;
                const en = rootDir.enumerate_children('standard::name,standard::type',
                    Gio.FileQueryInfoFlags.NONE, null);
                let info;
                while ((info = en.next_file(null)) !== null) {
                    if (info.get_file_type() !== Gio.FileType.DIRECTORY)
                        continue;
                    const profile = GLib.build_filenamev([home, root, info.get_name()]);
                    if (GLib.file_test(GLib.build_filenamev([profile, 'prefs.js']), GLib.FileTest.EXISTS))
                        this._writePrefsBlock(profile, block);
                }
                en.close(null);
            } catch (e) {
                console.warn(`tind-ice: could not update Mozilla profiles under ${root}: ${e.message}`);
            }
        }
    }

    _writePrefsBlock(profile, block) {
        try {
            const file = Gio.File.new_for_path(GLib.build_filenamev([profile, 'user.js']));
            let current = '';
            try {
                current = new TextDecoder().decode(file.load_contents(null)[1]);
            } catch (e) { /* no user.js yet */ }
            const rest = current.replace(/(^|\n)\/\/ BEGIN tind-accent[\s\S]*?\/\/ END tind-accent\n?/, '$1');
            const next = `${rest}${rest === '' || rest.endsWith('\n') ? '' : '\n'}${block}`;
            if (next !== current)
                file.replace_contents(new TextEncoder().encode(next), null, false,
                    Gio.FileCreateFlags.REPLACE_DESTINATION, null);
        } catch (e) {
            console.warn(`tind-ice: could not write user.js in ${profile}: ${e.message}`);
        }
    }

    _writeGtkDir(name, body) {
        try {
            const dir = GLib.build_filenamev([GLib.get_user_config_dir(), name]);
            GLib.mkdir_with_parents(dir, 0o755);
            const css = `/* Written by the Tind shell theme whenever the accent colour changes. */\n${body}`;
            const accentFile = Gio.File.new_for_path(GLib.build_filenamev([dir, 'tind-accent.css']));
            let current = '';
            try {
                current = new TextDecoder().decode(accentFile.load_contents(null)[1]);
            } catch (e) { /* not there yet */ }
            if (current !== css)
                accentFile.replace_contents(new TextEncoder().encode(css), null, false,
                    Gio.FileCreateFlags.REPLACE_DESTINATION, null);

            // gtk.css must start with the @import line; keep whatever else the user has in it
            const gtkFile = Gio.File.new_for_path(GLib.build_filenamev([dir, 'gtk.css']));
            let gtk = null;
            try {
                gtk = new TextDecoder().decode(gtkFile.load_contents(null)[1]);
            } catch (e) { /* not there yet */ }
            if (gtk === null || !gtk.includes(GTK_IMPORT))
                gtkFile.replace_contents(new TextEncoder().encode(`${GTK_IMPORT}\n${gtk ?? ''}`), null, false,
                    Gio.FileCreateFlags.REPLACE_DESTINATION, null);
        } catch (e) {
            console.warn(`tind-ice: could not write the ${name} accent file: ${e.message}`);
        }
    }

    disable() {
        this._disableWorkspaceNumbers();
        this._disableDock();
        delete global._tindAccentText;
        if (this._sigScheme) this._settings.disconnect(this._sigScheme);
        if (this._sigAccent) this._settings.disconnect(this._sigAccent);
        Main.uiGroup.remove_style_class_name(LIGHT);
        for (const s of SLOTS)
            Main.uiGroup.remove_style_class_name(`tind-accent-${s}`);
        this._sigScheme = this._sigAccent = null;
        this._settings = null;
    }
}
