-- Mage telegraphs. The fields are described at the top of Core.lua.

AST_Register("mage", {
	{
		id = "frost_nova", name = "Frost Nova", shape = "circle", spellKey = "frost_nova",
		desc = "The area around you that Frost Nova hits and roots.",
		modes = { "cast", "cooldown" },
		tipNames = { "Frost Nova" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 10 yd x Area x (1 + 10% per Arctic Reach rank)
		base = 10, reachTalent = "arctic_reach", reachPerRank = 0.10,
		defaults = { mode = "cast", line = { 0.55, 0.85, 1, 1 }, fill = { 0.45, 0.75, 1, 0.3 } },
	},
	{
		id = "arcane_explosion", name = "Arcane Explosion", shape = "circle", spellKey = "arcane_explosion",
		desc = "The area around you that Arcane Explosion hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Arcane Explosion" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 9 yd x Area x (1 + 12% per Improved Arcane Explosion rank)
		base = 9, reachTalent = "imp_arcane_explosion", reachPerRank = 0.12,
		defaults = { mode = "cast", line = { 0.85, 0.55, 1, 1 }, fill = { 0.75, 0.45, 1, 0.3 } },
	},
	{
		id = "blast_wave", name = "Blast Wave", shape = "circle", spellKey = "blast_wave",
		desc = "The area around you that Blast Wave hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Blast Wave" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 10 yd x Area
		base = 10,
		defaults = { mode = "cast", line = { 1, 0.6, 0.25, 1 }, fill = { 1, 0.45, 0.1, 0.3 } },
	},
	{
		id = "cone_of_cold", name = "Cone of Cold", shape = "cone", spellKey = "cone_of_cold",
		desc = "The cone Cone of Cold hits in front of you, sized from its tooltip so every bonus counts.",
		modes = { "cast", "cooldown" },
		halfAngle = 60,
		tipNames = { "Cone of Cold" }, sizePattern = "([%d%.]+) yd cone",
		-- 12 yd x Area x (1 + 10% per Arctic Reach rank)
		base = 12, reachTalent = "arctic_reach", reachPerRank = 0.10,
		defaults = { mode = "cast", line = { 0.65, 0.9, 1, 1 }, fill = { 0.5, 0.8, 1, 0.3 } },
	},
	{
		-- "Lands on the thickest group of enemies within 30 yd: every enemy within 9 yd of that spot
		-- takes ... every 1 sec for 9.8 sec".
		id = "blizzard", name = "Blizzard", shape = "ground", spellKey = "blizzard",
		desc = "Where Blizzard lands: the storm fills in from its centre until it ends.",
		on = { spells = { 10 }, names = { "blizzard" } }, range = 30,
		tipNames = { "Blizzard" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		-- 9 yd x Area x (1 + 10% per Arctic Reach rank), for 9.8 sec, a tick every second
		areaItem = "item/blizzard", durationItem = "item/blizzard",
		base = 9, reachTalent = "arctic_reach", reachPerRank = 0.10, duration = 9.8, every = 1, recDuration = 7,
		defaults = { mode = "duration", line = { 0.6, 0.85, 1, 1 }, fill = { 0.5, 0.75, 1, 0.25 } },
	},
	{
		-- "Lands on the thickest group of enemies within 30 yd: every enemy within 8 yd of that spot
		-- takes ... every 2.1 sec for 8.4 sec".
		id = "flamestrike", name = "Flamestrike", shape = "ground", spellKey = "flamestrike",
		desc = "Where Flamestrike lands: the fire fills in from its centre until it burns out.",
		on = { spells = { 2120 }, names = { "flamestrike" } }, range = 30,
		tipNames = { "Flamestrike" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		-- 8 yd x Area, for 8.4 sec, a tick every 2.1 sec
		areaItem = "item/flamestrike", durationItem = "item/flamestrike",
		base = 8, duration = 8.4, every = 2.1, recDuration = 6,
		defaults = { mode = "duration", line = { 1, 0.55, 0.2, 1 }, fill = { 1, 0.4, 0.1, 0.25 } },
	},
	{
		-- "Your spells have a 12% chance to turn the enemy they hit into a sheep ... the next hit on
		-- it pops it in an arcane burst ... on every enemy within 7 yd": 7 yd x Area (and the Charm
		-- of the Fated Hour's "+N% area").
		id = "polymorph", name = "Polymorph", shape = "enemy", trigger = "burst", spellKey = "polymorph", kind = "Spells",
		match = { "polymorph" }, talentKeys = { "polymorph" }, needName = "the Polymorph ability",
		desc = "With Polymorph, where a sheep pops: the arcane burst around it.",
		on = { spells = { 118 }, names = { "polymorph" } },
		tipNames = { "Polymorph" }, sizePattern = "on every enemy within ([%d%.]+) yd",
		base = 7, areaItem = "item/polymorph",
		defaults = { mode = "event", flash = 0.5, line = { 0.9, 0.6, 1, 1 }, fill = { 0.8, 0.5, 1, 0.25 } },
	},
	{
		-- Arcane Concentration (Arcane milestone): "every spell you cast has a 30% chance to set off a
		-- free Arcane Explosion", your Arcane Explosion's size.
		id = "arcane_concentration", name = "Clearcasting explosion", shape = "circle", sizeOf = "arcane_explosion",
		desc = "With Arcane Concentration, a spell you cast can set off a free Arcane Explosion: this flashes when one does.",
		match = { "arcaneconcentration" }, talentKeys = { "arcaneconcentration" },
		needName = "the Arcane Concentration talent",
		free = { spells = { 1449 }, names = { "arcaneexplosion" }, ownSpell = "arcane_explosion" },
		defaults = { mode = "proc", line = { 0.95, 0.75, 1, 1 }, fill = { 0.85, 0.6, 1, 0.3 } },
	},
	{
		-- Summon Water Elemental (Frost capstone): "a free Frost Nova bursts from you every 8 sec",
		-- your Frost Nova's size.
		id = "water_nova", name = "Water Elemental nova", shape = "circle", sizeOf = "frost_nova",
		desc = "With the Water Elemental, a free Frost Nova bursts from you every 8 sec: the ring fills toward the next one.",
		match = { "summonwaterelemental", "waterelemental" }, talentKeys = { "summonwaterelemental", "waterelemental" },
		needName = "the Summon Water Elemental talent",
		clock = { names = { "Summon Water Elemental", "Water Elemental" }, every = 8 },
		free = { spells = { 122 }, names = { "frostnova" }, ownSpell = "frost_nova" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "cooldown", line = { 0.45, 0.75, 1, 1 }, fill = { 0.35, 0.65, 1, 0.15 } },
	},
	{
		-- Pyroclasm (Fire capstone): "enemies killed by your Fire spells explode for 25% of their
		-- maximum health on everything within 6 yd, at most 3 a second".
		id = "pyroclasm", name = "Pyroclasm", shape = "enemy", trigger = "kill", cap = 3, radius = 6,
		desc = "With Pyroclasm, enemies your Fire spells kill explode: where they do.",
		match = { "pyroclasm" }, talentKeys = { "pyroclasm" },
		-- your Fire spells: Fireball, Fire Blast, Pyroblast, Flamestrike, Blast Wave, and Ignite's burn
		by = { spells = { 133, 2136, 11366, 2120, 11113, 12654 },
			names = { "fireball", "fireblast", "pyroblast", "flamestrike", "blastwave", "ignite" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.5, 0.15, 1 }, fill = { 1, 0.4, 0.05, 0.25 } },
	},
	{
		-- Splitting Ice (Frost milestone): "Frostbolt splinters on impact: ... every enemy within 5 yd
		-- of its target."
		id = "splitting_ice", name = "Splitting Ice", shape = "enemy", trigger = "hit", radius = 5,
		desc = "With Splitting Ice, each Frostbolt splinters where it lands: the area the splinters strike.",
		match = { "splittingice" }, talentKeys = { "splittingice" },
		on = { spells = { 116 }, names = { "frostbolt" } },
		defaults = { mode = "event", flash = 0.4, line = { 0.7, 0.92, 1, 1 }, fill = { 0.55, 0.85, 1, 0.2 } },
	},
	{
		-- The Amulet of the Inferno on Blizzard: "Enemies Blizzard kills explode for 30% of their max
		-- health, at most 2 times a second", on everything within 7 yd.
		id = "inferno_blizzard", name = "Inferno: Blizzard kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on Blizzard, enemies Blizzard kills explode: where they do.",
		match = { "item/blizzard" }, needName = "the Amulet of the Inferno (Blizzard)",
		by = { spells = { 10 }, names = { "blizzard" } },
		defaults = { mode = "event", flash = 0.5, line = { 0.6, 0.85, 1, 1 }, fill = { 0.45, 0.75, 1, 0.25 } },
	},
	{
		-- The Amulet of the Inferno on Flamestrike: "Enemies Flamestrike kills explode for 30% of their
		-- max health, at most 2 times a second", on everything within 7 yd.
		id = "inferno_flamestrike", name = "Inferno: Flamestrike kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on Flamestrike, enemies Flamestrike kills explode: where they do.",
		match = { "item/flamestrike" }, needName = "the Amulet of the Inferno (Flamestrike)",
		by = { spells = { 2120 }, names = { "flamestrike" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.55, 0.2, 1 }, fill = { 1, 0.4, 0.1, 0.25 } },
	},
	{
		-- The Eternal Talisman on Ice Barrier: "A broken shield bursts for 50% of what it absorbed on
		-- enemies within 10 yd".
		id = "ice_barrier_burst", name = "Ice Barrier burst", shape = "circle",
		desc = "With The Eternal Talisman on Ice Barrier, a broken Ice Barrier bursts: this flashes where it hits.",
		buffSpells = { 11426 },
		match = { "item/icebarrier" }, radii = { ["item/icebarrier"] = 10 },
		needName = "The Eternal Talisman (Ice Barrier)",
		defaults = { mode = "shield", line = { 0.7, 0.9, 1, 1 }, fill = { 0.6, 0.85, 1, 0.12 } },
	},
	{
		-- How far your targeted spells look for enemies.
		id = "mage_range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Fireball", "Frostbolt", "Arcane Missiles", "Pyroblast" },
		sizePattern = "within ([%d%.]+) yd", base = 30, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.55, 0.8, 1, 0.6 }, fill = { 0.55, 0.8, 1, 0 } },
	},
}, {
	icon = "Interface\\Icons\\Spell_Frost_IceStorm",
	-- legendary amulets, by their tooltips: { text on the name or a line, the key it gives }
	gear = {
		{ "Amulet of the Inferno: Blizzard", "item/blizzard" },
		{ "Enemies Blizzard kills explode", "item/blizzard" },
		{ "Amulet of the Inferno: Flamestrike", "item/flamestrike" },
		{ "Enemies Flamestrike kills explode", "item/flamestrike" },
		{ "The Eternal Talisman: Ice Barrier", "item/icebarrier" },
		{ "A broken shield bursts", "item/icebarrier" },
		{ "Charm of the Fated Hour: Polymorph", "item/polymorph" },
		{ "Polymorph: %+[%d%.]+%% area", "item/polymorph" },
		{ "^Blizzard: %+", "item/blizzard" },
		{ "^Flamestrike: %+", "item/flamestrike" },
	},
});
