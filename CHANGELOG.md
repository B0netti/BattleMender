## 16.0.0

- Fixed enemy aura flares retaining another player's class colour when nameplates are recycled, such as a Priest showing a Rogue-coloured flare.
- Enemy state is cleared when a nameplate disappears and again before it is assigned to a new unit.
- Class-coloured managed flares now use separate pools for each class, with their colour set during initialization for Retail 12.1 compatibility.
- When an enemy's class cannot be determined safely, flares use the configured custom colour instead of a potentially stale health-bar colour.
- Reorganized the enemy-nameplate system into separate modules, resolving Lua's local-variable limit while preserving existing settings and profiles.

## 15.19.0-enemy-modules

- Refactored the custom enemy-nameplate implementation into core, health/highlight, flare, cast, aura, and lifecycle modules.
- Preserved the 15.18.1 enemy aura-flare recycling/class-color fix without changing settings or saved-variable keys.
- Removed the monolithic EnemyPlates.lua local-variable pressure that had reached Lua's 200-local compilation limit.

## 15.18-enemy-flare-recycle-color

- Fixed enemy aura flare class colors surviving from the previous occupant of a recycled Blizzard nameplate/unit token.
- Enemy nameplate lifecycle state is now invalidated from BattleMender's own plate table on both `NAME_PLATE_UNIT_REMOVED` and the next `NAME_PLATE_UNIT_ADDED`, even when Blizzard has already detached the native plate.
- Class-colored managed aura flares now use a small per-class container pool for the flare trigger category. This keeps creation-time flare tint matched to the current enemy class without trying to repaint forbidden 12.1 AuraButton descendants after recycling.
- If Blizzard withholds a safe class key, the flare falls back to the configured custom flare color rather than displaying another enemy's class color.
- Player flare fallback no longer copies the native/rendered health-bar class tint, because that tint itself can briefly be stale during nameplate recycling.

## 15.17-target-glow-edge-feather

- Feathered the extreme perimeter of `Media\Bars\outer_glow.tga` to transparent over a narrow 6-pixel source band. This removes the visible hard clipping edge on the exterior-only target/low-health glow while preserving the existing glow shape through the rest of the texture.

## 15.16-pve-threat-neutral-target-cutout

- PvE threat changes no longer drive BattleMender enemy-nameplate appearance. Removed the explicit threat-list/selection-state recoloring path and stopped registering `UNIT_THREAT_LIST_UPDATE` / `UNIT_THREAT_SITUATION_UPDATE`; NPC colors now remain based on reaction/classification rather than changing because aggro or threat ownership changes.
- Reworked the enemy current-target / low-health outer glow so the glow is visible only outside the health-bar rectangle. The same `outer_glow.tga` is now sampled as four cropped exterior pieces, preserving the existing halo shape while making an exact dynamic cutout for any configured bar width/height.
- Retains the 15.15 pooled Blizzard UnitFrame alpha hook, which is intended to prevent native Blizzard enemy artwork from resurfacing when Blizzard reapplies alpha during target/threat/classification transitions.

## 15.15-native-objective-flash

- Fixed intermittent Blizzard enemy nameplate artwork resurfacing over BattleMender custom enemy plates. BattleMender now keeps the pooled Blizzard UnitFrame at alpha 0 when Blizzard reapplies nameplate alpha for distance/selection/classification changes, while retaining the narrow root-alpha approach used to avoid tainting Blizzard health/cast/aura internals.
- Explicitly enables Blizzard's `nameplateShowEnemyMinus` CVar while the custom enemy provider is active so weaker/minus enemies still receive the underlying NamePlate frame BattleMender needs.
- Added **Flash Objective Carriers** under Enemy Plates > Text / Indicators > Portrait / PvP. Enemy flag, orb, cart, and bounty carriers now receive a repeating BattleMender-owned health-bar double flash based on Blizzard's native threat Flash cadence, tinted to the objective classification color.
- Kept the current 12.1 managed Aura Flare ownership unchanged. Blizzard's source confirms its Progressive flare uses 2-second alpha fades plus the existing 40-second opposing scroll, but managed AuraButtons do not expose a safe show/hide signal for reproducing a true fade-out outside their secret subtree.

