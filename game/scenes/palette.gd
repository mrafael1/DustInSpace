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
