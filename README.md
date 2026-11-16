<h1 align="center">Forever Achievements</h1>

<p align="center">
  Character and account achievements for <b>World of Warcraft: Forever</b>.
</p>

<p align="center">
  <!-- Placeholder URL: confirm the slug once the CurseForge project is public. -->
  <a href="https://www.curseforge.com/wow/addons/forever-achievements"><b>Get it on CurseForge</b></a> ·
  <a href="https://github.com/Fragudev/addon-forever-achievements/releases"><b>Download from Releases</b></a> ·
  <a href="docs/USER_GUIDE.md"><b>User guide</b></a>
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licence: proprietary" src="https://img.shields.io/badge/licence-proprietary-e6ba66?style=flat-square&labelColor=1c1a17"></a>
  <img alt="World of Warcraft: Forever, client 1.60.1" src="https://img.shields.io/badge/WoW-Forever_1.60.1-94c9ff?style=flat-square&labelColor=1c1a17">
  <img alt="Status: beta" src="https://img.shields.io/badge/status-beta-fabf4d?style=flat-square&labelColor=1c1a17">
  <a href="https://www.curseforge.com/wow/addons/forever-achievements"><img alt="CurseForge: Forever Achievements" src="https://img.shields.io/badge/CurseForge-Forever_Achievements-f16436?style=flat-square&logo=curseforge&logoColor=white&labelColor=1c1a17"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#features">Features</a> ·
  <a href="#slash-commands">Slash commands</a> ·
  <a href="#documentation">Documentation</a> ·
  <a href="#building-from-source">Building from source</a> ·
  <a href="#contributing">Contributing</a> ·
  <a href="#releasing">Releasing</a> ·
  <a href="#credits-and-licence">Credits and licence</a>
</p>

## Quick start