## 15.14-profile-sync-audit

- Audited the full profile schema against the current BattleMender settings, including all Buff, Debuff, Custom, Important, flare, cast, health, portrait, objective, defensive, immunity, LoS, and friendly appearance controls. No current BattleMender-owned CFG setting was missing from the profile defaults/export whitelist.
- Fixed profile copy/switch/reset so cached defensive and immunity AuraContainer presentation is reapplied immediately instead of retaining scale/ring/swipe/position values from the previous profile until a plate rebuild.
- Profile changes now also reapply the custom enemy-provider CVars before refreshing visible plates, matching the normal settings-save path more closely.
- Blizzard CVar controls and the minimap-button position remain global client/addon-launcher state by design; BattleMender visual/gameplay settings remain per-profile.

## 15.13-hover-allocation-test

- Reworked enemy mouseover highlighting so UPDATE_MOUSEOVER_UNIT touches only the previous and current hovered enemy plate instead of scanning and recomputing highlights for every visible enemy.
- Added the same previous/current-only mouseover path for friendly BattleMender plates, avoiding a full active-friendly refresh every time the mouse crosses a nameplate.
- Reused secret-safe pcall helper functions for UnitIsUnit and health-ratio reads instead of allocating new Lua closures in high-frequency nameplate paths.
- Intended to reduce the large temporary BattleMender memory allocation bursts observed while hovering enemy plates in raid packs.

## 15.12-raid-enemy-performance

- Reduced raid CPU spikes from the custom enemy-nameplate provider by removing full enemy-plate refreshes from the 0.15-second friendly LoS/hover poll.
- High-frequency enemy health, aura, threat, and cast events now update only the affected visual component instead of rebuilding layout, name, health, cast, aura containers, flare colors, and portrait together.
- Managed 12.1 AuraContainers are allowed to handle their own live UNIT_AURA updates instead of BattleMender forcing UpdateAllAuras on every aura event.
- Target and mouseover changes now refresh lightweight enemy target/hover state without invoking the full enemy-plate renderer.
- Removed an unrelated BattleMaps FoV mask directory that had been accidentally bundled inside BattleMender, reducing the addon package by roughly 99 MB.

## 15.11-objective-recycle-safety

- Prevented BattleMender friendly objective badges from surviving on a recycled UnitFrame when that frame becomes an enemy nameplate.
- Enemy plate refreshes now explicitly hide any BattleMender-owned friendly overlay attached to the recycled Blizzard UnitFrame, without touching Blizzard protected child regions.
- Includes the 15.10 live-BG defensive forbidden-object guard and objective cleanup changes.

## 14.22-pvp-classification-objectives
- Friendly plates: PvP objective carriers now replace the spec artwork using Blizzard's UnitPvpClassification state and stock flag/cart/orb/bounty atlases instead of objective aura spell IDs.
- Friendly plates: objective replacement now updates safely during combat through the normal plate refresh path.

## 14.21-secret-cast-texture-fix
- Enemy plates: fixed a 12.1 secret-boolean error when selecting interruptible versus uninterruptible cast textures.
- Enemy plates: Class flare color now resolves Blizzard class color directly instead of inheriting a stale/custom health-bar tint.
- Friendly plates: preserved the PvP objective-carrier aura icon override from the 14.17 test build.

## 14.20-cast-spark-sublevel-fix
- Enemy plates: fixed repeated Lua errors caused by an invalid cast-spark texture sublevel. The spark now uses the highest valid OVERLAY sublevel (7).

## 14.19-cast-spark-fix
- Enemy plates: fixed the Blizzard cast spark so it is no longer stretched horizontally and now draws clearly in front of the cast fill.

## 14.18-enemy-absorbs-cast-spark
- Enemy plates: added absorb shield rendering on the custom enemy health bar by mirroring Blizzard absorb geometry when available.
- Enemy plates: added a Blizzard-style moving cast spark at the leading edge of the cast fill.
- Enemy plates: added separate interruptible and uninterruptible cast texture options, including a Blizzard texture option in the shared statusbar selector.

