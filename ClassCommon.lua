-- Telegraphs every class can use: amulets any hero can find, the racials that hit around you,
-- co-op revives, and a ring of your own. The fields are described at the top of Core.lua.

AST_Register("common", {
	{
		-- "Enemies you kill explode for 15% of their max health, at most 4 times a second", 6 yd
		id = "choker", name = "Choker of the Fire Lord", shape = "enemy", trigger = "kill", cap = 4,
		desc = "While you wear it, enemies you kill explode: where they do.",
		match = { "chokerofthefirelord", "firelord" }, radius = 6,
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.45, 0.2, 1 }, fill = { 1, 0.35, 0.1, 0.25 } },
	},
	{
		-- "Your critical hits splash 30% on enemies within 5 yd, at most 6 times a second"
		id = "onyxia", name = "Onyxia Tooth Pendant", shape = "enemy", trigger = "crit", cap = 6,
		desc = "While you wear it, your critical hits splash onto enemies nearby: where they land.",
		match = { "onyxiatoothpendant", "onyxiatooth" }, radius = 5,
		defaults = { mode = "event", flash = 0.4, line = { 0.6, 0.9, 1, 1 }, fill = { 0.5, 0.8, 1, 0.2 } },
	},
	{
		-- War Stomp (Tauren): goes off on its own from the racial slot, hitting every enemy within
		-- 8 yd of you (times your Area) and stunning them for 2 sec. The spell bar lists it with its
		-- cooldown, like your spells, so only a Tauren sees it.
		id = "war_stomp", name = "War Stomp", shape = "circle", spellKey = "war_stomp", kind = "Racial",
		desc = "Tauren: the area around you that War Stomp hits and stuns.",
		modes = { "cast", "cooldown" },
		tipNames = { "War Stomp" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 8,
		defaults = { mode = "cast", line = { 0.95, 0.7, 0.35, 1 }, fill = { 0.85, 0.55, 0.25, 0.3 } },
	},
	{
		-- Escape Artist (Gnome): the same from the racial slot, rooting every enemy within 8 yd of
		-- you (times your Area) for 2 sec.
		id = "escape_artist", name = "Escape Artist", shape = "circle", spellKey = "escape_artist", kind = "Racial",
		desc = "Gnome: the area around you that Escape Artist hits and roots.",
		modes = { "cast", "cooldown" },
		tipNames = { "Escape Artist" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 8,
		defaults = { mode = "cast", line = { 0.45, 0.9, 0.75, 1 }, fill = { 0.35, 0.8, 0.65, 0.3 } },
	},
	{
		-- A downed teammate in co-op: stand within 5 yd of them to bring them back (6 sec, 9 at
		-- Heroic 5 and up; each extra friend standing there makes it 20% faster). The ring fills
		-- with your revive's progress.
		id = "revive", name = "Revive range", shape = "downed", radius = 5, sizeLabel = "revive range",
		desc = "In co-op, where to stand to bring a downed teammate back. It fills as you revive them.",
		defaults = { mode = "always", line = { 0.4, 1, 0.5, 1 }, fill = { 0.3, 1, 0.4, 0.2 } },
	},
	{
		id = "ring", name = "Custom ring", shape = "circle",
		desc = "A ring of any size around you, for whatever you want to keep an eye on.",
		defaults = { enabled = false, mode = "always", radius = 8, line = { 1, 0.25, 0.25, 1 }, fill = { 1, 0.25, 0.25, 0 } },
	},
}, {
	blurb = "Amulets any hero can find, the racials that hit around you, co-op revives and a ring of your own.",
	gear = {
		{ "Enemies you kill explode", "chokerofthefirelord" },
		{ "Choker of the Fire Lord", "chokerofthefirelord" },
		{ "critical hits splash", "onyxiatoothpendant" },
		{ "Onyxia Tooth Pendant", "onyxiatoothpendant" },
	},
});
