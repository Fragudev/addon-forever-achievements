# Privacy and data

What Forever Achievements stores, and what it does not do.

## The short version

- **Everything stays on your computer**, in the game's `SavedVariables` file (`ForeverAchievementsDB`). It is a
  normal file on your disk, not a secret store.
- The addon **sends no addon messages** and **makes no network calls**. It has no server, no website and no
  telemetry. Nothing about you leaves your client unless you copy a file or some output yourself.
- Other players, including your guild, cannot see your achievements through this addon.

This is verifiable in the source: it never calls `SendAddonMessage`, `C_ChatInfo.SendAddonMessage`,
`SendChatMessage` or any HTTP function. The only `C_ChatInfo` calls are reads (`InChatMessagingLockdown`) and a
secure hook on `PerformEmote` to count your own emotes.

## What is stored

| Data | Where it comes from |
|---|---|
| For each character you log in with: its GUID, name, class, race, faction, level and when it was last seen | read from the game |
| For each character: a snapshot used for the account totals (money, time played, skill levels, reputation standings) | read from the game |
| For each character: the progress on every achievement, the achievements earned (when, and whether it was earned before the addon) and the statistics counters | computed by the addon |
| Account achievements earned (when, and which character) | computed by the addon |
| Your settings: toasts, chat, sound, the tracked achievements, the minimap button position and whether it is hidden, the position of the tracker and of the window | you |
| Diagnostics, bounded (see below) | the `/fach debug` commands and the boss detector |

The achievements, categories and names are shipped inside the addon; they are not downloaded.

### Diagnostic logs

The debug logs are local, bounded and stored in the same file, under `ForeverAchievementsDB.debug`:

- `probeEvents`: the events captured by `/fach debug probe events`, at most **64** entries.
- `lastProbe`: the lines of the last `/fach debug probe`, at most **200** lines.
- `encounters`: the last **20** boss kills the addon saw (encounter id, difficulty id, and the instance type).

They hold client API results (which can include your own character's name and GUID) and event names. They do not hold chat, other players' names or your inventory.

## Where the file is

```text
World of Warcraft/<forever client folder>/WTF/Account/<account>/SavedVariables/ForeverAchievements.lua
```

The game writes it on `/reload` and on logout. It contains your **character names and GUIDs**, so think before
attaching it to a public issue; the output of `/fach debug selftest` is usually enough.

## Taking data back

- **A character:** `/fach forget <name>` deletes it and everything stored for it (see the
  [user guide](USER_GUIDE.md#forgetting-a-character)).
- **Everything:** disable or remove the addon and delete `ForeverAchievements.lua` (and `ForeverAchievements.lua.bak`)
  from the `SavedVariables` folder while the game is closed.

## Retention

There is no automatic expiry: data stays until you forget a character or delete the file. The only things that are
trimmed are the bounded diagnostic logs above.