# BattleMender Changelog

## 14.16 — Aura Flare Class Color Consistency

- Fixed Progressive aura flares sometimes using another player's class color in PvP.
- When an enemy player's BattleMender health bar is class-colored, the flare now copies that already-rendered bar color instead of independently resolving the class a second time.
- Players whose bars are not class-colored still use direct class color; NPC flares continue to use their rendered bar color.

## 14.15 — Options Close Button

- Added a standard WoW `X` close button to the top-right of the standalone BattleMender options window.
- The new button uses the existing AceGUI close callback, so Test Mode and defensive previews are cleaned up exactly the same way as the other close paths.

## 14.14 — PvP Class Color Consistency

- Friendly nameplate-to-roster identity caches are now cleared whenever a `nameplateN` token is added or removed, preventing a recycled plate from retaining the previous player's class color.
- Enemy player class colors now prefer Blizzard's secret-safe `C_ClassColor` path instead of mirroring the native health bar's rendered color.
- Added `UnitTreatAsPlayerForDisplay` as the first enemy player-display predicate for restricted PvP nameplate tokens.
- Native enemy health-bar color mirroring remains only as a fallback, reducing incorrect colors caused by recycled nameplate update order.
- Aura Flare class color now uses the same direct class-color source as enemy player health bars.

## 14.13 — Enemy UI / Flare Layout

- Fixed managed Important-aura spacing so the Spacing slider changes the actual gap between AuraContainer icons.
- Added Aura Flare Horizontal Density to independently pack or stretch Blizzard's Progressive flame texture without changing flare height or bar coverage.
- Preserved the options window size and position when switching between Friendly and Enemy Plates from the minimap button.
- Simplified Auras > Flare: removed the explanatory paragraph and moved the short explanation to the Enable Aura Flare tooltip.
- Simplified Health Bar > Texture & Fill, removed the retired alternate health-fill renderer from the UI, and standardized existing profiles on the direct StatusBar renderer.
- Reduced repeated Target / Focus wording while preserving the same controls and behavior.

## 14.12 — Enemy Menu / Aura Flare

- Reorganized Enemy Plates into five clearer tabs: Health Bar, Target / Focus, Cast Bar, Auras, and Text / Indicators.
- Consolidated sizing, textures, normal colors, hover, and low-health settings under Health Bar.
- Restored visible controls for Non-target Scale and Focus Target Scale while grouping Focus texture with Focus presentation.
- Split Cast Bar settings into Layout & Behavior and Cast Colors.
- Moved name, portrait, and battleground indicator options into Text / Indicators.
- Moved the Progressive aura flare out of Important and into its own Auras > Flare category.
- Added Trigger Aura Category selection: Buffs, Debuffs, Custom, or Important.
- Existing Important-flare settings migrate to the new independent flare system with Important retained as the initial trigger.

## 14.11 — Release Defaults Sync

* Synchronized the public new-profile/reset defaults with the maintainer's current Default profile, including friendly visual sizing/effects, enemy plate presentation, aura layouts/filters, and the Important Progressive flare controls.
* Kept Developer Mode and movable Test Mode state out of the public defaults.
* Updated skipped-upgrade migration behavior so newly introduced Important flare controls inherit the current official defaults while genuinely customized legacy glow values are preserved.
* Existing users' established profile choices are not overwritten by the default refresh.

## 14.10 — Important Flare Secret-Aspect Fix

* Fixed the remaining 12.1 taint caused by assigning `OnShow`/`OnHide` scripts to a child of Blizzard-managed `CustomAuraButtonTemplate`; descendants inherit the parent button's secret aspects.
* Removed the visibility-proxy approach completely. Important flare visibility now comes solely from normal parent/child visibility inheritance, with no script hooks or visibility polling on managed aura frames.
* Reverted the flare to direct AuraButton-owned texture regions created only during AuraContainer initialization; this was the previously proven taint-safe ownership model.
* The flare is positioned geometrically above the health bar and retains the Vertical Offset control instead of attempting protected cross-frame re-layering.
* Preserved the Progressive animation and the existing Height, Vertical Offset, Opacity, and Color controls.

