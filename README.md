# Mystery Gift

Adds a **MYSTERY GIFT** row to the START menu. Once per real-world calendar
day it offers a free Pokémon or item — which one is deterministic for that
day and scales with how many badges you're carrying.

## Try it

Enable it (`mystery-gift = true` under `mods` in `options.lua`, or the F10
manager), then from the overworld: START → MYSTERY GIFT.

- **A gift is waiting** → confirm YES to open it, NO to leave it for later
  (declining does not spend the day).
- **Already claimed today** → a short "come back tomorrow" message instead.

## Reward tiers

The pool an entry belongs to is gated by badge count (`minBadges`), not
excluded by it — a fresh save only sees tier 0, a post-Elite-Four save sees
everything through tier 8. The day's pick is deterministic (see below), not
uniformly random, so it's the same for everyone on the same calendar day at
a given badge count.

| Badges | Pokémon | Items |
|---|---|---|
| 0 | Pidgey Lv3 | Potion |
| 1 | Bulbasaur, Charmander, Squirtle, Abra, Vulpix (all Lv8) | Great Ball ×2 |
| 2 | Eevee, Growlithe, Machop (all Lv10) | Nugget |
| 3 | Pikachu, Onix, Magnemite (all Lv12) | TM_DIG |
| 4 | — | Rare Candy, PP Up, TM_SWORDS_DANCE |
| 5 | Dratini, Scyther (Lv20) | TM_ICE_BEAM |
| 6 | Chansey Lv22 | Max Revive, Full Restore ×2, TM_THUNDERBOLT |
| 7 | Kangaskhan Lv25 | TM_FIRE_BLAST |
| 8 (all badges) | **Mew Lv10**, Dratini Lv28 | Rare Candy ×3, TM_EARTHQUAKE |

Tier 1 doubles as a second shot at whichever starter you didn't pick from
Oak, plus Vulpix/Growlithe so either version's cross-game exclusive is
reachable without a trade. Tier 8's Mew is the marquee gift and stays
exclusive to the full badge case rather than an in-between count.

If a Pokémon gift can't fit (party and every box full), the day is **not**
marked claimed — the gift is still there next time you have room, same as
the vanilla Celadon Mansion Eevee ball.

## OPTIONS rows

Two rows are added under START → OPTION, appended after the vanilla rows:

- **GIFT SCALING** (ON/OFF, default ON) — OFF drops the badge gate
  entirely, so every tier is always in the day's pool regardless of
  progress.
- **RESET GIFT** (shows OPEN/CLAIMED, press A) — clears today's claim, for
  testing without waiting for the date to roll over.

## How the daily pick works

The reward index is a djb2 hash of `os.date("%Y-%m-%d")`, not
`math.random`/`math.randomseed` — touching the shared RNG stream would
perturb battle and encounter rolls that happen to run the same frame. The
hash is local to this mod and never reseeds anything global.

Claim state (`lastClaim`, the last date claimed) lives in
`save.modData["mystery-gift"]` — `mod.save:get/set` from Lua and the script
`set_field "mod:lastClaim"` route both read/write that same table, so it's
per save file and survives a reload.