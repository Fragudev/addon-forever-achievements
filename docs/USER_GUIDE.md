# Forever Achievements: user guide

Character and account achievements for **World of Warcraft: Forever**: 422 achievements, a window to browse them,
toasts when you earn one, a tracker, statistics, and an account view that sums up all your characters.

> **Beta, not verified in game.** The addon is covered by automated tests, but nothing has been tested on a live
> Forever client yet; the launch is on 2026-11-05. Every client API it reads is *assumed*, not measured (see
> [API_NOTES.md](API_NOTES.md)). Expect some achievements not to be detected until the first real measurements.
> The open checks are tracked as issues labelled `verify-in-game`.

## Contents

- [Getting started](#getting-started)
- [The window](#the-window)
- [Summary](#summary)
- [Achievements](#achievements)
- [Statistics](#statistics)
- [Character and account views](#character-and-account-views)
- [Earned before the addon](#earned-before-the-addon)
- [Toasts, chat and sound](#toasts-chat-and-sound)
- [The tracker](#the-tracker)
- [The minimap button](#the-minimap-button)
- [Slash commands](#slash-commands)
- [Forgetting a character](#forgetting-a-character)
- [What the addon cannot detect](#what-the-addon-cannot-detect)
- [Reporting a problem](#reporting-a-problem)

## Getting started

1. Install it as described in the [README](../README.md#quick-start): with the CurseForge app, or by unzipping the
   release into `World of Warcraft/<forever client folder>/Interface/AddOns/`.
2. **Updating:** delete the old `ForeverAchievements` folder, then unzip the new release the same way (the CurseForge
   app does this for you). Your data is kept: it lives in the `ForeverAchievementsDB` saved variable, not in the
   addon folder.
3. Log in. The chat says `Forever Achievements <version> loaded`. If the addon finds achievements you had already
   earned in the game, it adds one line saying how many it granted (see
   [Earned before the addon](#earned-before-the-addon)).
4. **Click the minimap button, or type `/fach`**, to open the window.

**Language:** the interface is in English, and in Spanish on the `esES` and `esMX` clients. There is no language
switch in the window: it follows the client. Any other client language shows English. The slash commands and the
`/fach help` text are always English.

## The window

The window has a header (logo, version, a gear and the close button), a sidebar with the three pages
(*Summary*, *Achievements*, *Statistics*), a **Character / Account** switch and a card at the bottom that says whose
progress you are looking at, and the page itself.

- Drag the header to move it and the corner to resize it. The size and position are remembered.
- **Escape** closes it.
- `/fach` and the minimap button open and close it.

## Summary

The overview of the current view:

- **Total progress** and your **achievement points**.
- **Latest achievements**: the most recent ones you earned. Shift-click one to track it.
- **Progress by category**: how many achievements you have in each category.

## Achievements

The browser for the whole catalog. The list on the left is the category tree with the count of earned achievements;
the rows on the right are the achievements of the selected category.

| Category | Achievements |
|---|---|
| General (level, wealth, time played, collections, emotes, miscellaneous) | 40 |
| Quests | 19 |
| Exploration | 44 |
| Player vs. Player (honor, battlegrounds) | 40 |
| Dungeons and raids (5-player: 34, raids: 66) | 100 |
| Professions (primary: 40, secondary: 12) | 52 |
| Reputation (factions, capitals, world, PvP) | 97 |
| Feats of Strength | 14 |
| Account | 16 |
| **Total** | **422** |

- **Search:** type a name and press Enter to search across the whole catalog.
- **Filters:** *All*, *Completed* or *Incomplete*.
- **Criteria:** click a row to open its criteria and see your progress on each one (for example `3 / 5 completed`,
  or a gold amount against the target).
- **Tracking:** **Shift-click** an achievement to pin it in the [tracker](#the-tracker); Shift-click it again to
  unpin it.
- A broad search shows the first 150 results and tells you to narrow it down.
- Achievements that belong to one faction are shown only to that faction.
- **Feats of Strength** give no points.

## Statistics

Counters for the current character, grouped as *General* (total deaths, quests completed, highest level, emotes
used), *Combat* (bosses, dungeon bosses and raid bosses defeated), *Player vs. Player* (honorable kills,
battlegrounds played and won, in total and for Warsong Gulch, Arathi Basin and Alterac Valley), *Wealth* (money
looted) and *Collections* (most epic items equipped, mounts collected). A counter shows as empty until the addon
has started counting it.

Statistics are per character. The Account view does not sum them.

## Character and account views

The **Character / Account** switch changes what every page shows:

- **Character:** the achievements of the character you are playing, with their progress and points.
- **Account:** every character the addon knows on this account. An achievement counts as earned if *any* of your
  characters earned it, and the points are the sum over your characters. The 16 **Account** achievements (for
  example, characters at a given level, different classes, gold across the account or total achievement points)
  only appear in this view, and are computed from all your characters together.

In the Account view, an earned achievement says who got it first: **`Earned by <character> on <date>`**, or
**`Earned by <character> before the addon`** for a retroactive grant. Progress you have not finished shows the
progress of your best character.

The addon only knows a character after you have logged in with it once with the addon enabled.

## Earned before the addon

At login the addon reads what the game says about your character and grants, **silently**, the achievements you
already meet. A retroactive grant never shows a toast; the addon prints one summary line instead (for example
`Granted 3 achievements earned before the addon`). They are marked **"Earned before the addon"** in the list, and
they count for points and for the Account view like any other.

**What can be granted retroactively** (from the current state of the character): level, money held, time played,
completed quests, exploration, reputation, profession skill, collected mounts and companions, honorable kills,
items you own now and the quality of your equipped gear. The Feats of Strength and Account achievements follow
from those.

**What cannot:** anything that needs an *event* the game does not keep a history of. The addon counts these only
**from the moment it is installed**:

- boss kills (dungeons and raids), including full clears;
- battlegrounds played and won;
- deaths;
- emotes aimed at a creature;
- money looted (as opposed to money held).

So a boss you killed last week is not credited; the next kill is. The same goes for the statistics.

## Toasts, chat and sound

Click the **gear** in the header to open the settings popover:

| Setting | Default | What it does |
|---|---|---|
| Show a toast when I earn an achievement | on | A small toast with the icon, name and points. Several at once are queued. |
| Play a sound with the toast | on | Plays a standard client sound; if the client has none of the ones tried, it stays silent. |
| Print earned achievements in chat | on | `Achievement earned: <name> (<points> points)` in the chat. |
| Show the minimap button | on | Shows or hides the minimap button. |

Settings are saved for the whole account. Retroactive grants never produce a toast or a chat line per achievement.

## The tracker

A small movable panel with the achievements you pinned (at most 10), each with its progress. Pin one with
**Shift-click** in the list, or with [`/fach track <id>`](#slash-commands). Drag the panel to move it; its position
is remembered. An achievement leaves the tracker by itself when you earn it.

## The minimap button

The addon logo in a gold ring on the edge of the minimap.

- **Left click** opens or closes the window.
- **Drag** it to move it around the minimap.
- **Hover** shows the title and these two hints.
- Hide or show it from the settings popover.

## Slash commands

These are the commands `/fach help` prints, in the same words.

| Command | What it does |
|---|---|
| `/fach` | Opens or closes the window. |
| `/fach help` | Prints the version and the list of commands. |
| `/fach track <id>` | Pins or unpins an achievement in the tracker. The id is the catalog id, for example `level_10`. |
| `/fach forget <name>` | Removes a known character (not the current one) and its achievements. |
| `/fach debug` | Lists the diagnostic commands. |
| `/fach debug probe` | Checks every client API the addon may use and prints one `key=value` line each. |
| `/fach debug probe events` | Prints the events captured since login: event, count, last arguments. |
| `/fach debug selftest` | Lists the client APIs the addon relies on, each as OK or missing. |

An unknown command prints the help again. The `debug` commands are for diagnostics and for the launch
measurements; you only need them when asked, or to attach their output to an issue.

`/fach track` tells you when the id is unknown, when the achievement is already earned and when the tracker is full.

## Forgetting a character

`/fach forget <name>` deletes a character the addon knows, and **everything stored for it**: its progress, its
earned achievements and its statistics. Use it for a character you deleted or no longer want counted. The account
totals are recomputed from the characters that remain.

- It matches the character's display name (not case sensitive) or its exact GUID.
- It refuses the character you are playing; log in with another one to forget it.
- If two characters share a name, it lists their GUIDs and asks you to repeat the command with one of them.
- There is no undo.

## What the addon cannot detect

Under the Midnight addon restrictions the combat log is not available to addons (the client blocks registering
`COMBAT_LOG_EVENT_UNFILTERED`), and some values are hidden ("secret") during boss encounters. The addon never
touches the combat log and never guesses a hidden value. That has consequences:

- **No combat-based achievements:** anything that needs damage, healing, kill credit of a specific creature or a
  combat log line cannot be detected. Boss kills are taken from `ENCOUNTER_END`, not from the log.
- **During an encounter,** facts that would be read while the client is locked down are parked in a queue and
  evaluated when the encounter ends.
- **Past events are not available:** see [Earned before the addon](#earned-before-the-addon).
- **Your class quests at level 60, the Hydraxian Waterlords and Ahn'Qiraj war effort quests, the Paladin Charger
  quest, Alterac Mountains exploration and full clears of Blackfathom Deeps, Dire Maul and Upper Blackrock Spire**
  are not in the catalog yet (missing data, tracked in issue
  [#3](https://github.com/Fragudev/addon-forever-achievements/issues/3)).
- **Unverified ids:** a few encounter, zone, item and creature ids come from public sources and are not confirmed
  on the Forever client. An achievement that depends on one may not complete until it is fixed.
- The addon does not know whether Forever ships its own achievement system. The first launch measurements will
  answer that.

## Reporting a problem

Open an [issue](https://github.com/Fragudev/addon-forever-achievements/issues) with what you did, what you
expected and what happened. Please attach:

- the output of `/fach debug selftest`;
- if it concerns detection, the output of `/fach debug probe` and `/fach debug probe events`;
- the addon version (printed by `/fach help`).

What the addon stores, and what you may be sharing by attaching a saved file, is in [PRIVACY.md](PRIVACY.md).