## 14.9 — Important Flare AuraButton Taint Fix

* Fixed a 12.1 taint error caused by attaching `OnShow`/`OnHide` hooks directly to Blizzard-managed `CustomAuraButtonTemplate` frames.
* Important-aura flare visibility now follows an addon-owned child visibility proxy created during AuraContainer initialization, so no post-initialization script assignment or visibility polling touches the restricted AuraButton.
* Moved the Progressive flare animation group onto the addon-owned enemy plate root rather than the managed aura button.
* Preserved the 14.8 root-background layering, vertical offset, height, opacity, and color controls.

## 14.8 — Important Flare Layering and Position

* Moved the Important-aura Progressive flare off the aura-button frame and onto the enemy plate root background, so the health and cast bars render above the flames.
* Preserved AuraButton visibility as the secret-safe trigger by mirroring its show/hide state onto the root-level flare rather than reading protected aura presence.
* Added a Vertical Offset control for the Important flare; positive values move the flames upward.
* Defaulted the new vertical offset to +4 px so the visible flame base clears the health-bar border.
* Kept target and low-health glows on separate, higher background sublevels so their colors remain independent from the Important flare.

## 14.7 — Important Flare Controls

* Separated the Important-aura Progressive threat flare from the current-target and low-health outer-glow layers.
* Removed the extra Important-aura backing glow that could make the normal target glow appear recolored.
* Added independent Important flare Height and Opacity controls.
* Added a Threat Flare Color mode with Class and Custom choices. Class uses a player target's class color when Retail exposes it safely; NPCs and restricted player class data fall back to the rendered health-bar color.
* Preserved existing custom flare RGB and alpha when migrating older profiles.

## 14.6 — Progressive Threat Flare Animation Fix

- Fixed Important aura **Threat Flare When Active** rendering the Progressive flare as a static texture.
- The Lua animation constructor now uses `TextureCoord`, the runtime constructor corresponding to Blizzard XML's `<TextureCoordTranslation>` animation type.
- The base and additive flare layers continue to scroll in opposite directions over Blizzard's 40-second repeating cycle.

## 14.5 — Progressive Threat Flare and Combat Spec Detection

- Fixed Important aura **Threat Flare When Active** regions using invalid texture sublevels that could prevent the backing/base layers from being created.
- Matched Blizzard's Progressive aggro treatment by continuously scrolling the base and additive flare layers in opposite directions over a 40-second loop.
- Restored structured `C_TooltipInfo.GetUnit()` specialization detection for visible non-group friendly players during combat, while keeping the legacy hidden tooltip scanner and `NotifyInspect` path out of combat.
- Added stricter secret-value guards around structured tooltip data before specialization text matching.

## 14.4 — Friendly Circle Mask Fix

* Fixed square texture corners appearing behind the circular friendly nameplate presentation.
* The damaged/missing-health spec layer now uses BattleMender's own `Circle_White.tga` alpha mask instead of Blizzard's temporary portrait mask.
* Kept the change isolated to the damaged/missing-health layer so the established masks used by the other friendly visual layers are unchanged.

## 14.3 — Aura Preview and Center Growth

* Enemy Test Mode now respects whether Buff, Debuff, Custom, and Important aura displays are enabled, while still ignoring target-only restrictions for layout testing.
* Added a Center option to Aura Layout > Growth X for centered horizontal aura rows in Test Mode and the managed 12.1 aura path.
* Simplified future addon versions to `MAJOR.REVISION`; historical three-part versions remain unchanged.

## 14.2.2 — Important Aura Threat Flare

* Renamed the user-facing Danger aura container to Important. Existing profile
  values remain compatible under the unchanged internal Danger setting keys.
* Replaced the oversized halo-only health treatment with Blizzard's masked
  `UI-HUD-Nameplates-Aggro-Flare` threat treatment and a restrained backing
  glow, tinted by the existing configurable color and opacity.
