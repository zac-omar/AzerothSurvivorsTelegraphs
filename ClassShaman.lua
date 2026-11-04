-- Shaman telegraphs. The fields are described at the top of Core.lua.

AST_Register("shaman", {
	{
		id = "fire_nova", name = "Fire Nova", shape = "circle", spellKey = "fire_nova",
		desc = "The area around you that Fire Nova hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Fire Nova" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 12,
		defaults = { mode = "cast", line = { 1, 0.55, 0.2, 1 }, fill = { 1, 0.4, 0.1, 0.3 } },
	},
	{
		-- "Drops a totem beside you for 17 sec once enemies are within 25 yd. Every 2 sec it deals ...
		-- to every enemy within 10 yd of it." Beside you: 1.5 yd ahead of where you face; its first
		-- pulse half a second after it lands, each one's hits Magma Totem's pulse (8187).
		id = "magma_totem", name = "Magma Totem", shape = "ground", spellKey = "magma_totem",
		atFeet = true, offset = 1.5, firstTick = 0.5,
		desc = "Where Magma Totem burns: the ring around the totem fills in until it's gone.",
		on = { spells = { 8187 }, names = { "magmatotem" } }, range = 0,
		tipNames = { "Magma Totem" }, sizePattern = "within ([%d%.]+) yd of it", durationPattern = "beside you for ([%d%.]+) sec",
		-- 10 yd x Area x (1 + 10% per Totemic Mastery rank), for 17 sec
		areaItem = "item/magmatotem", durationItem = "item/magmatotem",
		base = 10, reachTalent = "totemic_mastery", reachPerRank = 0.10, duration = 17, every = 2, recDuration = 12, tail = 0,
		defaults = { mode = "duration", line = { 1, 0.5, 0.15, 1 }, fill = { 1, 0.35, 0.05, 0.2 } },
	},
	{
		-- Flametongue Weapon: "Rockbiter Weapon has a 5% (10%, 15%) chance to cast a free Fire Nova",
		-- your Fire Nova's size.
		id = "flametongue", name = "Flametongue Weapon", shape = "circle", sizeOf = "fire_nova",
		desc = "With Flametongue Weapon, Rockbiter Weapon can set off a free Fire Nova: this flashes when it does.",
		match = { "enhflametongueweapon", "flametongueweapon" }, talentKeys = { "enhflametongueweapon", "flametongueweapon" },
		needName = "the Flametongue Weapon talent",
		free = { spells = { 1535 }, names = { "firenova" }, ownSpell = "fire_nova" },
		modes = { "proc" },
		defaults = { mode = "proc", line = { 1, 0.7, 0.3, 1 }, fill = { 1, 0.55, 0.15, 0.3 } },
	},
	{
		-- The Emberwake Pendant (Flame Shock): "Each tick of Flame Shock also hits 2 nearby enemies
		-- within 6 yd for 50% damage."
		id = "emberwake", name = "Emberwake Pendant", shape = "enemy", trigger = "hit", radius = 6,
		desc = "With the Emberwake Pendant, each tick of Flame Shock also hits 2 enemies near its target: the area they can be in.",
		match = { "item/flameshock" }, needName = "the Emberwake Pendant",
		on = { spells = { 8050 }, names = { "flameshock" }, ticks = true },
		defaults = { mode = "event", flash = 0.35, line = { 1, 0.5, 0.2, 1 }, fill = { 1, 0.4, 0.1, 0.15 } },
	},
	{
		-- The Heart of the Earthbreaker (Rockbiter Weapon): "The first hit of each cast sends a
		-- shockwave dealing 40% damage to enemies within 6 yards", out of the enemy that hit landed
		-- on.
		id = "earthbreaker", name = "Heart of the Earthbreaker", shape = "enemy", trigger = "hit", radius = 6, cap = 1,
		desc = "With the Heart of the Earthbreaker, the first hit of each Rockbiter Weapon sends a shockwave out of its target: the area it strikes.",
		match = { "item/rockbiter" }, needName = "the Heart of the Earthbreaker",
		on = { spells = { 8017 }, names = { "rockbiterweapon", "rockbiter" } },
		defaults = { mode = "event", flash = 0.45, line = { 0.85, 0.65, 0.35, 1 }, fill = { 0.75, 0.55, 0.25, 0.25 } },
	},
	{
		-- The Uncommon armor set's 8 pieces (each at 3 stars or more): "Enemies dying with your Flame
		-- Shock explode for 15% of their max health on everything within 8 yards." Flashed on the
		-- body as the explosion's own hits land.
		id = "set_flameshock", name = "Uncommon set: Flame Shock kills", shape = "enemy", trigger = "burst", atKill = true,
		kind = "Sets", radius = 8,
		desc = "With all 8 pieces of the Uncommon shaman armor set at 3 stars or more, enemies dying with your Flame Shock on them explode: where they do.",
		on = { source = "^set:1%.shaman" },
		match = { "set/uncommon/shaman/5", "set/uncommon/shaman" }, talentKeys = { "set/uncommon/shaman/5", "set/uncommon/shaman" }, showsItself = true,
		needName = "the Uncommon shaman set's 8 pieces (known from its first explosion)",
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.55, 0.25, 1 }, fill = { 1, 0.4, 0.1, 0.25 } },
	},
	{
		-- The T0.5 armor set's 8 pieces: "Every Stormstrike causes Thunderburst, dealing Nature damage
		-- equal to 25% of its damage to enemies within 6 yd" (8 yd with all eight at 5 stars), out of
		-- the enemy it struck. Known from its first Thunderburst; then around each Stormstrike's
		-- target.
		id = "set_thunderburst", name = "T0.5 set: Thunderburst", shape = "enemy", trigger = "hit",
		kind = "Sets",
		desc = "With all 8 pieces of the T0.5 shaman armor set, every Stormstrike sets off a Thunderburst around its target: the area it hits.",
		match = { "set/t05/shaman/5", "set/t05/shaman" }, talentKeys = { "set/t05/shaman/5", "set/t05/shaman" },
		radii = { ["set/t05/shaman/5"] = 8, ["set/t05/shaman"] = 6 },
		needName = "the T0.5 shaman set's 8 pieces (known from its first Thunderburst)",
		on = { spells = { 17364 }, names = { "stormstrike" } },
		defaults = { mode = "event", flash = 0.4, line = { 0.5, 0.75, 1, 1 }, fill = { 0.35, 0.6, 1, 0.2 } },
	},
	{
		-- How far your targeted spells reach for an enemy.
		id = "shaman_range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Lightning Bolt", "Chain Lightning", "Earth Shock", "Flame Shock", "Frost Shock" },
		sizePattern = "within ([%d%.]+) yd", base = 30, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.3, 0.6, 1, 0.6 }, fill = { 0.3, 0.6, 1, 0 } },
	},
}, {
	icon = "Interface\\Icons\\Spell_Nature_BloodLust",
	gear = {
		{ "Emberwake Pendant", "item/flameshock" },
		{ "Each tick of Flame Shock also hits", "item/flameshock" },
		{ "Heart of the Earthbreaker", "item/rockbiter" },
		{ "Rockbiter Weapon's primary hit unleashes", "item/rockbiter" },
		{ "Amulet of the Ancients: Magma Totem", "item/magmatotem" },
		{ "^Magma Totem: %+", "item/magmatotem" },
	},
});
