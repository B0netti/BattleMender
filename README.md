# BattleMender

BattleMender highlights friendly players with clear visual indicators, including class-colored rings, health overlays, hover effects, and specialization-aware icons. Its goal is to improve battlefield readability as an essential part of a minimalist PvP UI.

## Key Features

- Friendly player nameplates
  - Circular, minimalist design
  - Damaged-health overlay
  - Battleground objective badges for flag and other objective carriers
  - Precise mouse interaction for mouseover casting
- Enemy nameplates
  - A simple, customizable alternative to major nameplate addons
  - Aura filtering
  - Highlight and flash effects inspired by Blizzard's nameplate threat visuals

## New in BattleMender 16.1

- Optional healer-cross health presentation and a separate hard-CC/silence aura badge
- A dedicated Environment section with Arena scale controls and per-environment friendly visibility
- Character-specific **Dispellable by Me** enemy Buff filtering
- Continuous managed enemy Buff and Debuff rows across selected aura categories
- More reliable PvP flare class colors and friendly specialization detection
- Safer deferred defensive layout updates in restricted PvP

See [CHANGELOG.md](CHANGELOG.md) for the complete update history.

## BattleMender 15.0 Feature Overview

BattleMender 15.0 is a major update focused on making the addon easier to configure, improving PvP readability, and expanding BattleMender beyond its original friendly-nameplate role.

### Presets

A new preset system provides quick starting points for different visual styles:

- **BattleMender** — the full signature appearance
- **Simple** — clean, restrained styling with a standard border
- **Bold** — stronger visual emphasis for maximum readability

Presets are intended to get most users close to a finished setup immediately, while all individual appearance settings remain customizable.

### Expanded Enemy Nameplates

Enemy nameplates have received a substantial upgrade and can now serve as a complete BattleMender-managed alternative to ElvUI enemy plates.

Major improvements include:

- Custom enemy health bars
- Cast bars with interruptibility styling
- Buff and debuff displays
- Important aura support
- Class-colored health bars and names
- Optional portraits
- Target and mouseover highlighting
- Improved cast-bar sizing and presentation
- Better support for absorb and health-state information

### PvP Objective Indicators

BattleMender now provides much stronger visual treatment for battleground objectives carried by players.

Objective states such as:

- Flags
- Temple of Kotmogu orbs
- Carts and other supported PvP classifications

can be surfaced directly on the relevant nameplate, making objective carriers much easier to identify during crowded fights.

The objective system has also been reworked to integrate more naturally with the existing BattleMender plate design rather than appearing as a detached indicator.

### Improved Friendly Plate Appearance

The friendly plate renderer has received a broad visual cleanup.

New and improved options include:

- Additional border styles
- Improved automatic border fitting
- Glass and other accent overlays
- Independent specialization-icon and class-icon desaturation
- Better class-color handling
- Improved flare coloring and fallback behavior
- Refined hover glow and halo effects
- Cleaner icon layering

Border changes are now designed to require much less manual resizing when switching between styles.

### Line-of-Sight Styling Overhaul

The line-of-sight appearance system has been simplified and made more predictable.

Highlights include:

- Dedicated line-of-sight border appearance
- Configurable line-of-sight border opacity
- Cleaner icon treatment while a player is out of sight
- Optional desaturation
- Removal of the old line-of-sight pulse behavior
- Better separation between normal, hover, and line-of-sight visual states

The defaults have also been revised to keep an out-of-sight player clearly identifiable without excessive flashing.

### Better Blizzard and ElvUI Compatibility

BattleMender now has more control over how its plates coexist with Blizzard and ElvUI nameplates.

This includes options for independently hiding:

- Blizzard friendly health-bar artwork
- Blizzard friendly player names

This makes it possible to retain whichever native elements you prefer without having duplicate health bars or unwanted artwork behind BattleMender.

Compatibility work has also continued around ElvUI nameplates, PvP classification indicators, frame recycling, and nameplate visibility.

### Improved Configuration

The options window has been reorganized to make the growing feature set easier to navigate.

Changes include:

- Cleaner high-level navigation
- More logical grouping of appearance settings
- Dedicated enemy plate controls
- Improved Test Mode access
- Profiles and Import/Export organization
- BattleMender version displayed directly in the options window
- Updated minimap launcher behavior

### Under-the-Hood Improvements

15.0 also contains substantial internal work aimed at making BattleMender more reliable during PvP:

- Safer handling of recycled nameplates
- Better restoration of Blizzard and ElvUI elements
- Improved specialization and class-color fallbacks
- More robust aura handling
- Reduced visual conflicts between BattleMender and native nameplate elements
- Numerous fixes for hover effects, borders, objectives, cast bars, and plate state transitions

**BattleMender 15.0 is the largest expansion of the addon since 14.0, with the emphasis shifting from simply replacing friendly PvP plates to providing a more complete, cohesive PvP nameplate system.**

## Compatibility

- ElvUI compatible
- Native Blizzard nameplates compatible
