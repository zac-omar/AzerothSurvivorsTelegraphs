-- Priest telegraphs. The fields are described at the top of Core.lua.

AST_Register("priest", {
	{
		id = "mind_flay", name = "Mind Flay", shape = "cone", spellKey = "mind_flay",
		desc = "The cone Mind Flay hits in front of you, sized from its tooltip so every bonus counts.",
		modes = { "cast", "cooldown" },
		-- every enemy within 60 degrees either side of where you face
		halfAngle = 60,
		tipNames = { "Mind Flay" }, sizePattern = "([%d%.]+) yd cone",
		-- 16 yd x Area x (1 + 10% per Shadow Reach rank); misses Mind Flay's own "+% area" upgrades
		base = 16, reachTalent = "shadow_reach", reachPerRank = 0.10,
		defaults = { mode = "cooldown", line = { 0.75, 0.45, 1, 1 }, fill = { 0.55, 0.25, 0.95, 0.3 } },
	},
	{
		id = "holy_nova", name = "Holy Nova", shape = "circle", spellKey = "holy_nova",
		desc = "The area around you that Holy Nova hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Holy Nova" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 10 yd x Area x (1 + 10% per Holy Reach rank). Chastise's free novas are the same size.
		base = 10, reachTalent = "holy_reach", reachPerRank = 0.10,
		defaults = { mode = "cast", line = { 1, 0.85, 0.35, 1 }, fill = { 1, 0.8, 0.3, 0.3 } },
	},
	{
		-- Chastise (Holy capstone): a Smite cast that crits sets off a free Holy Nova. Your hero
		-- is known to have it once a Holy Nova you didn't cast follows a Smite crit.
		id = "chastise", name = "Chastise", shape = "circle", sizeOf = "holy_nova",
		desc = "With the Chastise talent, a Smite crit sets off a free Holy Nova: this flashes when it does.",
		match = { "chastise" }, talentKeys = { "chastise" },
		needName = "the Chastise talent (spotted at its first free nova after a Smite crit)",
		procOn = { spells = { 585 }, names = { "smite" }, crit = true, gap = 0.25 },
		spot = { spells = { 15237 }, names = { "holynova" }, ownSpell = "holy_nova", window = 0.6 },
		defaults = { mode = "proc", line = { 1, 1, 0.8, 1 }, fill = { 1, 0.95, 0.6, 0.3 } },
	},
	{
		-- Radiance (Holy milestone): "A Holy Nova bursts from you on its own every 24 sec." Timed by
		-- the talent's clock, or else from the free novas seen (not Chastise's, which follow a Smite
		-- crit); each one is your Holy Nova's size.
		id = "radiance", name = "Radiance", shape = "circle", sizeOf = "holy_nova", kind = "Talents",
		desc = "With the Radiance talent, a free Holy Nova bursts from you every 24 sec: the ring fills toward the next one.",
		-- its own reading of Holy Nova's size, for when Holy Nova's telegraph is left to Priest Telegraphs
		tipNames = { "Holy Nova" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 10, reachTalent = "holy_reach", reachPerRank = 0.10,
		match = { "holynovatalent", "radiance" }, talentKeys = { "holynovatalent", "radiance" },
		needName = "the Radiance talent",
		clock = { names = { "Radiance" }, every = 24 },
		free = { spells = { 15237 }, names = { "holynova" }, ownSpell = "holy_nova", unless = "chastise" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "cooldown", line = { 1, 0.95, 0.55, 1 }, fill = { 1, 0.9, 0.45, 0.18 } },
	},
	{
		id = "psychic_scream", name = "Psychic Scream", shape = "circle", spellKey = "psychic_scream",
		desc = "The area around you that Psychic Scream fears enemies in.",
		modes = { "cast", "cooldown" },
		tipNames = { "Psychic Scream" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 10,
		defaults = { mode = "cast", line = { 0.9, 0.35, 0.85, 1 }, fill = { 0.65, 0.2, 0.75, 0.3 } },
	},
	{
		-- Divine Aegis: a shield on you that breaks strikes every enemy within 10 yd. The Eternal
		-- Talisman on Power Word: Shield: "A broken shield bursts ... on enemies within 10 yd"; the
		-- Uncommon set's 8 pieces: "When Power Word: Shield breaks it explodes ... within 8 yards"
		-- (known from its first explosion, or its text on your gear). Shown only with one of them.
		id = "shield", name = "Shield burst", shape = "circle",
		desc = "With Divine Aegis, the Power Word: Shield amulet or its set, your shield bursts when it breaks: this flashes where it hits.",
		buffSpells = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
		match = { "divineaegis", "item/pwshield", "set/uncommon/priest", "set/pwshield" },
		talentKeys = { "divineaegis", "set/uncommon/priest" },
		radii = { divineaegis = 10, ["item/pwshield"] = 10, ["set/uncommon/priest"] = 8, ["set/pwshield"] = 8 },
		needName = "Divine Aegis, The Eternal Talisman (Power Word: Shield) or its set",
		defaults = { mode = "shield", line = { 1, 1, 0.65, 1 }, fill = { 1, 1, 0.75, 0.12 } },
	},
	{
		-- How far your targeted spells look for enemies.
		id = "range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Smite", "Mind Blast", "Holy Fire", "Shadow Word: Pain", "Devouring Plague" },
		sizePattern = "within ([%d%.]+) yd", base = 28, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.55, 0.8, 1, 0.6 }, fill = { 0.55, 0.8, 1, 0 } },
	},
	{
		-- "Enemies that die with Shadow Word: Pain (or Devouring Plague) on them explode for 20% of
		-- their max health, at most 2 times a second", on everything within 7 yd.
		id = "pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2,
		desc = "Enemies that die with your Shadow Word: Pain (or Devouring Plague) on them explode: where they do.",
		match = { "item/swpain", "item/devouringplague", "pendantoftheplague" },
		needs = { ["item/swpain"] = "swp", ["item/devouringplague"] = "dp", pendantoftheplague = "any" },
		radius = 7,
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- Shadowform (capstone): "when an enemy dies with Shadow Word: Pain on it, it bursts for 4%
		-- of its maximum health on everything within 6 yd". Known by its aura.
		id = "shadowform", name = "Shadowform burst", shape = "enemy", trigger = "kill",
		desc = "With the Shadowform capstone, enemies that die with your Shadow Word: Pain burst: where they do.",
		match = { "shadowform" }, talentKeys = { "shadowform" }, needs = { shadowform = "swp" }, radius = 6,
		defaults = { mode = "event", flash = 0.5, line = { 0.6, 0.35, 1, 1 }, fill = { 0.45, 0.2, 0.8, 0.25 } },
	},
}, {
	icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
	-- the priest's amulets, by their tooltips: { text on the name or a line, the key it gives }
	gear = {
		{ "When Power Word: Shield breaks it explodes", "set/pwshield" },
		{ ": Power Word: Shield$", "item/pwshield" },
		{ "A broken shield bursts", "item/pwshield" },
		{ "die with Shadow Word: Pain on them explode", "item/swpain" },
		{ "Pendant of the Plague: Shadow Word: Pain", "item/swpain" },
		{ "die with Devouring Plague on them explode", "item/devouringplague" },
		{ "Pendant of the Plague: Devouring Plague", "item/devouringplague" },
	},
	-- damage over time an enemy can die with
	dots = {
		swp = { spells = { 589 }, names = { "shadowwordpain" }, keys = { "swpain" } },
		dp = { spells = { 2944 }, names = { "devouringplague" }, keys = { "devouringplague" } },
	},
	-- auras that show a talent
	auras = {
		{ key = "shadowform", textures = { "Shadowform" }, spells = { 15473, 16592 }, name = "Shadowform aura" },
	},
});
