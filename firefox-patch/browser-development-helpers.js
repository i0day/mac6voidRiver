/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Extra features for local development. This file isn't loaded in
 * non-local builds.
 */

var DevelopmentHelpers = {
  init() {
    this.quickRestart = this.quickRestart.bind(this);
    // LOCAL PATCH 2026-10-04: addRestartShortcut() disabled — this Void build
    // (MOZILLA_OFFICIAL=false) prepended Ctrl+Alt+R "Restart (Developer)" and
    // hijacked the reader-mode toggle on the same shortcut.
  },

  quickRestart() {
    Services.obs.notifyObservers(null, "startupcache-invalidate");
    Services.env.set("MOZ_DISABLE_SAFE_MODE_KEY", "1");

    Services.startup.quit(
      Ci.nsIAppStartup.eAttemptQuit | Ci.nsIAppStartup.eRestart
    );
  },

  addRestartShortcut() {
    // PATCHED: no-op — Ctrl+Alt+R belongs to reader mode.
    if (true) return;
    let command = document.createXULElement("command");
    command.setAttribute("id", "cmd_quickRestart");
    command.addEventListener("command", this.quickRestart, true);
    document.getElementById("mainCommandSet").prepend(command);

    let key = document.createXULElement("key");
    key.setAttribute("id", "key_quickRestart");
    key.setAttribute("key", "r");
    key.setAttribute("modifiers", "accel,alt");
    key.setAttribute("command", "cmd_quickRestart");
    document.getElementById("mainKeyset").prepend(key);

    let menuitem = document.createXULElement("menuitem");
    menuitem.setAttribute("id", "menu_FileRestartItem");
    menuitem.setAttribute("key", "key_quickRestart");
    menuitem.setAttribute("label", "Restart (Developer)");
    menuitem.addEventListener("command", this.quickRestart, true);
    document.getElementById("menu_FilePopup").appendChild(menuitem);
  },
};
