-- Warrior telegraphs. The fields are described at the top of Core.lua.

AST_Register("warrior", {
	{
		id = "whirlwind", name = "Whirlwind", shape = "circle", spellKey = "whirlwind",
		desc = "The area around you that Whirlwind hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Whirlwind" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 8 yd x Area x (1 + 6% per Improved Whirlwind rank)
		base = 8, reachTalent = "imp_whirlwind", reachPerRank = 0.06,
		defaults = { mode = "cast", line = { 0.9, 0.85, 0.75, 1 }, fill = { 0.8, 0.7, 0.55, 0.3 } },
	},
	{
		id = "thunder_clap", name = "Thunder Clap", shape = "circle", spellKey = "thunder_clap",
		desc = "The area around you that Thunder Clap hits and slows.",
		modes = { "cast", "cooldown" },
		tipNames = { "Thunder Clap" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 10,
		defaults = { mode = "cast", line = { 0.6, 0.8, 1, 1 }, fill = { 0.45, 0.65, 1, 0.3 } },
	},
	{
		id = "demo_shout", name = "Demoralizing Shout", shape = "circle", spellKey = "demo_shout",
		desc = "The area around you that Demoralizing Shout reaches.",
		modes = { "cast", "cooldown" },
		tipNames = { "Demoralizing Shout" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 14 yd x Area x (1 + 10% per Booming Voice rank)
		base = 14, reachTalent = "booming_voice", reachPerRank = 0.10,
		defaults = { mode = "cast", line = { 1, 0.6, 0.3, 1 }, fill = { 1, 0.5, 0.2, 0.2 } },
	},
	{
		-- "Strikes up to 3 enemies within 7 yd for ... each."
		id = "cleave", name = "Cleave", shape = "circle", spellKey = "cleave",
		desc = "How far Cleave reaches: up to 3 enemies within it are struck.",
		modes = { "cast", "cooldown" },
		tipNames = { "Cleave" }, sizePattern = "enemies within ([%d%.]+) yd",
		base = 7, unscaled = true,
		defaults = { mode = "cast", line = { 1, 0.8, 0.5, 1 }, fill = { 1, 0.7, 0.35, 0.2 } },
	},
	{
		-- Bloodrage (an ability from the spell pool): "At 100 rage you erupt, dealing ... Physical
		-- damage to every enemy within 9 yd, at most once every 10 sec": 9 yd x Area (and the Charm
		-- of the Fated Hour's "+N% area"), its hits Bloodrage's (2687). Known by the meter's ability
		-- list, or the first eruption seen.
		id = "rage_eruption", name = "Bloodrage", shape = "circle", kind = "Spells",
		desc = "With Bloodrage, at 100 rage you erupt, hitting every enemy around you: this flashes when you do.",
		tipNames = { "Bloodrage" }, sizePattern = "every enemy within ([%d%.]+) yd",
		base = 9, areaItem = "item/bloodrage",
		match = { "bloodrage" }, talentKeys = { "bloodrage" }, needName = "the Bloodrage ability",
		free = { spells = { 2687 }, names = { "bloodrage" } },
		modes = { "proc" },
		defaults = { mode = "proc", line = { 1, 0.3, 0.2, 1 }, fill = { 1, 0.2, 0.1, 0.3 } },
	},
	{
		-- Rampage (Fury milestone): "Every 7th kill unleashes a free Whirlwind."
		id = "rampage", name = "Rampage", shape = "circle", sizeOf = "whirlwind",
		desc = "With Rampage, every 7th kill unleashes a free Whirlwind: this flashes when it does.",
		match = { "rampage" }, talentKeys = { "rampage" },
		needName = "the Rampage talent",
		free = { spells = { 1680 }, names = { "whirlwind" }, ownSpell = "whirlwind" },
		modes = { "proc" },
		defaults = { mode = "proc", line = { 1, 0.45, 0.35, 1 }, fill = { 0.95, 0.35, 0.25, 0.3 } },
	},
	{
		-- Bladestorm (Fury capstone): "you never stop spinning: a free Whirlwind every 3 sec".
		id = "bladestorm", name = "Bladestorm", shape = "circle", sizeOf = "whirlwind",
		desc = "With Bladestorm, a free Whirlwind spins out of you every 3 sec: this flashes with each one.",
		match = { "bladestorm" }, talentKeys = { "bladestorm" },
		needName = "the Bladestorm talent",
		clock = { names = { "Bladestorm" }, every = 3 },
		free = { spells = { 1680 }, names = { "whirlwind" }, ownSpell = "whirlwind" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "proc", line = { 0.95, 0.9, 0.8, 1 }, fill = { 0.85, 0.8, 0.65, 0.25 } },
	},
	{
		-- Shockwave (Protection milestone): "Each Shield Slam sends a shockwave from its first
		-- target: every enemy within 8 yd of it is struck ... and stunned."
		id = "shockwave", name = "Shockwave", shape = "enemy", trigger = "hit", radius = 8, cap = 1,
		desc = "With Shockwave, each Shield Slam sends a shockwave out of its first target: the area it strikes.",
		match = { "shockwave" }, talentKeys = { "shockwave" },
		on = { spells = { 23922 }, names = { "shieldslam" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.85, 0.4, 1 }, fill = { 1, 0.75, 0.25, 0.25 } },
	},
	{
		-- The Pendant of the Plague on Rend: enemies that die with it on them explode for 20% of their
		-- max health on everything within 7 yd, at most 2 a second.
		id = "warrior_pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Pendant of the Plague on Rend, enemies that die with your Rend on them explode: where they do.",
		match = { "item/rend" }, needs = { ["item/rend"] = "rend" },
		needName = "the Pendant of the Plague (Rend)",
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- The Reaper's Amulet on Execute: "Execute's hits splash 50% on enemies within 6 yd".
		id = "reaper_execute", name = "Reaper's Amulet: Execute", shape = "enemy", trigger = "hit", radius = 6,
		desc = "With The Reaper's Amulet on Execute, each Execute hit splashes onto the enemies around its target: the area it splashes.",
		match = { "item/execute" }, needName = "The Reaper's Amulet (Execute)",
		on = { spells = { 5308 }, names = { "execute" } },
		defaults = { mode = "event", flash = 0.4, line = { 0.85, 0.3, 0.3, 1 }, fill = { 0.75, 0.2, 0.2, 0.2 } },
	},
	{
		-- How far your single-target strikes reach for an enemy.
		id = "warrior_range", name = "Strike reach", shape = "circle",
		desc = "How far your strikes reach for an enemy.",
		tipNames = { "Mortal Strike", "Bloodthirst", "Shield Slam", "Execute" },
		sizePattern = "within ([%d%.]+) yd", base = 7, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.85, 0.75, 0.6, 0.6 }, fill = { 0.85, 0.75, 0.6, 0 } },
	},
}, {
	icon = "Interface\\Icons\\INV_Sword_27",
	gear = {
		{ "Pendant of the Plague: Rend", "item/rend" },
		{ "die with Rend on them explode", "item/rend" },
		{ "The Reaper's Amulet: Execute", "item/execute" },
		{ "Execute's hits splash", "item/execute" },
		{ "Charm of the Fated Hour: Bloodrage", "item/bloodrage" },
		{ "Bloodrage: %+[%d%.]+%% area", "item/bloodrage" },
	},
	dots = {
		rend = { spells = { 772 }, names = { "rend" }, keys = { "rend" } },
	},
});
