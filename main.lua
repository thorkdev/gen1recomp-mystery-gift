-- Mystery Gift: a MYSTERY GIFT row on the START menu that hands out one
-- free Pokemon or item per real-world calendar day. The day's pick is a
-- deterministic hash of the date string, not math.random/math.randomseed --
-- touching the shared RNG stream here would perturb battle/encounter rolls
-- that happen to run the same frame.
--
-- Claim state lives in save.modData["mystery-gift"] (mod.save / the
-- script "mod:" field route both read/write that same table), so it's
-- per save file and survives a reload.

return function(mod)
  -- minBadges gates an entry into the day's pool; pool grows (and gets
  -- better) as the badge case fills instead of ever losing entries, so a
  -- fresh save and a post-Elite-Four save both always have something
  -- eligible.
  local REWARDS = {
    -- tier 0: nothing gates these, so a brand new save always has a gift
    { kind = "item", item = "POTION", qty = 1, minBadges = 0 },
    { kind = "pokemon", species = "PIDGEY", level = 3, minBadges = 0 },

    -- tier 1: a second shot at any starter you didn't pick from Oak, plus
    -- VULPIX/GROWLITHE so either version's cross-game exclusive is
    -- reachable without a trade
    { kind = "item", item = "GREAT_BALL", qty = 2, minBadges = 1 },
    { kind = "pokemon", species = "BULBASAUR", level = 8, minBadges = 1 },
    { kind = "pokemon", species = "CHARMANDER", level = 8, minBadges = 1 },
    { kind = "pokemon", species = "SQUIRTLE", level = 8, minBadges = 1 },
    { kind = "pokemon", species = "ABRA", level = 8, minBadges = 1 },
    { kind = "pokemon", species = "VULPIX", level = 8, minBadges = 1 },

    -- tier 2
    { kind = "pokemon", species = "EEVEE", level = 10, minBadges = 2 },
    { kind = "pokemon", species = "GROWLITHE", level = 10, minBadges = 2 },
    { kind = "pokemon", species = "MACHOP", level = 10, minBadges = 2 },
    { kind = "item", item = "NUGGET", qty = 1, minBadges = 2 },

    -- tier 3
    { kind = "pokemon", species = "PIKACHU", level = 12, minBadges = 3 },
    { kind = "pokemon", species = "ONIX", level = 12, minBadges = 3 },
    { kind = "pokemon", species = "MAGNEMITE", level = 12, minBadges = 3 },
    { kind = "item", item = "TM_DIG", qty = 1, minBadges = 3 },

    -- tier 4
    { kind = "item", item = "RARE_CANDY", qty = 1, minBadges = 4 },
    { kind = "item", item = "PP_UP", qty = 1, minBadges = 4 },
    { kind = "item", item = "TM_SWORDS_DANCE", qty = 1, minBadges = 4 },

    -- tier 5: the Safari Zone rarities, without the Safari Zone
    { kind = "pokemon", species = "DRATINI", level = 20, minBadges = 5 },
    { kind = "pokemon", species = "SCYTHER", level = 20, minBadges = 5 },
    { kind = "item", item = "TM_ICE_BEAM", qty = 1, minBadges = 5 },

    -- tier 6
    { kind = "pokemon", species = "CHANSEY", level = 22, minBadges = 6 },
    { kind = "item", item = "MAX_REVIVE", qty = 1, minBadges = 6 },
    { kind = "item", item = "FULL_RESTORE", qty = 2, minBadges = 6 },
    { kind = "item", item = "TM_THUNDERBOLT", qty = 1, minBadges = 6 },

    -- tier 7
    { kind = "pokemon", species = "KANGASKHAN", level = 25, minBadges = 7 },
    { kind = "item", item = "TM_FIRE_BLAST", qty = 1, minBadges = 7 },

    -- tier 8: all badges. MEW is the marquee mystery gift, so it's the one
    -- entry gated on the full case rather than an in-between count
    { kind = "pokemon", species = "MEW", level = 10, minBadges = 8 },
    { kind = "pokemon", species = "DRATINI", level = 28, minBadges = 8 },
    { kind = "item", item = "RARE_CANDY", qty = 3, minBadges = 8 },
    { kind = "item", item = "TM_EARTHQUAKE", qty = 1, minBadges = 8 },
  }

  -- constants.badges order (src/inventory/Badges.lua); badges are just
  -- item ids in save.inventory, so this needs no private require
  local BADGE_IDS = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }

  local function badgeCount(game)
    local inv = game.save and game.save.inventory
    if not inv then return 0 end
    local n = 0
    for _, id in ipairs(BADGE_IDS) do
      if inv[id] then n = n + 1 end
    end
    return n
  end

  local function eligiblePool(badges)
    local pool = {}
    for _, reward in ipairs(REWARDS) do
      if (reward.minBadges or 0) <= badges then pool[#pool + 1] = reward end
    end
    return pool
  end

  local function todayKey()
    return os.date("%Y-%m-%d")
  end

  -- djb2 over the date string, kept local so nothing here touches
  -- math.random's shared state
  local function pickIndex(key, count)
    local h = 5381
    for i = 1, #key do
      h = (h * 33 + key:byte(i)) % 2147483647
    end
    return (h % count) + 1
  end

  local function claim(game)
    local key = todayKey()
    if mod.save:get("lastClaim") == key then
      mod.world:queueScript({
        { "show_text", "There's no gift\nfor you today..." },
        { "show_text", "Come back\ntomorrow!" },
      }, { source = { modId = mod.id } })
      return
    end

    -- OFF: no badge gate, every reward is always in play
    local scaling = mod.save:get("badgeScaling", true)
    local pool = scaling and eligiblePool(badgeCount(game)) or REWARDS
    local reward = pool[pickIndex(key, #pool)]

    -- Two boxes, not one three-line box: \n only fills the box's two
    -- lines, so a third auto-scrolls (vanilla <CONT>), which read as the
    -- announcement and the question running together. "ask" is the
    -- vanilla show-then-YES/NO primitive (Commands.ask); declining leaves
    -- lastClaim unset, so the gift is still there on a later visit.
    local rows = {
      { "show_text", "Someone left you\na MYSTERY GIFT!" },
      { "ask", "Open it now?" },
      { "jump_if_false", "declined" },
      { "show_text", "Your gift is on\nits way..." },
    }

    if reward.kind == "pokemon" then
      -- mirrors data/scripts/celadon_eevee.lua: only mark the day claimed
      -- once GivePokemon actually succeeds, so a full party+boxes leaves
      -- the gift claimable again later instead of burning the day. The
      -- nickname prompt (give_pokemon's own askNickname) lands here too,
      -- now with the ask/"on its way" text ahead of it for context.
      local giftRows = {
        { "give_pokemon", reward.species, reward.level },
        { "jump_if_false", "full" },
        { "play_sound", "Get_Item1" },
        { "show_text", "_GotMonText", { RAM = reward.species } },
        { "set_field", "mod:lastClaim", key },
        { "jump", "done" },
        { "label", "full" },
        { "show_text", "_BoxIsFullText" },
        { "jump", "done" },
      }
      for _, row in ipairs(giftRows) do rows[#rows + 1] = row end
    else
      -- give_item's default gotText already announces what was received
      rows[#rows + 1] = { "give_item", reward.item, reward.qty }
      rows[#rows + 1] = { "set_field", "mod:lastClaim", key }
      rows[#rows + 1] = { "jump", "done" }
    end

    rows[#rows + 1] = { "label", "declined" }
    rows[#rows + 1] = { "show_text", "Maybe next time!" }
    rows[#rows + 1] = { "label", "done" }

    local ok, err = mod.world:queueScript(rows, { source = { modId = mod.id } })
    if not ok then
      mod.log:warn("could not deliver the daily gift: %s", tostring(err))
    end
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "MYSTERY GIFT",
      onSelect = function() claim(game) end,
    })
  end)

  -- OPTIONS row: cycles like the vanilla ON/OFF rows (BATTLE ANIMATION etc.)
  -- -- value/step against mod.save, so the setting is per save file same as
  -- everything else on that screen
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "mystery_gift_scaling",
      label = "GIFT SCALING",
      value = function()
        return mod.save:get("badgeScaling", true) and "ON" or "OFF"
      end,
      step = function()
        mod.save:set("badgeScaling", not mod.save:get("badgeScaling", true))
        return true
      end,
    }
    -- activate, not step (12 4.5): a one-shot action reads on A, not
    -- Left/Right, same as CONTROLS/MODS above it
    out[#out + 1] = {
      id = "mystery_gift_reset",
      label = "RESET GIFT",
      value = function()
        return mod.save:get("lastClaim") == todayKey() and "CLAIMED" or "OPEN"
      end,
      activate = function()
        mod.save:set("lastClaim", nil)
      end,
    }
    return out
  end)
end