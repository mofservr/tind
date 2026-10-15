// Tind Ice v2: one stylesheet.css (GNOME Shell loads it automatically). The light "midday" rules in it
// are all prefixed with .tind-light; this puts that class on the shell's top actor whenever the
// colour scheme is not "prefer-dark", so Settings > Appearance switches the whole shell between
// night and midday. A style class updates live; loading and unloading stylesheets at runtime does
// not (Dash to Dock makes GNOME Shell replace the theme object).
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const LIGHT = 'tind-light';

export default class TindIce extends Extension {
    enable() {
        this._settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
        this._sig = this._settings.connect('changed::color-scheme', () => this._sync());
        this._sync();
    }

    _sync() {
        if (this._settings.get_string('color-scheme') !== 'prefer-dark')
            Main.uiGroup.add_style_class_name(LIGHT);
        else
            Main.uiGroup.remove_style_class_name(LIGHT);
    }

    disable() {
        if (this._sig) this._settings.disconnect(this._sig);
        Main.uiGroup.remove_style_class_name(LIGHT);
        this._sig = null;
        this._settings = null;
    }
}
