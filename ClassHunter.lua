-- Hunter telegraphs. The fields are described at the top of Core.lua.

-- the Amulet of the Inferno on a spot spell: enemies it kills explode for 30% of their max health on
-- everything within 7 yd, at most 2 times a second
local function Inferno(key, name, spell)
	return {
		id = "inferno_" .. key, name = "Inferno: " .. name .. " kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on " .. name .. ", enemies " .. name .. " kills explode: where they do.",
		match = { "item/" .. key }, needName = "the Amulet of the Inferno (" .. name .. ")",
		by = { spells = { spell }, names = { key } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.6, 0.25, 1 }, fill = { 1, 0.45, 0.1, 0.25 } },
	};
end

AST_Register("hunter", {
	{
		-- "Lands on the thickest group of enemies within 28 yd: every enemy within 8 yd of that spot
		-- takes ... every 1 sec for 8.4 sec".
		id = "volley", name = "Volley", shape = "ground", spellKey = "volley",
		desc = "Where Volley lands: the arrows fill in from its centre until they stop.",
		on = { spells = { 1510 }, names = { "volley" } }, range = 28,
		tipNames = { "Volley" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/volley", durationItem = "item/volley",
		base = 8, duration = 8.4, every = 1, recDuration = 6,
		defaults = { mode = "duration", line = { 0.85, 0.6, 1, 1 }, fill = { 0.7, 0.45, 1, 0.25 } },
	},
	{
		-- "Marks the ground where you stand once enemies come within 7 yd: every enemy within 7 yd of
		-- that spot takes ... every 1.9 sec for 11 sec".
		id = "immolation_trap", name = "Immolation Trap", shape = "ground", spellKey = "immolation_trap", atFeet = true,
		desc = "Where Immolation Trap burns: the fire fills in from its centre until it goes out.",
		on = { spells = { 13797 }, names = { "immolationtrap" } }, range = 0,
		tipNames = { "Immolation Trap" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/immolationtrap", durationItem = "item/immolationtrap",
		base = 7, duration = 11, every = 1.9, recDuration = 8,
		defaults = { mode = "duration", line = { 1, 0.5, 0.15, 1 }, fill = { 1, 0.35, 0.05, 0.25 } },
	},
	{
		-- "Marks the ground where you stand once enemies come within 10 yd: every enemy within 10 yd
		-- of that spot takes ... every 2.1 sec for 8.4 sec".
		id = "frost_trap", name = "Frost Trap", shape = "ground", spellKey = "frost_trap", atFeet = true,
		desc = "Where Frost Trap freezes the ground: the ice fills in from its centre until it melts.",
		on = { spells = { 13810 }, names = { "frosttrap" } }, range = 0,
		tipNames = { "Frost Trap" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/frosttrap", durationItem = "item/frosttrap",
		base = 10, duration = 8.4, every = 2.1, recDuration = 6,
		defaults = { mode = "duration", line = { 0.55, 0.85, 1, 1 }, fill = { 0.45, 0.75, 1, 0.25 } },
	},
	{
		-- Wyvern Sting (Survival capstone): "an Immolation Trap sets itself at your feet every 5 sec";
		-- Counterattack: "When an enemy strikes you in melee, 15% (30%) chance" of a free Immolation
		-- Trap, your trap's upgrades too. Set as Immolation Trap is, where you stand; the spell list
		-- doesn't show them, so each one's first tick places it, a quarter second after it went down.
		id = "wyvern_sting", name = "Free Immolation Traps", shape = "ground", freeFall = "immolation_trap", atFeet = true,
		desc = "With Wyvern Sting or Counterattack, an Immolation Trap sets itself at your feet: where it burns (shown with its first tick).",
		on = { spells = { 13797 }, names = { "immolationtrap" } }, range = 0,
		tipNames = { "Immolation Trap" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/immolationtrap", durationItem = "item/immolationtrap",
		base = 7, duration = 11, every = 1.9, recDuration = 8,
		match = { "wyvernsting", "counterattack" }, talentKeys = { "wyvernsting", "counterattack" },
		needName = "the Wyvern Sting or Counterattack talent",
		defaults = { mode = "duration", line = { 1, 0.65, 0.3, 1 }, fill = { 1, 0.5, 0.15, 0.25 } },
	},
	{
		-- Hunter's Mark (an ability from the spell pool): "When it dies the mark explodes, dealing ...
		-- Arcane damage to every enemy within 8 yd, at most once every 2 sec": 8 yd x Area (and the
		-- Charm of the Fated Hour's "+N% area"), its hits Hunter's Mark's (1130). Flashed on the body
		-- its hits fit around. Known by the meter's ability list, or the first explosion seen.
		id = "hunters_mark", name = "Hunter's Mark", shape = "enemy", trigger = "burst", atKill = true, kind = "Spells",
		spellKey = "hunters_mark",
		match = { "huntersmark" }, talentKeys = { "huntersmark" }, needName = "the Hunter's Mark ability",
		desc = "With Hunter's Mark, the mark explodes when its enemy dies: where it does.",
		on = { spells = { 1130 }, names = { "huntersmark" } },
		tipNames = { "Hunter's Mark" }, sizePattern = "every enemy within ([%d%.]+) yd",
		base = 8, areaItem = "item/huntersmark",
		defaults = { mode = "event", flash = 0.5, line = { 0.75, 0.55, 1, 1 }, fill = { 0.6, 0.4, 1, 0.25 } },
	},
	{
		-- Explosive Ammunition (Survival milestone): "Enemies killed by your Auto Shot or Multi-Shot
		-- explode for 20% of their maximum health on everything within 6 yd."
		id = "explosive_ammo", name = "Explosive Ammunition", shape = "enemy", trigger = "kill", radius = 6,
		desc = "With Explosive Ammunition, enemies your Auto Shot or Multi-Shot kills explode: where they do.",
		match = { "explosiveammo", "explosiveammunition" }, talentKeys = { "explosiveammo", "explosiveammunition" },
		by = { spells = { 75, 2643 }, names = { "autoshot", "multishot" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.6, 0.25, 1 }, fill = { 1, 0.45, 0.1, 0.25 } },
	},
	{
		-- The Pendant of the Plague on Serpent Sting: enemies that die with it on them explode for 20%
		-- of their max health on everything within 7 yd, at most 2 a second.
		id = "hunter_pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Pendant of the Plague on Serpent Sting, enemies that die with your Serpent Sting on them explode: where they do.",
		match = { "item/serpentsting" }, needs = { ["item/serpentsting"] = "serpentsting" },
		needName = "the Pendant of the Plague (Serpent Sting)",
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	Inferno("volley", "Volley", 1510),
	Inferno("immolationtrap", "Immolation Trap", 13797),
	Inferno("frosttrap", "Frost Trap", 13810),
	{
		-- How far your shots reach for an enemy.
		id = "hunter_range", name = "Shot range", shape = "circle",
		desc = "How far your shots reach for an enemy.",
		tipNames = { "Auto Shot", "Arcane Shot", "Multi-Shot", "Aimed Shot" },
		sizePattern = "within ([%d%.]+) yd", base = 32, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.67, 0.83, 0.45, 0.6 }, fill = { 0.67, 0.83, 0.45, 0 } },
	},
}, {
	icon = "Interface\\Icons\\INV_Weapon_Bow_07",
	gear = {
		{ "Pendant of the Plague: Serpent Sting", "item/serpentsting" },
		{ "die with Serpent Sting on them explode", "item/serpentsting" },
		{ "Amulet of the Inferno: Volley", "item/volley" },
		{ "Enemies Volley kills explode", "item/volley" },
		{ "Amulet of the Inferno: Immolation Trap", "item/immolationtrap" },
		{ "Enemies Immolation Trap kills explode", "item/immolationtrap" },
		{ "Amulet of the Inferno: Frost Trap", "item/frosttrap" },
		{ "Enemies Frost Trap kills explode", "item/frosttrap" },
		{ "Charm of the Fated Hour: Hunter's Mark", "item/huntersmark" },
		{ "Hunter's Mark: %+[%d%.]+%% area", "item/huntersmark" },
		{ "^Volley: %+", "item/volley" },
		{ "^Immolation Trap: %+", "item/immolationtrap" },
		{ "^Frost Trap: %+", "item/frosttrap" },
	},
	dots = {
		serpentsting = { spells = { 1978 }, names = { "serpentsting" }, keys = { "serpentsting" } },
	},
});