* Kept the complete effect on BattleMender-owned aura-button child regions, so
  Blizzard still drives visibility without addon code inspecting secret aura
  presence.

## 14.2.1 — Danger Health Glow

* Added an optional Danger style that glows the enemy health bar whenever at
  least one filtered Danger aura is displayed.
* Added configurable glow color and opacity. Additional active Danger auras
  reinforce the same glow slightly.
* Bound the effect to BattleMender-owned regions on the rendered aura buttons,
  so Test Mode, manual auras, and Blizzard's managed combat path share the same
  presentation without reading protected aura presence.

## 14.2.0 — Danger Aura Container

* Added Danger as a fourth independent enemy aura container with its own
  enable, target-only, Buff/Debuff selection, filters, style, and layout.
* Added Danger to Test Mode, manual rendering, managed in-combat rendering,
  frame setup, refresh, and cleanup paths.
* Simplified all aura tabs to one Filters section. Buff filters no longer
  duplicate Cast by You and Not Cast by You groups; Debuffs use one optional
  Only Cast by You modifier applied to the complete selected filter.
* Migrated existing dedicated Debuff and Custom source-specific choices into
  the consolidated tri-state categories. Danger remains disabled by default.

## 14.1.56 — Consistent Aura Filters

* Buff, Debuff, and Custom aura categories now share the same empty, yellow
  include, and red exclude states.
* Replaced separate Cancelable and Not Cancelable choices with one Cancelable
  category: yellow includes it and red excludes it.
* Clarified source, dispel, raid-frame, target-only, and permanent-aura labels
  and tooltips, while keeping Hide Permanent Auras as a normal checkbox.

## 14.1.55 — Blizzard Friendly-Name Settings

* Removed BattleMender's duplicate Names Only While Disabled and Class-Colored
  Friendly Names controls now that Retail provides those choices directly.
* BattleMender no longer writes the friendly names-only or friendly-name class
  color CVars during login, instance transitions, profile changes, or combat.
* Instanced PvE sleep behavior and default-clickbox restoration are unchanged.

## 14.1.54 — Interrupted Cast Feedback

* Fixed enemy cast bars losing their red Interrupted feedback immediately when
  Retail sends a trailing cast-stop event after the interruption event.
* Interrupted casts now remain visible for the configured Interrupted Display
  Time, while new casts and recycled nameplates still clear the held state.

## 14.1.53 — Release Cleanup

* Removed an internal developer-diagnostics module from the public build while
  preserving the ElvUI friendly-nameplate conflict warning used at login.

## 14.1.52 — Three-State Enemy Buff Filters

* Enemy Buff categories now cycle from empty/off to yellow/include, then to
  red/exclude, allowing native negative-filter combinations.
* Red categories are subtracted from every included category and from the
  broad fallback when no positive category is selected.
* Important can now be combined with excluded Big Defensive and External
  Defensive categories to focus the display on important offensive buffs.

## 14.1.51 — Enemy Buff Source Clarity

* Removed the misleading Player-source controls from the dedicated enemy Buff
  display; PLAYER means buffs cast by you, your pet, or your vehicle rather
  than buffs owned by the enemy player.
* Renamed Others to Not Cast by You and consistently excludes player-cast
  buffs from its filters, the General categories, and the broad fallback.
* Kept explicit Player-source controls available under Custom Auras for rare
  advanced configurations.

## 14.1.50 — Managed Aura Category De-duplication

* Fixed a helpful aura appearing twice when Blizzard classifies it as both a
  Big Defensive and an External Defensive. External Defensive now owns that
  overlap, so effects such as Time Dilation render once.

## 14.1.49 — Friendly Spec Continuity

* Friendly plates now retain their last resolved specialization when a live
  battleground roster update temporarily makes inspect specialization data
  unavailable, instead of reverting to the class-icon fallback.
* Fresh and recycled plates still clear their previous specialization state,
  preventing one player from inheriting another player's icon.

## 14.1.48 — Duel Enemy Plates

* Same-faction and party members now switch from BattleMender's friendly
  circular presentation to the configured enemy-nameplate style while they
  are attackable during a duel.
