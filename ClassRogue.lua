-- Rogue telegraphs. The fields are described at the top of Core.lua.

-- The Reaper's Amulet on a strike: "<strike>'s hits splash 50% on enemies within 6 yd".
local function Reaper(key, name, spell)
	return {
		id = "reaper_" .. key, name = "Reaper's Amulet: " .. name, shape = "enemy", trigger = "hit", radius = 6,
		desc = "With The Reaper's Amulet on " .. name .. ", each " .. name .. " hit splashes onto the enemies around its target: the area it splashes.",
		match = { "item/" .. key }, needName = "The Reaper's Amulet (" .. name .. ")",
		on = { spells = { spell }, names = { key } },
		defaults = { mode = "event", flash = 0.4, line = { 0.85, 0.3, 0.3, 1 }, fill = { 0.75, 0.2, 0.2, 0.2 } },
	};
end

AST_Register("rogue", {
	{
		id = "blade_flurry", name = "Blade Flurry", shape = "circle", spellKey = "blade_flurry",
		desc = "The area around you that Blade Flurry hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Blade Flurry" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 7,
		defaults = { mode = "cast", line = { 1, 0.95, 0.45, 1 }, fill = { 1, 0.9, 0.3, 0.3 } },
	},
	{
		-- Preparation (Subtlety milestone): "A free Gouge stuns the enemies around you every 6 sec."
		-- Gouge strikes up to 3 enemies within its reach (8 yd); its free goes are Gouge's (1776).
		id = "preparation", name = "Preparation", shape = "circle",
		desc = "With Preparation, a free Gouge stuns up to 3 enemies around you every 6 sec: the ring fills toward the next one.",
		tipNames = { "Gouge" }, sizePattern = "enemies within ([%d%.]+) yd", base = 8, unscaled = true,
		match = { "preparation" }, talentKeys = { "preparation" },
		needName = "the Preparation talent",
		clock = { names = { "Preparation" }, every = 6 },
		free = { spells = { 1776 }, names = { "gouge" }, ownSpell = "gouge" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "cooldown", line = { 0.95, 0.85, 0.5, 1 }, fill = { 0.9, 0.75, 0.35, 0.18 } },
	},
	{
		-- Shadow Dance (Subtlety capstone): "Backstab and Eviscerate splash 20% of their damage onto
		-- every enemy within 5 yd of their target."
		id = "shadow_dance", name = "Shadow Dance", shape = "enemy", trigger = "hit", radius = 5,
		desc = "With Shadow Dance, Backstab and Eviscerate splash onto the enemies around their target: the area they splash.",
		match = { "shadowdance" }, talentKeys = { "shadowdance" },
		on = { spells = { 53, 2098 }, names = { "backstab", "eviscerate" } },
		defaults = { mode = "event", flash = 0.4, line = { 0.75, 0.55, 1, 1 }, fill = { 0.6, 0.4, 0.95, 0.2 } },
	},
	{
		-- Toxic Bloom (Assassination capstone): "Enemies that die poisoned or bleeding burst in a
		-- toxic cloud for 15% of their maximum health on everything within 7 yd." Rupture's bleed
		-- is the one the combat text names.
		id = "toxic_bloom", name = "Toxic Bloom", shape = "enemy", trigger = "kill", radius = 7,
		desc = "With Toxic Bloom, enemies that die bleeding from your Rupture burst in a toxic cloud: where they do.",
		match = { "toxicbloom" }, talentKeys = { "toxicbloom" }, needs = { toxicbloom = "rupture" },
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- The Pendant of the Plague on Rupture: enemies that die with it on them explode for 20% of
		-- their max health on everything within 7 yd, at most 2 a second.
		id = "rogue_pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Pendant of the Plague on Rupture, enemies that die with your Rupture on them explode: where they do.",
		match = { "item/rupture" }, needs = { ["item/rupture"] = "rupture" },
		needName = "the Pendant of the Plague (Rupture)",
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.35, 0.35, 1 }, fill = { 0.9, 0.2, 0.2, 0.25 } },
	},
	{
		-- The Uncommon armor set's 8 pieces (each at 3 stars or more): "Enemies dying with your
		-- Rupture burst for 15% of their max health on everything within 8 yards." Flashed on the
		-- body as the burst's own hits land.
		id = "set_rupture", name = "Uncommon set: Rupture bursts", shape = "enemy", trigger = "burst", atKill = true,
		kind = "Sets", radius = 8,
		desc = "With all 8 pieces of the Uncommon rogue armor set at 3 stars or more, enemies dying with your Rupture on them burst: where they do.",
		on = { source = "^set:rogue%.1" },
		needs = { ["set/uncommon/rogue/5"] = "rupture", ["set/uncommon/rogue"] = "rupture" },
		match = { "set/uncommon/rogue/5", "set/uncommon/rogue" }, talentKeys = { "set/uncommon/rogue/5", "set/uncommon/rogue" }, showsItself = true,
		needName = "the Uncommon rogue set's 8 pieces at 3 stars or more",
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.45, 0.4, 1 }, fill = { 0.9, 0.3, 0.25, 0.25 } },
	},
	Reaper("eviscerate", "Eviscerate", 2098),
	Reaper("backstab", "Backstab", 53),
	{
		-- How far your strikes reach for an enemy.
		id = "rogue_range", name = "Strike reach", shape = "circle",
		desc = "How far your strikes reach for an enemy.",
		tipNames = { "Sinister Strike", "Backstab", "Eviscerate", "Kidney Shot" },
		sizePattern = "within ([%d%.]+) yd", base = 8, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 1, 0.96, 0.41, 0.6 }, fill = { 1, 0.96, 0.41, 0 } },
	},
}, {
	icon = "Interface\\Icons\\INV_ThrowingKnife_04",
	gear = {
		{ "Pendant of the Plague: Rupture", "item/rupture" },
		{ "die with Rupture on them explode", "item/rupture" },
		{ "The Reaper's Amulet: Eviscerate", "item/eviscerate" },
		{ "Eviscerate's hits splash", "item/eviscerate" },
		{ "The Reaper's Amulet: Backstab", "item/backstab" },
		{ "Backstab's hits splash", "item/backstab" },
	},
	-- damage over time an enemy can die with: Rupture's bleed
	dots = {
		rupture = { spells = { 1943 }, names = { "rupture" }, keys = { "rupture" } },
	},
});
