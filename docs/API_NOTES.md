# Client API notes

What has been measured on the WoW: Forever client, what the addon assumes, and what is still to be checked.
The API reference used is [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Api) (Mainline branch); only deviations
from it and measured behaviour belong here.

## Measured

Facts carried over from the Nrage Assistant project (`addon-nrage-assistant/docs/API_NOTES.md`). They are measured on
the Forever beta client and must be measured again at launch (2026-11-05).

| Item | Value | Where it matters |
|---|---|---|
| Interface number (`select(4, GetBuildInfo())`) | 16001 (beta) | TOC |
| `COMBAT_LOG_EVENT_UNFILTERED` | registering it raised "blocked from an action only available to the Blizzard UI" | never registered, not even by the probe (`Platform.TryRegisterEvent` refuses it) |
| Secret values | some data is a secret value during encounters: it cannot be compared, stored or measured | every client call goes through `Platform`, which gives nil for a secret |
| `UnitName("player")` | only the **first word** of a multi-word name | a character is identified by its GUID |
| Division by zero | raises an error on this client | percentages of progress are guarded |

## Assumed, not measured yet

- The client uses the Mainline API, so the wrappers in `Core/Platform.lua` follow the Mainline signatures. A call that
  does not exist or raises gives nil to the caller (unavailable, never a guess).
- The native achievement system may exist because the API is Mainline (plan section 2). **This is the key risk:** if
  Forever has an active native system, the scope is reconsidered before phase 3. Probe items 38 to 42 and the `native_achievements=` summary line answer it.
- `Platform.GetCompletedQuestIDs`, `GetProfessions` and `GetAchievementCategories` return an empty table when the API
  is unavailable, so "none" and "unavailable" look the same there; `Platform.Has(path)` tells them apart.

## How to run the probe

Run these in game, once per session, and copy the output back to the project:

1. Log in and wait for the "loaded" message. The event log starts at `PLAYER_LOGIN`.
2. `/fach debug selftest`
3. `/fach debug probe` (it calls `RequestTimePlayed`, so the client also prints the time played in chat).
4. Play for a while: gain XP or kill something, loot money, turn in a quest, open the map, change a reputation,
   enter and leave an instance, die once, learn a mount if you can.
5. `/fach debug probe events`
6. `/reload` or log out: the events and the last probe lines are kept in `ForeverAchievementsDB.debug`
   (`probeEvents` and `lastProbe`, bounded to 64 events and 200 lines) in
   `WTF/Account/<account>/SavedVariables/ForeverAchievements.lua`.

Output format: one `NN key=value` line per API. `missing` is an API that does not exist, `error: <message>` is one
that raised, `<secret>` is a value the client hides. Large tables show their size and the first 5 entries.

## Probe: APIs

