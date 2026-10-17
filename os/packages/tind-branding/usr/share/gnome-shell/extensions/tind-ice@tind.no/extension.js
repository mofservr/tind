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
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const LIGHT = 'tind-light';
const DARK_DEFAULT = 'green';
const LIGHT_DEFAULT = 'pink';
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
        Main.uiGroup.add_style_class_name(`tind-accent-${SLOTS.includes(accent) ? accent : DARK_DEFAULT}`);
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
