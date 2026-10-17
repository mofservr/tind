/* ============================================
   System Monitor — panelMetrics.js
   Shared panel metric definitions
   ============================================

   SPDX-FileCopyrightText: 2026 Naimur Rahman
   SPDX-License-Identifier: GPL-2.0-or-later

   Imported by both extension.js and prefs.js. The shell lays the panel out
   from this order and the prefs dialog edits it, so the id list and the
   repair rules have to be one definition rather than two that drift apart.
*/

/**
 * The panel's metrics in their default left-to-right order.
 *
 * `id` is what the `panel-order` setting stores and what names the metric's
 * icon file (icons/smp-<id>-symbolic.svg); `visibilityKey` is the switch that
 * decides whether it is drawn at all.
 */
export const PANEL_METRICS = [
    {id: 'cpu', title: 'CPU Usage', visibilityKey: 'show-cpu'},
    {id: 'gpu', title: 'GPU Usage', visibilityKey: 'show-gpu'},
    {id: 'memory', title: 'Memory Usage', visibilityKey: 'show-memory'},
    {id: 'disk', title: 'Disk Usage', visibilityKey: 'show-disk'},
    {id: 'temperature', title: 'Temperature', visibilityKey: 'show-temperature'},
    {id: 'network', title: 'Network Speed', visibilityKey: 'show-network'},
];

/**
 * A complete, duplicate-free panel order built from a stored one.
 *
 * The setting is user data, and a hand-edited dconf entry, a settings backup
 * taken from another release or a future release that adds a metric can each
 * leave it short, long or malformed. Unknown ids are dropped and anything
 * missing is appended in default order, so the panel always ends up with
 * every metric exactly once whatever the key contains.
 */
export function sanitizePanelOrder(stored) {
    const order = [];

    for (const id of stored) {
        if (!order.includes(id) && PANEL_METRICS.some(m => m.id === id))
            order.push(id);
    }
    for (const {id} of PANEL_METRICS) {
        if (!order.includes(id))
            order.push(id);
    }

    return order;
}