| # | Question | API | Result |
|---|---|---|---|
| 1 | Is the player level readable? | `UnitLevel` | not measured yet |
| 2 | Is the player GUID readable (the identity of a character)? | `UnitGUID` | not measured yet |
| 3 | What does UnitName give for a multi-word name? | `UnitName` | not measured yet |
| 4 | Does GetUnitName give the full name? | `GetUnitName` | not measured yet |
| 5 | Class name, token and id? | `UnitClass` | not measured yet |
| 6 | Race name, token and id? | `UnitRace` | not measured yet |
| 7 | Faction token? | `UnitFactionGroup` | not measured yet |
| 8 | Normalized realm name? | `GetNormalizedRealmName` | not measured yet |
| 9 | Is the money (copper) readable? | `GetMoney` | not measured yet |
| 10 | Does it fire TIME_PLAYED_MSG (check the events report)? | `RequestTimePlayed` | not measured yet |
| 11 | Does it list the completed quests (retroactive quest achievements)? | `C_QuestLog.GetAllCompletedQuestIDs` | not measured yet |
| 12 | Does it answer for a completed quest id? | `C_QuestLog.IsQuestFlaggedCompleted` | not measured yet |
| 13 | Which map is the player on? | `C_Map.GetBestMapForUnit` | not measured yet |
| 14 | Are the map name, type and parent readable? | `C_Map.GetMapInfo` | not measured yet |
| 15 | Is the player position on the map readable? | `C_Map.GetPlayerMapPosition` | not measured yet |
| 16 | Does it say which areas are explored at a position (exploration achievements)? | `C_MapExplorationInfo.GetExploredAreaIDsAtPosition` | not measured yet |
| 17 | Does it list the explored map textures of a map? | `C_MapExplorationInfo.GetExploredMapTextures` | not measured yet |
| 18 | Does the modern reputation API answer for a faction id? | `C_Reputation.GetFactionDataByID` | not measured yet |
| 19 | Does the old reputation API answer? | `GetFactionInfoByID` | not measured yet |
| 20 | How many factions are listed? | `C_Reputation.GetNumFactions` | not measured yet |
| 21 | How many factions (old API)? | `GetNumFactions` | not measured yet |
| 22 | Which profession indexes does the player have? | `GetProfessions` | not measured yet |
| 23 | Are the profession name and skill level readable? | `GetProfessionInfo` | not measured yet |
| 24 | Does the mount journal exist on Forever? | `C_MountJournal.GetNumMounts` | not measured yet |
| 25 | Does it list the mount ids? | `C_MountJournal.GetMountIDs` | not measured yet |
| 26 | Does the pet journal exist (total, owned)? | `C_PetJournal.GetNumPets` | not measured yet |
| 27 | Does the toy box exist on Forever? | `C_ToyBox.GetNumLearnedDisplayedToys` | not measured yet |
| 28 | Does it give lifetime honourable kills (issue #99)? | `GetPVPLifetimeStats` | not measured yet |
| 29 | What does it give outside a battleground? | `GetBattlefieldWinner` | not measured yet |
| 30 | Does it count an item (the Hearthstone)? | `GetItemCount` | not measured yet |
| 31 | Is the equipped item link readable? | `GetInventoryItemLink` | not measured yet |
| 32 | Does it give an item quality by id? | `C_Item.GetItemQualityByID` | not measured yet |
| 33 | Is the server time readable? | `GetServerTime` | not measured yet |
| 34 | Which locale does the client report? | `GetLocale` | not measured yet |
| 35 | Does it report the instance type? | `IsInInstance` | not measured yet |
| 36 | Is the chat lockdown state readable? | `C_ChatInfo.InChatMessagingLockdown` | not measured yet |
| 37 | Can DoEmote be hooked (emote achievements)? | `hooksecurefunc` | not measured yet |
| 38 | Does the native achievement namespace exist, and which functions? | `C_AchievementInfo` | not measured yet |
| 39 | Does the native achievement lookup answer (id 6)? | `GetAchievementInfo` | not measured yet |
| 40 | Is the native achievement category list non-empty? | `GetCategoryList` | not measured yet |
| 41 | What does the native completed count say? | `GetNumCompletedAchievements` | not measured yet |
| 42 | What do the native achievement points say? | `GetTotalAchievementPoints` | not measured yet |

## Probe: events

Registration is tried with `pcall`; "fires" is whether it was seen during the session (`/fach debug probe events`).
`ENCOUNTER_START` and `ENCOUNTER_END` log every argument. `hook:DoEmote` is the `hooksecurefunc("DoEmote")` hook.

| Event | Registers | Fires |
|---|---|---|
| `PLAYER_LEVEL_UP` | not measured yet | not measured yet |
| `PLAYER_MONEY` | not measured yet | not measured yet |
| `TIME_PLAYED_MSG` | not measured yet | not measured yet |
| `QUEST_TURNED_IN` | not measured yet | not measured yet |
| `MAP_EXPLORATION_UPDATED` | not measured yet | not measured yet |
| `UPDATE_FACTION` | not measured yet | not measured yet |
| `SKILL_LINES_CHANGED` | not measured yet | not measured yet |
| `ENCOUNTER_START` | not measured yet | not measured yet |
| `ENCOUNTER_END` | not measured yet | not measured yet |
| `PLAYER_PVP_KILLS_CHANGED` | not measured yet | not measured yet |
| `UPDATE_BATTLEFIELD_STATUS` | not measured yet | not measured yet |
| `PLAYER_DEAD` | not measured yet | not measured yet |
| `BAG_UPDATE_DELAYED` | not measured yet | not measured yet |
| `CHAT_MSG_MONEY` | not measured yet | not measured yet |
| `NEW_MOUNT_ADDED` | not measured yet | not measured yet |
| `ACHIEVEMENT_EARNED` | not measured yet | not measured yet |
| `CRITERIA_UPDATE` | not measured yet | not measured yet |
| `PLAYER_LOGOUT` | not measured yet | not measured yet |

## Criteria without a reliable source

Anything the probe shows as missing, secret or empty leaves the catalogue and is listed here (plan section 5.2).

None yet: nothing has been measured.

## Detectors (assumed, not measured)

Phase 3 detectors read the client only through `Core/Platform.lua`. **Nothing here has been measured in game**: every
source below follows the Mainline signature documented on warcraft.wiki.gg and must be checked at the Forever launch
(2026-11-05). Each detector degrades silently: a missing API, an error or a secret value means no fact is published.
`COMBAT_LOG_EVENT_UNFILTERED` is never registered. Noisy events (`UPDATE_FACTION`, `SKILL_LINES_CHANGED`,
`MAP_EXPLORATION_UPDATED`, `NEW_*_ADDED`) are coalesced with `C_Timer.After` (0.5 s); money snapshot writes too.

| Detector | Fact (criterion type) | Source (assumed) | Events | What to check at launch |
|---|---|---|---|---|
| Level | `level` | `UnitLevel` | `PLAYER_LEVEL_UP` (first argument is the new level) | the event argument is the new level |
| Money | `money` | `GetMoney` (copper) | `PLAYER_MONEY` | unit is copper |
| Played | `played` | `RequestTimePlayed`, then the event | `TIME_PLAYED_MSG` (total, level seconds) | the event fires once after the request; the chat print is **not** suppressed (hiding it means touching Blizzard chat frames) |
| Quests | `quest_count`, `quest_id` (key = quest id) | `C_QuestLog.GetAllCompletedQuestIDs` | `QUEST_TURNED_IN` (first argument is the quest id) | the list is complete and returns ids; a turned-in id may or may not already be in the list |
| Exploration | `explore_zone` (key = uiMapID, 0..100), `explore_area` (key = area id) | `C_MapExplorationInfo.GetExploredMapTextures`, `GetExploredAreaIDsAtPosition` | `MAP_EXPLORATION_UPDATED` | see below |
| Reputation | `reputation` (key = faction id, bar value), `reputation_count` (Exalted) | `C_Reputation.GetFactionDataByID` (legacy `GetFactionInfoByID`); list via `C_Reputation.GetNumFactions` + `GetFactionDataByIndex` (legacy `GetFactionInfo`) | `UPDATE_FACTION` | bar value is cumulative; Exalted is standing id 8; the list only has visible rows |
| Skills | `skill` (key = skill line, rank), `skill_count` (professions at max) | `GetProfessions`, `GetProfessionInfo` (7th result is the skill line) | `SKILL_LINES_CHANGED` | the skill line ids; Classic cap `Skills.MAX_RANK = 300` |
| Collections | `mount_count`, `pet_count`, `toy_count` | mounts: `C_MountJournal.GetMountIDs` + 11th result (`isCollected`) of `GetMountInfoByID`; pets: second result of `C_PetJournal.GetNumPets`; toys: `C_ToyBox.GetNumLearnedDisplayedToys` | `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `NEW_TOY_ADDED` | whether the journals exist at all on Forever; the toy count depends on the toy box filters |
| PvP | `honor_kills` | first result of `GetPVPLifetimeStats` | `PLAYER_PVP_KILLS_CHANGED` | nrage issue #99: whether it answers |
| Snapshot | none (stores `{ money, played, skills, reps }` and the character info) | `GetUnitName("player", false)` then `UnitName`; `UnitClass`, `UnitRace`, `UnitFactionGroup`, `UnitLevel` | `PLAYER_LOGOUT` | `GetUnitName("player", false)` gives the full multi-word name |

Exploration (the weakest source):

- Mainline gives the **explored** overlays of a map (`GetExploredMapTextures`) but not how many the map has. Each
  returned record is counted as one overlay, and the percentage needs a reference total that the **catalog** gives in
  the criterion: `{ type = "explore_zone", key = uiMapID, value = 100, total = <overlays of a fully explored map> }`.
  The totals must be measured in game. A zone without `total` publishes nothing.
- `explore_area` is only checked at the player's current position (`C_Map.GetBestMapForUnit` +
  `C_Map.GetPlayerMapPosition` + `GetExploredAreaIDsAtPosition`) on login and on each exploration update. There is no
  retroactive answer for areas the player is not standing in.
- `zone_quests` is not published: it needs a quest-to-zone reference table (phase 6).

Other assumptions:

- `Platform.GetFactionByIndex`, `GetCollectedMountCount`, `ReadCompletedQuestIDs`, `After` (`C_Timer.After`) and
  `NewFrame` are new wrappers with the same contract as the rest of `Platform` (nil or false when missing, raising
  or secret).
- The Exalted count is a lower bound: the faction list hides the rows under collapsed headers and the addon never
  expands them (that would change the player's UI state). Referenced factions are read by id, so they always count.
- `GetPVPLifetimeStats` first result is taken as the lifetime honourable kills; `pvp_rank` has no source and is not
  published.
- The login Played request makes the client print the time played in chat once per session.
