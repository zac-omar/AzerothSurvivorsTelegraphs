-- Warlock telegraphs. The fields are described at the top of Core.lua.

AST_Register("warlock", {
	{
		id = "hellfire", name = "Hellfire", shape = "circle", spellKey = "hellfire",
		desc = "The area around you that each pulse of Hellfire burns.",
		modes = { "cast", "cooldown" },
		tipNames = { "Hellfire" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 7 yd x Area x (1 + 8% per Destructive Reach rank)
		base = 7, reachTalent = "destructive_reach", reachPerRank = 0.08,
		defaults = { mode = "cast", line = { 1, 0.45, 0.15, 1 }, fill = { 0.9, 0.3, 0.05, 0.3 } },
	},
	{
		-- "Lands on the thickest group of enemies within 30 yd: every enemy within 8 yd of that spot
		-- takes ... every 1.9 sec for 11 sec".
		id = "rain_of_fire", name = "Rain of Fire", shape = "ground", spellKey = "rain_of_fire",
		desc = "Where Rain of Fire lands: the fire fills in from its centre until it stops.",
		on = { spells = { 5740 }, names = { "rainoffire" } }, range = 30,
		tipNames = { "Rain of Fire" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/rainoffire", durationItem = "item/rainoffire",
		base = 8, reachTalent = "destructive_reach", reachPerRank = 0.08, duration = 11, every = 1.9, recDuration = 8,
		defaults = { mode = "duration", line = { 1, 0.5, 0.15, 1 }, fill = { 1, 0.35, 0.05, 0.25 } },
	},
	{
		-- Rain of Chaos (Destruction capstone): "A second Rain of Fire falls on its own every 13 sec".
		-- It is cast as Rain of Fire is, so it lands the same way; the spell list doesn't show it, so
		-- its first tick places it, a quarter second after it fell.
		id = "rain_of_chaos", name = "Rain of Chaos", shape = "ground", freeFall = "rain_of_fire",
		desc = "With Rain of Chaos, a second Rain of Fire falls on its own: where it lands (shown with its first tick).",
		on = { spells = { 5740 }, names = { "rainoffire" } }, range = 30,
		tipNames = { "Rain of Fire" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/rainoffire", durationItem = "item/rainoffire",
		base = 8, reachTalent = "destructive_reach", reachPerRank = 0.08, duration = 11, every = 1.9, recDuration = 8,
		match = { "rainofchaos" }, talentKeys = { "rainofchaos" },
		needName = "the Rain of Chaos talent",
		defaults = { mode = "duration", line = { 1, 0.6, 0.3, 1 }, fill = { 1, 0.45, 0.15, 0.25 } },
	},
	{
		-- Conflagrate (Destruction milestone): "Shadow Bolt and Searing Pain make Immolated enemies
		-- explode for 15% of the hit's damage within 6 yd."
		id = "conflagrate", name = "Conflagrate", shape = "enemy", trigger = "hit", radius = 6,
		desc = "With Conflagrate, Shadow Bolt and Searing Pain make an enemy burning with your Immolate explode: the area it hits.",
		match = { "conflagrate" }, talentKeys = { "conflagrate" }, needs = { conflagrate = "immolate" },
		on = { spells = { 686, 5676 }, names = { "shadowbolt", "searingpain" } },
		defaults = { mode = "event", flash = 0.4, line = { 1, 0.55, 0.2, 1 }, fill = { 1, 0.4, 0.1, 0.25 } },
	},
	{
		-- Seed of Corruption (Affliction capstone): "enemies that die afflicted by your damage-over-
		-- time effects burst for ...% of their maximum health on everything within 6 yd."
		id = "seed_of_corruption", name = "Seed of Corruption", shape = "enemy", trigger = "kill", radius = 6,
		desc = "With Seed of Corruption, enemies that die with your damage over time on them burst: where they do.",
		match = { "seedofcorruption" }, talentKeys = { "seedofcorruption" }, needs = { seedofcorruption = "any" },
		defaults = { mode = "event", flash = 0.5, line = { 0.6, 0.35, 1, 1 }, fill = { 0.45, 0.2, 0.8, 0.25 } },
	},
	{
		-- The Pendant of the Plague on one of your damage-over-time spells: enemies that die with it
		-- on them explode for 20% of their max health on everything within 7 yd, at most 2 a second.
		id = "warlock_pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Pendant of the Plague on one of your damage-over-time spells, enemies that die with it on them explode: where they do.",
		match = { "item/corruption", "item/curseofagony", "item/drainlife", "item/immolate" },
		needs = { ["item/corruption"] = "corruption", ["item/curseofagony"] = "agony", ["item/drainlife"] = "drain", ["item/immolate"] = "immolate" },
		needName = "the Pendant of the Plague (on Corruption, Curse of Agony, Drain Life or Immolate)",
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- The Amulet of the Inferno on Rain of Fire: enemies it kills explode for 30% of their max
		-- health on everything within 7 yd, at most 2 times a second.
		id = "inferno_rainoffire", name = "Inferno: Rain of Fire kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on Rain of Fire, enemies Rain of Fire kills explode: where they do.",
		match = { "item/rainoffire" }, needName = "the Amulet of the Inferno (Rain of Fire)",
		by = { spells = { 5740 }, names = { "rainoffire" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.6, 0.25, 1 }, fill = { 1, 0.45, 0.1, 0.25 } },
	},
	{
		-- How far your targeted spells reach for an enemy.
		id = "warlock_range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Shadow Bolt", "Corruption", "Immolate", "Curse of Agony" },
		sizePattern = "within ([%d%.]+) yd", base = 30, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.58, 0.51, 0.79, 0.6 }, fill = { 0.58, 0.51, 0.79, 0 } },
	},
}, {
	icon = "Interface\\Icons\\Spell_Nature_FaerieFire",
	gear = {
		{ "Pendant of the Plague: Corruption", "item/corruption" },
		{ "die with Corruption on them explode", "item/corruption" },
		{ "Pendant of the Plague: Curse of Agony", "item/curseofagony" },
		{ "die with Curse of Agony on them explode", "item/curseofagony" },
		{ "Pendant of the Plague: Drain Life", "item/drainlife" },
		{ "die with Drain Life on them explode", "item/drainlife" },
		{ "Pendant of the Plague: Immolate", "item/immolate" },
		{ "die with Immolate on them explode", "item/immolate" },
		{ "Amulet of the Inferno: Rain of Fire", "item/rainoffire" },
		{ "Enemies Rain of Fire kills explode", "item/rainoffire" },
		{ "^Rain of Fire: %+", "item/rainoffire" },
	},
	-- damage over time an enemy can carry or die with
	dots = {
		corruption = { spells = { 172 }, names = { "corruption" }, keys = { "corruption" } },
		immolate = { spells = { 348 }, names = { "immolate" }, keys = { "immolate" } },
		agony = { spells = { 980 }, names = { "curseofagony" }, keys = { "curseofagony" } },
		drain = { spells = { 689 }, names = { "drainlife" }, keys = { "drainlife" } },
	},
});
