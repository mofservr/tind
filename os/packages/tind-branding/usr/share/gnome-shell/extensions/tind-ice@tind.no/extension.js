// Tind Ice: the styling lives entirely in stylesheet.css, which GNOME Shell loads
// automatically when the extension is enabled. Nothing to do at runtime.
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

export default class TindIce extends Extension {
    enable() {}
    disable() {}
}
