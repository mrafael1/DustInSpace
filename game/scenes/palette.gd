class_name Palette
extends RefCounted
## Colours from assets/palettes/stellar_sun.gpl, for views that draw in code.
## Add a colour here only when a view uses it; tests check each one against the .gpl.

## Starlight ramp: collectibles, links, particles. C4-C5 are for halos only.
const C0 := Color("#FFFBEA")
const C1 := Color("#FFE59A")
const C2 := Color("#FFC062")
const C3 := Color("#E88A57")
const C4 := Color("#A45A78")
const C5 := Color("#6A3F7A")

## Sky ramp: UI plaques use an N0 fill and an N6 border; N7 marks things with no value.
const N0 := Color("#07091F")
const N6 := Color("#5A51A6")
const N7 := Color("#7E68C8")

## Dim Sun ramp. S4 (ember) marks a rejected link: blue and red are reserved for packs.
const S4 := Color("#D0542E")

## Dust ramp: dust icon, numbers, particles.
const D0 := Color("#D9CCFF")

## Land ramp: the slingshot's fork, handle and bands.
const M1 := Color("#121638")
const M3 := Color("#2B3470")
const M4 := Color("#4A5AA8")
const M5 := Color("#9FB0EE")

## Pack ramps, dark to light. Blue and red appear only on packs.
const BLUE_PACK: Array[Color] = [Color("#12245A"), Color("#1D4696"), Color("#2F78D0"), Color("#62B4F0"), Color("#B8E6FF")]
const RED_PACK: Array[Color] = [Color("#4A1226"), Color("#862032"), Color("#C8413A"), Color("#F07A4E"), Color("#FFC09A")]
