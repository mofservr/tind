// Tind Ice v2: stylesheet.css (night) is loaded by GNOME Shell automatically. This adds
// stylesheet-light.css on top whenever the colour scheme is not "prefer-dark", so the
// Settings > Appearance light/dark toggle switches the whole shell between night and midday.
// The St theme object is fetched fresh each time: GNOME Shell replaces it whenever another
// extension (Dash to Dock) loads its stylesheet, and a cached copy would silently do nothing.
import Gio from 'gi://Gio';
import St from 'gi://St';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

export default class TindIce extends Extension {
    enable() {
        this._settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
        this._light = Gio.File.new_for_path(`${this.path}/stylesheet-light.css`);
        this._loaded = false;
        this._sig = this._settings.connect('changed::color-scheme', () => this._sync());
        this._sync();
    }

    _theme() {
        return St.ThemeContext.get_for_stage(global.stage).get_theme();
    }

    _sync() {
        const light = this._settings.get_string('color-scheme') !== 'prefer-dark';
        const theme = this._theme();
        if (light && !this._loaded) {
            theme.load_stylesheet(this._light);
            this._loaded = true;
        } else if (!light && this._loaded) {
            theme.unload_stylesheet(this._light);
            this._loaded = false;
        }
    }

    disable() {
        if (this._sig) this._settings.disconnect(this._sig);
        if (this._loaded) this._theme().unload_stylesheet(this._light);
        this._sig = null;
        this._settings = null;
        this._light = null;
        this._loaded = false;
    }
}