* Duel start and finish events now reclassify visible plates immediately, and
  the existing cleanup paths restore the friendly presentation afterward.

## 14.1.47 — Secret Cast-Color Pass-Through

* Fixed uninterruptible enemy casts retaining the lower-priority Targeting You
  or interruptible color when Retail exposes `notInterruptible` as a secret
  boolean. BattleMender now passes that opaque state through Blizzard's
  boolean-to-color evaluator without reading or comparing it.
* Removed the temporary cast-event, timing, native-shield, and `/bm castwatch`
  diagnostics used to isolate the failure.

## 14.1.46 — Managed Aura Source Restore

* Restored normal enemy Buff rendering after a source-candidate filter was
  found to over-filter enemy player auras.

## 14.1.45 — Readable Cast Watch

* Added temporary session-only `/bm castwatch` diagnostics. It quietly watches
  every BattleMender enemy cast and reports only a safe, readable native
  `notInterruptible=true` result, if the client exposes one.

## 14.1.44 — Native Cast-Shield Frame Order

* Fixed custom enemy plates recording their native outer-frame reference after
  subscribing to cast events. A currently active cast can be delivered during
  registration, so read-only cast-state diagnostics now see the correct plate.

## 14.1.43 — Native Cast-Shield Path Trace

* Refined the temporary read-only native cast-shield trace to identify the
  exact documented nameplate path that is absent or inaccessible, rather than
  reporting a combined unavailable result.

## 14.1.42 — Native Cast-Shield Trace

* Added a temporary read-only `/bm debug` check of Blizzard's rendered
  nameplate interrupt shield for the current target. It will determine whether
  that visual state is safely available to BattleMender without inspecting or
  modifying the protected cast-bar tree.

## 14.1.41 — Cast-State Timing Trace

* Added a temporary, target-only `/bm debug` trace that samples the raw cast
  interruptibility value at the event, on the next frame, and 0.10 seconds
  later. It records only safe state metadata and no spell or unit identity.

## 14.1.40 — Target Cast-Info Token

* When an enemy plate is the player’s target, BattleMender now reads the cast
  through the equivalent `target` token before falling back to `nameplateN`.
  This uses the normal cast API through the client’s most reliable token.

## 14.1.39 — Target Cast Trace

* Limited the temporary `/bm debug` cast trace to the current target so nearby
  nameplate casts cannot obscure the event sequence under investigation.

## 14.1.38 — Temporary Cast Event Trace

* Added an opt-in `/bm debug` trace for the native enemy cast events while
  diagnosing the Heavyweight Golem interruptibility path. This trace will be
  removed after the event route is verified.

## 14.1.37 — Per-Plate Cast Event State

* Fixed native cast interruptibility events being stored by an event token
  instead of directly on the visible BattleMender cast bar.

## 14.1.36 — Native Cast Events and Interrupted Casts

* Replaced spell-specific and rendered-native cast inference with the supported
  `UNIT_SPELLCAST_INTERRUPTIBLE` and `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` state
  used by established nameplate providers.
* Added a configurable Interrupted Color and Interrupted Display Time for
  briefly showing enemy casts that the player interrupts.

## 14.1.35 — Uninterruptible Cast Priority

* Fixed a late generic interruptible event being able to overwrite a confirmed
  uninterruptible cast state. Grey uninterruptible presentation now retains
  priority over Targeting You.

## 14.1.34 — Event Spell-ID Cast Overrides

* Fixed known uninterruptible casts receiving a restricted spell ID from
  cast-info APIs. BattleMender now classifies confirmed exceptions from the
  ordinary spell ID supplied by the cast-start event.

## 14.1.33 — Restricted Cast Spell IDs

* Fixed known uninterruptible spell overrides being skipped when Retail exposes
  the nameplate cast spell ID as a restricted value.

## 14.1.32 — Cast Diagnostic

* Temporarily added opt-in cast-signal output through `/bm debug` to capture
  live interruptibility data for the heavyweight golem.

## 14.1.31 — Uninterruptible Training and Raid Casts

