pragma Singleton

import Quickshell

// Session-scoped query for the keybind cheatsheet — the filter should survive closing and
// reopening the cheatsheet within a session, but reset whenever the quickshell process restarts.
// Originally from https://github.com/asteriau/dotfiles.

Singleton {
    id: root
    property string query: ""
}
