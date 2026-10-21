// Tind Ice v5: the light "midday" rules in stylesheet.css are all prefixed with .tind-light; this puts
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
// 2026-10-19: the GTK accent file is now written for GTK 3 as well (~/.config/gtk-3.0), and the shell
// stylesheet overrides the tile preview, text selection in shell entries, switches etc. (ACCENTS part 2).
//
// 2026-10-21: Firefox and Thunderbird ignore the GTK 3 colours above. On GNOME (theme "Adwaita") they use
// the accent the settings portal reports, which is GNOME's stock colour for the slot (stock green for our
// teal), for selections, focus rings, checkboxes and buttons. Their ui.* colour prefs override that, so the
// accent is also written as a managed block in user.js of every Firefox and Thunderbird profile. Mozilla
// apps read user.js at start, so a running Firefox keeps its colour until it is restarted.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
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
    blue: '#19685F', teal: '#21857A', green: '#3AA79A', yellow: '#68C4B7', orange: '#A2DBD2',
    red: '#FED2CB', pink: '#F4988C', purple: '#E27E75', slate: '#C25D59',
};
const ACCENT_FG_WHITE = ['blue', 'teal'];
const GTK_IMPORT = '@import url("tind-accent.css");';
const MOZ_PROFILE_ROOTS = ['.mozilla/firefox', '.thunderbird', '.config/mozilla/firefox', '.config/thunderbird'];
const MOZ_BEGIN = '// BEGIN tind-accent (managed by the Tind shell theme; rewritten at login and when the accent changes)';
const MOZ_END = '// END tind-accent';
const SLOTS = ['blue', 'teal', 'green', 'yellow', 'orange', 'red', 'pink', 'purple', 'slate'];

export default class TindIce extends Extension {
    enable() {
        this._settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
        this._sigScheme = this._settings.connect('changed::color-scheme', () => { this._swapDefault(); this._sync(); });
        this._sigAccent = this._settings.connect('changed::accent-color', () => this._sync());
        this._sync();
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
    }

    _writeGtkAccent(slot) {
        const fg = ACCENT_FG_WHITE.includes(slot) ? '#FFFFFF' : '#14110F';
        const hex = ACCENT_HEX[slot];
        // GTK 4 / libadwaita: accent_* colours. GTK 3 (Firefox, Thunderbird, Terminal, LibreOffice, ...):
        // Adwaita for GTK 3 paints selections, focus rings and switches from theme_selected_*.
        this._writeGtkDir('gtk-4.0',
            `@define-color accent_bg_color ${hex};\n@define-color accent_fg_color ${fg};\n`);
        this._writeGtkDir('gtk-3.0',
            `@define-color accent_bg_color ${hex};\n@define-color accent_fg_color ${fg};\n` +
            `@define-color accent_color ${hex};\n` +
            `@define-color theme_selected_bg_color ${hex};\n@define-color theme_selected_fg_color ${fg};\n` +
            `@define-color selected_bg_color ${hex};\n@define-color selected_fg_color ${fg};\n`);
        this._writeMozillaPrefs(hex, fg);
    }

    // Firefox / Thunderbird: colour prefs in user.js (see the 2026-10-21 note at the top).
    _writeMozillaPrefs(hex, fg) {
        const pairs = [
            ['ui.accentcolor', hex], ['ui.accentcolortext', fg],
            ['ui.highlight', hex], ['ui.highlighttext', fg],
            ['ui.selecteditem', hex], ['ui.selecteditemtext', fg],
            ['ui.-moz_menuhover', hex], ['ui.-moz_menuhovertext', fg],
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
        if (this._sigScheme) this._settings.disconnect(this._sigScheme);
        if (this._sigAccent) this._settings.disconnect(this._sigAccent);
        Main.uiGroup.remove_style_class_name(LIGHT);
        for (const s of SLOTS)
            Main.uiGroup.remove_style_class_name(`tind-accent-${s}`);
        this._sigScheme = this._sigAccent = null;
        this._settings = null;
    }
}
