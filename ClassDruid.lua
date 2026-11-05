-- Druid telegraphs. The fields are described at the top of Core.lua.

AST_Register("druid", {
	{
		id = "swipe", name = "Swipe", shape = "circle", spellKey = "swipe",
		desc = "The area around you that Swipe hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Swipe" }, sizePattern = "within ([%d%.]+) yd of you",
		base = 7,
		defaults = { mode = "cast", line = { 1, 0.6, 0.2, 1 }, fill = { 1, 0.49, 0.04, 0.3 } },
	},
	{
		-- "Lands on the thickest group of enemies within 28 yd: every enemy within 10 yd of that spot
		-- takes ... every 1 sec for 11 sec".
		id = "hurricane", name = "Hurricane", shape = "ground", spellKey = "hurricane",
		desc = "Where Hurricane lands: the storm fills in from its centre until it dies down.",
		on = { spells = { 16914 }, names = { "hurricane" } }, range = 28,
		tipNames = { "Hurricane" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		-- 10 yd x Area x (1 + 10% per Gale Winds rank)
		areaItem = "item/hurricane", durationItem = "item/hurricane",
		base = 10, reachTalent = "gale_winds", reachPerRank = 0.10, duration = 11, every = 1, recDuration = 8,
		defaults = { mode = "duration", line = { 0.55, 0.95, 0.6, 1 }, fill = { 0.4, 0.85, 0.45, 0.25 } },
	},
	{
		-- Tranquility (Restoration milestone): "Every heal you cast also strikes every enemy within
		-- 12 yd for 300% of the healing as Nature damage." Flashed when its damage lands.
		id = "tranquility", name = "Tranquility", shape = "circle", radius = 12,
		desc = "With Tranquility, every heal you cast also strikes the enemies around you: this flashes when it does.",
		match = { "tranquility" }, talentKeys = { "tranquility" },
		needName = "the Tranquility talent",
		free = { names = { "tranquility" } },
		modes = { "proc" },
		defaults = { mode = "proc", line = { 0.55, 1, 0.55, 1 }, fill = { 0.4, 0.9, 0.4, 0.25 } },
	},
	{
		-- Dire Bear Form (Feral capstone): "A free Swipe tears around you every 3 sec".
		id = "dire_bear", name = "Dire Bear Swipe", shape = "circle", sizeOf = "swipe",
		desc = "In Dire Bear Form, a free Swipe tears around you every 3 sec: this flashes with each one.",
		match = { "leaderofpack", "direbearform" }, talentKeys = { "leaderofpack", "direbearform" },
		needName = "the Dire Bear Form talent",
		clock = { names = { "Dire Bear Form" }, every = 3 },
		free = { spells = { 779 }, names = { "swipe" }, ownSpell = "swipe" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "proc", line = { 0.85, 0.55, 0.3, 1 }, fill = { 0.75, 0.45, 0.2, 0.25 } },
	},
	{
		-- Enrage: "When an enemy strikes you in melee, 10% (up to 50%) chance to answer with a free
		-- Swipe".
		id = "enrage", name = "Enrage", shape = "circle", sizeOf = "swipe",
		desc = "With Enrage, an enemy striking you can set off a free Swipe: this flashes when it does.",
		match = { "brutalimpact", "enrage" }, talentKeys = { "brutalimpact", "enrage" },
		needName = "the Enrage talent",
		free = { spells = { 779 }, names = { "swipe" }, ownSpell = "swipe" },
		modes = { "proc" },
		defaults = { mode = "proc", line = { 1, 0.4, 0.3, 1 }, fill = { 0.95, 0.3, 0.2, 0.3 } },
	},
	{
		-- The Pendant of the Plague on Moonfire or Insect Swarm: enemies that die with it on them
		-- explode for 20% of their max health on everything within 7 yd, at most 2 a second.
		id = "druid_pendant", name = "Pendant of the Plague", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Pendant of the Plague on Moonfire or Insect Swarm, enemies that die with it on them explode: where they do.",
		match = { "item/moonfire", "item/insectswarm" },
		needs = { ["item/moonfire"] = "moonfire", ["item/insectswarm"] = "insectswarm" },
		needName = "the Pendant of the Plague (on Moonfire or Insect Swarm)",
		defaults = { mode = "event", flash = 0.5, line = { 0.55, 1, 0.35, 1 }, fill = { 0.4, 0.9, 0.2, 0.25 } },
	},
	{
		-- The Amulet of the Inferno on Hurricane: enemies it kills explode for 30% of their max health
		-- on everything within 7 yd, at most 2 times a second.
		id = "inferno_hurricane", name = "Inferno: Hurricane kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on Hurricane, enemies Hurricane kills explode: where they do.",
		match = { "item/hurricane" }, needName = "the Amulet of the Inferno (Hurricane)",
		by = { spells = { 16914 }, names = { "hurricane" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.6, 0.25, 1 }, fill = { 1, 0.45, 0.1, 0.25 } },
	},
	{
		-- The Epic armor set's 8 pieces (each at 3 stars or more): "Starfire bursts on every enemy
		-- within 6 yards of its target". Known from its first burst; then around each Starfire's
		-- target, free ones too.
		id = "set_starfire", name = "Epic set: Starfire bursts", shape = "enemy", trigger = "hit", radius = 6,
		kind = "Sets",
		desc = "With all 8 pieces of the Epic druid armor set at 3 stars or more, every Starfire bursts on the enemies around its target: the area it hits.",
		match = { "set/epic/druid" }, talentKeys = { "set/epic/druid" },
		needName = "the Epic druid set's 8 pieces at 3 stars or more",
		on = { spells = { 2912 }, names = { "starfire" } },
		defaults = { mode = "event", flash = 0.4, line = { 0.85, 0.65, 1, 1 }, fill = { 0.7, 0.5, 1, 0.25 } },
	},
	{
		-- How far your targeted spells reach for an enemy.
		id = "druid_range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Wrath", "Moonfire", "Starfire", "Insect Swarm", "Entangling Roots" },
		sizePattern = "within ([%d%.]+) yd", base = 30, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 1, 0.49, 0.04, 0.6 }, fill = { 1, 0.49, 0.04, 0 } },
	},
}, {
	icon = "Interface\\Icons\\Ability_Druid_Maul",
	gear = {
		{ "Pendant of the Plague: Moonfire", "item/moonfire" },
		{ "die with Moonfire on them explode", "item/moonfire" },
		{ "Pendant of the Plague: Insect Swarm", "item/insectswarm" },
		{ "die with Insect Swarm on them explode", "item/insectswarm" },
		{ "Amulet of the Inferno: Hurricane", "item/hurricane" },
		{ "Enemies Hurricane kills explode", "item/hurricane" },
		{ "^Hurricane: %+", "item/hurricane" },
	},
	-- damage over time an enemy can carry or die with
	dots = {
		moonfire = { spells = { 8921 }, names = { "moonfire" }, keys = { "moonfire" } },
		insectswarm = { spells = { 5570 }, names = { "insectswarm" }, keys = { "insectswarm" } },
	},
});