1. **Install it with the CurseForge app** (search for Forever Achievements), then skip to step 3.
   **Or download** `ForeverAchievements-<version>.zip` from the newest release on the
   [Releases page](https://github.com/Fragudev/addon-forever-achievements/releases), under *Assets* (not "Source code").
2. **Unzip it into the game's AddOns folder**:
   ```text
   World of Warcraft/<forever client folder>/Interface/AddOns/
   ```
   The zip already contains the `ForeverAchievements` folder, so do not create it yourself.
3. **Restart the game** and make sure **Forever Achievements** is enabled in the AddOns list. Log in: the chat says
   `Forever Achievements <version> loaded`.
4. **Click the minimap button, or type `/fach`**, to open the window.

Good to know:

- **Updating:** delete the old `ForeverAchievements` folder, then unzip the new release the same way (the CurseForge
  app does this for you). Your data is kept in `ForeverAchievementsDB`.
- **Language:** the interface follows the client: Spanish on `esES` and `esMX`, English otherwise.
- **Data:** everything stays on your computer; the addon sends no messages and makes no network calls. See
  [Privacy and data](docs/PRIVACY.md).
- **Something wrong?** Check the [user guide](docs/USER_GUIDE.md#what-the-addon-cannot-detect), then open an
  [issue](https://github.com/Fragudev/addon-forever-achievements/issues) with what you did, what you expected and the
  output of `/fach debug selftest`.

> [!NOTE]
> **Beta.** Everything below is implemented and covered by automated tests, but **nothing has been verified on the
> game client yet**. See [docs/API_NOTES.md](docs/API_NOTES.md) for what is still assumed.

## Features

- **422 achievements** in nine categories: General (40), Quests (19), Exploration (44), Player vs. Player (40),
  Dungeons and raids (100), Professions (52), Reputation (97), Feats of Strength (14) and Account (16).
- **Retroactive grants:** at login the addon grants, silently, what your character already meets (level, money, time
  played, quests, exploration, reputation, professions, collections, honorable kills, items). Boss kills,
  battlegrounds, deaths, emotes and looted money are counted from the moment you install it.
- **Window** with Summary, Achievements and Statistics, a category tree, search, filters and the criteria of each
  achievement.
- **Character and account views:** the account view sums all your characters and shows who earned each achievement.
- **Statistics** per character: deaths, quests, bosses, honorable kills, battlegrounds, money looted and more.
- **Toasts, chat lines and a sound** when you earn an achievement, each with its own switch.
- **Tracker:** Shift-click an achievement to pin it; up to 10 are shown with their progress.
- **Minimap button** to open the window.
- **Private by design:** local only, no addon messages, no network.
- **No combat log:** the Midnight restrictions block it, so the addon never uses it.

The full walkthrough is the [user guide](docs/USER_GUIDE.md).

## Slash commands

| Command | What it does |
|---|---|
| `/fach` | Opens or closes the window. |
| `/fach help` | Prints the version and the list of commands. |
| `/fach track <id>` | Pins or unpins an achievement in the tracker. |
| `/fach forget <name>` | Removes a known character (not the current one) and its achievements. |

<details>
<summary><b>Diagnostics for developers</b></summary>

| Command | What it does |
|---|---|
| `/fach debug` | Lists the diagnostic commands. |
| `/fach debug probe` | Checks every client API the addon may use and prints one `key=value` line each. |
| `/fach debug probe events` | Prints the events captured since login: event, count, last arguments. |
| `/fach debug selftest` | Lists the client APIs the addon relies on, each as OK or missing. |

</details>

## Documentation

| Document | For |
|---|---|
| [User guide](docs/USER_GUIDE.md) | players |
| [Privacy and data](docs/PRIVACY.md) | what is stored, and what is not sent |
| [Client API notes](docs/API_NOTES.md) | what the Forever client does and does not expose |

## Building from source

Lua 5.1 with [luacheck](https://github.com/lunarmodules/luacheck), [busted](https://lunarmodules.github.io/busted/),
[luacov](https://lunarmodules.github.io/luacov/) and [StyLua](https://github.com/JohnnyMorganz/StyLua).

```bash
luacheck ForeverAchievements tests
busted --coverage && luacov && tools/check_coverage.sh 80
stylua --check ForeverAchievements tests
tools/package.sh dev
```

Every pull request runs lint, the tests with a minimum of 80% line coverage, a StyLua format check and a package
build that verifies every file referenced by the TOC and the icon is in the zip. Pull request titles must follow
[Conventional Commits](https://www.conventionalcommits.org/). Dependabot keeps the workflow actions up to date.

## Contributing

Bug reports and ideas are welcome from everyone as issues; pull requests are open to maintainers only. See
[CONTRIBUTING.md](CONTRIBUTING.md) for what to include in a report and how maintainers work.

## Releasing

Betas ship from `develop` and releases from `main`; only the owner can push version tags. Write the notes in
`release-notes/<tag>.md`, then push the tag. The **Release** workflow checks that the tag is on the right branch, runs
the full CI and, only if both pass, stamps the version into the TOC, zips `ForeverAchievements/`, publishes a GitHub
release and uploads the zip to CurseForge.

```bash
# Beta: tag develop
git switch develop && git pull && git tag v1.2.0-beta.1 && git push origin v1.2.0-beta.1
# Release: merge develop into main through a pull request, then tag main
git switch main && git pull && git tag v1.2.0 && git push origin v1.2.0
```

Tags containing a hyphen are published as betas (a GitHub pre-release and a CurseForge beta), the rest as releases.
After a release, merge `main` back into `develop`. Only `ForeverAchievements/` is shipped. If the CurseForge upload
fails, run the **Release** workflow by hand with the existing tag to publish it again.

## Credits and licence

Proprietary, see [LICENSE](LICENSE). Interface font: Fira Sans, under the SIL Open Font License
(`ForeverAchievements/Media/Fonts/OFL.txt`). World of Warcraft is a trademark of Blizzard Entertainment, Inc.; this
project is not affiliated with or endorsed by Blizzard Entertainment.
