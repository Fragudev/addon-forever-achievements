<h1 align="center">Forever Achievements</h1>

<p align="center">
  Character and account achievements for <b>World of Warcraft: Forever</b>.
</p>

<p align="center">
  <!-- Placeholder URL: confirm the slug once the CurseForge project is public. -->
  <a href="https://www.curseforge.com/wow/addons/forever-achievements"><b>Get it on CurseForge</b></a> ·
  <a href="https://github.com/Fragudev/addon-forever-achievements/releases"><b>Download from Releases</b></a>
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licence: proprietary" src="https://img.shields.io/badge/licence-proprietary-e6ba66?style=flat-square&labelColor=1c1a17"></a>
  <img alt="World of Warcraft: Forever, client 1.60.1" src="https://img.shields.io/badge/WoW-Forever_1.60.1-94c9ff?style=flat-square&labelColor=1c1a17">
  <img alt="Status: in development" src="https://img.shields.io/badge/status-in_development-fabf4d?style=flat-square&labelColor=1c1a17">
  <a href="https://www.curseforge.com/wow/addons/forever-achievements"><img alt="CurseForge: Forever Achievements" src="https://img.shields.io/badge/CurseForge-Forever_Achievements-f16436?style=flat-square&logo=curseforge&logoColor=white&labelColor=1c1a17"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#features">Features</a> ·
  <a href="#building-from-source">Building from source</a> ·
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
4. **Type `/fach`** to print the installed version and the list of commands.

### Slash commands

| Command | What it does |
|---|---|
| `/fach` | Prints the version and the list of commands. |
| `/fach debug probe` | Checks every client API the addon may use and prints one `key=value` line each. |
| `/fach debug probe events` | Prints the events captured since login: event, count, last arguments. |
| `/fach debug selftest` | Lists the client APIs the addon relies on, each as OK or missing. |

## Features

In development. The addon currently loads, creates its saved variables (`ForeverAchievementsDB`) and answers `/fach`.
Achievement tracking and its window are not implemented yet.

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

## Credits and licence

Proprietary, see [LICENSE](LICENSE). Interface font: Fira Sans, under the SIL Open Font License
(`ForeverAchievements/Media/Fonts/OFL.txt`). World of Warcraft is a trademark of Blizzard Entertainment, Inc.; this
project is not affiliated with or endorsed by Blizzard Entertainment.