* Fixed the heavyweight golem's Uber Strike and Vexhul's Caustic Deluge using
  the Targeting You colour despite being mechanically uninterruptible.

## 14.1.30 — Uninterruptible Cast Shield

* Fixed uninterruptible training-dummy and raid casts still receiving the
  Targeting You colour. BattleMender now reads Blizzard's native cast shield
  before applying lower-priority cast colours.

## 14.1.29 — Raid Cast Interruptibility

* Fixed raid casts such as Vexhul's Caustic Deluge not using the configured
  uninterruptible colour when their API state is unavailable to the addon.

## 14.1.28 — Channel Cast-Bar Direction

* Fixed channelled-cast progress appearing on the right side of the enemy cast
  bar. The remaining coloured segment now stays on the left.

## 14.1.27 — Uninterruptible Enemy Casts

* Fixed uninterruptible enemy casts displaying as interruptible. Their
  configured grey colour now takes priority reliably.

## 14.1.26 — 12.1 Managed Aura Source De-duplication

* Fixed enemy self-cast buffs appearing twice in the managed combat aura display.

## 14.1.25 — 12.1 Managed Aura Desaturation

* Fixed Custom Aura icon desaturation while Blizzard's AuraContainer manages
  the combat display.
* Changing the desaturation setting now rebuilds the managed combat group.

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

## 14.23-objectives-badge
- Friendly objective carriers now use a separate **Objectives** badge instead of replacing the centre spec icon.
- Objectives are driven by Blizzard PvP classification, covering flags, orbs, carts, and bounties.
- Added class-colored objective badge borders, objective-colored glow, and a pulsing objective icon.
- Added an **Objectives** options group for badge layout, border, glow, and pulse settings.

## 14.24-flare-class-recycle-fix
- Fixed enemy aura flares retaining the class color of a previously recycled nameplate/AuraContainer button.
- Class flare mode now resolves the current unit directly and refreshes BattleMender-owned flare texture colors when a plate is reassigned.
- If Blizzard temporarily withholds a player class token, Class mode uses neutral white rather than showing a stale class color.

## 14.25-auras-objectives-preview
- Renamed the friendly **Defensives** options page to **Auras**.
- Moved **Objectives** closer to the top of the Auras page.
- Added a **Test Objectives** button directly in the Objectives section.
- Added an Objectives preview using the current badge size, radial position, cogwheel/border settings, class color, objective glow, and pulse settings.

## 15.0
- Reworked the settings window around vertical navigation to reduce nested horizontal tabs.
- Moved Developer Mode into Friendly Plates and Blizzard nameplate CVars into General.
- Simplified Compatibility to provider detection/handoff; removed the old disabled-ElvUI repair and ElvUI clickthrough controls.
- Added BattleMender-owned Clickthrough controls for friendly and custom enemy plates.
- Consolidated friendly testing into one Preview page for health, LoS, class/spec art, Objectives, major defensives, and immunities.
- Kept per-feature Test buttons in Auras as shortcuts into the shared Friendly Preview.
- Moved Objectives to the top of Auras and removed the duplicate Aura Preview block.
- Combined profile management and Import / Export under one Profiles branch.

## 15.1-range-test-prototype
- Added a safe live range-test prototype for friendly group nameplates.
- `/bm rangetest` toggles fixed diagnostic labels (`R:IN`, `R:OUT`, `R:?`, `R:SECRET`).
- `/bm rangestatus` prints a snapshot including whether UnitInRange returns are secret.
- Added the same controls under Friendly Plates > Preview > Live Range Test.
- The prototype does not yet alter Normal/LoS rendering.

## 15.2-enemy-bar-art-fix
- Matched the enemy cast spark to Blizzard's modern nameplate 4x12 pip and prevented atlas-native sizing from enlarging it.
- Enemy absorbs now default to the current health-bar texture, including normal/target/focus texture changes.
- Removed the misleading BattleMender Blizzard statusbar option; the old generic UI-StatusBar was not the modern native nameplate cast texture.
- Preserved the 15.1 range-test prototype.

