# BattleMender Changelog

## 14.1.24 — 12.1 Custom Aura Layout

* Updated for World of Warcraft Retail 12.1.
* Improved friendly-player identity handling for the client’s restricted data,
  including safer class colours, specialization resolution, and click targets.
* Restored combat aura displays through Blizzard’s native AuraContainer system.
* Added independent Buff, Debuff, and Custom aura layouts and target-only
  display controls.
* Reworked Custom Aura settings into a compact display row with clear Buffs and
  Debuffs sections, each organized by General, Player, and Others filters.
* Removed obsolete spell-ID and redundant aura-filter controls that are not
  compatible with the 12.1 combat aura API.
* Improved city specialization resolution and fallback behaviour for nearby
  friendly players.