## 15.3-border-fit-cleanup
- Normalized friendly circular border fitting so swapping ring/cogwheel textures keeps the spec-icon opening approximately consistent.
- Replaced the old manual Border Size correction with **Border Fine Tune**; `1.00` is now the calibrated automatic fit.
- Normal and LoS borders now use one shared border-definition table, and the Friendly Preview uses the same renderer values.
- Existing profiles migrate their old Border Size value to preserve the currently selected border's apparent size as closely as possible.
- Shield-shaped borders retain their legacy sizing for now pending art-specific treatment.
- Removed the Range Test prototype after live 12.1 testing confirmed both `UnitInRange` returns are secret on friendly nameplate units.

## 15.4-border-visual-bias
- Added per-border visual bias on top of geometric opening normalization.
- Live-tested defaults: Thin 1.05, Standard 1.05, Heavy 1.05, Extra Heavy 1.00, Metal 1.00, Plastic 1.05, Cogwheel 1.00.
- Border Fine Tune now represents only a small user preference adjustment and defaults to 1.00.
- Existing profiles migrate their fine-tune value to preserve the currently selected border's apparent size.
- Shield variants remain available with legacy/special-case sizing pending separate art calibration.

## 15.5-quick-setup-presets
- Added a General > Quick Setup section for users who want a useful configuration with one or two choices.
- Added Appearance presets: BattleMender, Simple, and Bold. BattleMender remains the default Plastic Ring + Glass presentation.
- Added Playstyle presets for Healer / Hybrid and DPS / Information, configuring friendly click targets, friendly/enemy clickthrough, and nameplate stacking.
- Added independent Friendly and Enemy interaction fine-tune buttons beneath the playstyle presets.
- Moved the primary Stack Nameplates toggle into Quick Setup; Blizzard's stacking control is global, so friendly and enemy stacking cannot be separated.
- Kept advanced Blizzard stacking spacing controls under General > Blizzard Nameplates without duplicating the stacking toggle.

## 15.6-los-appearance-cleanup
- Simple appearance preset now uses the Standard border with no accent overlay.
- New/default LoS styling uses the Standard border at 70% opacity with the LoS accent overlay disabled.
- Added an explicit Disabled choice for the LoS Accent Overlay.
- Removed the unused LoS Border Opacity Multiplier control; it was not connected to the renderer.
- Removed LoS Pulse controls and LoS pulse rendering to eliminate the flicker-style effect.
- Restored Spec Icon desaturation and class-color tint controls on the Appearance page, including a separate LoS desaturation option.

## 15.7-hover-glow-fix
- Fixed friendly non-LoS mouseover glows briefly flashing and then disappearing.
- Hover fade animations now exclusively control glow alpha while they are running.
- Removed a duplicate accent-glow fade-in call from the friendly hover path.
## 15.8-flare-class-fallback
- Improved enemy aura flare class-color resolution by reusing a class color already resolved by BattleMender's enemy health-bar path when direct class lookup is temporarily unavailable.
- Class flare mode now falls back to the configured Custom Flare Color instead of neutral white when a player class cannot be safely resolved.
- Custom Flare Color remains editable in Class mode because it now also serves as the class-color fallback.

## 15.9-native-friendly-visibility
- Added independent Friendly Plates > General controls to hide Blizzard's native friendly health bar/art and Blizzard player names.
- The native health bar/art is hidden by default while the Blizzard player name remains visible by default, preventing the horizontal Blizzard plate from showing behind BattleMender without forcing users to give up names.
- Both controls use Blizzard CVars rather than hiding or reparenting Blizzard's internal nameplate frame tree.

## 15.10-live-bg-safety
- Fixed a live-battleground Lua error when ordinary settings refreshes attempted to reposition Blizzard-managed defensive AuraButtons after those buttons had become forbidden/restricted. Forbidden managed buttons are now left entirely in Blizzard's ownership.
- Fixed friendly PvP objective badges surviving nameplate recycling and appearing on a different player after the original carrier plate was released. Objective icon, border, glow, pulse, and frame visibility are now cleared with the rest of the friendly overlay.
