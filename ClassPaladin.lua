-- Paladin telegraphs. The fields are described at the top of Core.lua.

AST_Register("paladin", {
	{
		id = "holy_wrath", name = "Holy Wrath", shape = "circle", spellKey = "holy_wrath",
		desc = "The area around you that Holy Wrath hits.",
		modes = { "cast", "cooldown" },
		tipNames = { "Holy Wrath" }, sizePattern = "within ([%d%.]+) yd of you",
		-- 12 yd x Area x (1 + 8% per Purifying Power rank)
		base = 12, reachTalent = "purifying_power", reachPerRank = 0.08,
		defaults = { mode = "cast", line = { 1, 0.85, 0.4, 1 }, fill = { 1, 0.8, 0.3, 0.3 } },
	},
	{
		-- "Marks the ground where you stand once enemies come within 8 yd: every enemy within 8 yd of
		-- that spot takes ... every 1 sec for 11 sec".
		id = "consecration", name = "Consecration", shape = "ground", spellKey = "consecration", atFeet = true,
		desc = "Where Consecration hallows the ground: the light fills in from its centre until it fades.",
		on = { spells = { 26573 }, names = { "consecration" } }, range = 0,
		tipNames = { "Consecration" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/consecration", durationItem = "item/consecration",
		base = 8, reachTalent = "purifying_power", reachPerRank = 0.08, duration = 11, every = 1, recDuration = 8,
		defaults = { mode = "duration", line = { 1, 0.9, 0.5, 1 }, fill = { 1, 0.85, 0.4, 0.25 } },
	},
	{
		-- Hallowed Ground (Protection milestone): "Every Hammer of Justice that lands hallows the
		-- ground beneath you: a free Consecration, at most once every 4 sec." Divine Intervention's
		-- death save brings one too. Cast as Consecration is, where you stand; the spell list doesn't
		-- show it, so its first tick places it, a quarter second after it fell.
		id = "free_consecration", name = "Free Consecration", shape = "ground", freeFall = "consecration", atFeet = true,
		desc = "With Hallowed Ground or Divine Intervention, a free Consecration hallows the ground beneath you: where it burns (shown with its first tick).",
		on = { spells = { 26573 }, names = { "consecration" } }, range = 0,
		tipNames = { "Consecration" }, sizePattern = "within ([%d%.]+) yd of that spot", durationPattern = "of that spot.-for ([%d%.]+) sec",
		areaItem = "item/consecration", durationItem = "item/consecration",
		base = 8, reachTalent = "purifying_power", reachPerRank = 0.08, duration = 11, every = 1, recDuration = 8,
		match = { "hallowedground", "divineintervention" }, talentKeys = { "hallowedground", "divineintervention" },
		needName = "the Hallowed Ground or Divine Intervention talent",
		defaults = { mode = "duration", line = { 1, 0.95, 0.65, 1 }, fill = { 1, 0.9, 0.55, 0.25 } },
	},
	{
		-- Redemption (an ability from the spell pool): "Enemies you slay have a 10% chance to burst
		-- in holy light, dealing ... Holy damage to every enemy within 8 yd of the body. ... At most
		-- two bursts a second": 8 yd x Area (and the Charm of the Fated Hour's "+N% area"), its hits
		-- Redemption's (7328). Flashed on the body its hits fit around. Known by the meter's ability
		-- list, or the first burst seen.
		id = "redemption", name = "Redemption", shape = "enemy", trigger = "burst", atKill = true, kind = "Spells",
		tipNames = { "Redemption" }, sizePattern = "within ([%d%.]+) yd of the body",
		base = 8, areaItem = "item/redemption",
		match = { "redemption" }, talentKeys = { "redemption" }, needName = "the Redemption ability",
		desc = "With Redemption, enemies you slay can burst in holy light: where a burst goes off.",
		on = { spells = { 7328 }, names = { "redemption" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.95, 0.6, 1 }, fill = { 1, 0.9, 0.5, 0.25 } },
	},
	{
		-- Light's Grace (Holy capstone): "A Holy Wrath bursts from you on its own every 14 sec."
		id = "lights_grace", name = "Light's Grace", shape = "circle", sizeOf = "holy_wrath",
		desc = "With Light's Grace, a free Holy Wrath bursts from you every 14 sec: the ring fills toward the next one.",
		match = { "lightsgrace" }, talentKeys = { "lightsgrace" },
		needName = "the Light's Grace talent",
		clock = { names = { "Light's Grace" }, every = 14 },
		free = { spells = { 2812 }, names = { "holywrath" }, ownSpell = "holy_wrath", unless = "daybreak" },
		modes = { "proc", "cooldown" },
		defaults = { mode = "cooldown", line = { 1, 0.95, 0.55, 1 }, fill = { 1, 0.9, 0.45, 0.18 } },
	},
	{
		-- Daybreak (Holy milestone): "Holy Shock's critical strikes call down a free Holy Wrath
		-- around you, at most once every 3 sec."
		id = "daybreak", name = "Daybreak", shape = "circle", sizeOf = "holy_wrath",
		desc = "With Daybreak, a Holy Shock crit calls down a free Holy Wrath around you: this flashes when it does.",
		match = { "daybreak" }, talentKeys = { "daybreak" },
		needName = "the Daybreak talent (spotted at its first free Holy Wrath after a Holy Shock crit)",
		procOn = { spells = { 25912 }, names = { "holyshock" }, crit = true, gap = 3 },
		spot = { spells = { 2812 }, names = { "holywrath" }, ownSpell = "holy_wrath", window = 0.6 },
		defaults = { mode = "proc", line = { 1, 1, 0.75, 1 }, fill = { 1, 0.95, 0.6, 0.3 } },
	},
	{
		-- Divine Storm (Retribution capstone): "every Exorcism bursts on its target, striking every
		-- enemy within 5 yd".
		id = "divine_storm", name = "Divine Storm", shape = "enemy", trigger = "hit", radius = 5,
		desc = "With Divine Storm, every Exorcism bursts on its target: the area it strikes.",
		match = { "divinestorm" }, talentKeys = { "divinestorm" },
		on = { spells = { 879 }, names = { "exorcism" } },
		defaults = { mode = "event", flash = 0.4, line = { 1, 0.8, 0.45, 1 }, fill = { 1, 0.7, 0.3, 0.25 } },
	},
	{
		-- The Amulet of the Inferno on Consecration: enemies it kills explode for 30% of their max
		-- health on everything within 7 yd, at most 2 times a second.
		id = "inferno_consecration", name = "Inferno: Consecration kills", shape = "enemy", trigger = "kill", cap = 2, radius = 7,
		desc = "With the Amulet of the Inferno on Consecration, enemies Consecration kills explode: where they do.",
		match = { "item/consecration" }, needName = "the Amulet of the Inferno (Consecration)",
		by = { spells = { 26573 }, names = { "consecration" } },
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.75, 0.35, 1 }, fill = { 1, 0.65, 0.2, 0.25 } },
	},
	{
		-- The Epic armor set's 8 pieces (each at 3 stars or more): "Enemies killed by Judgement
		-- explode for 15% of their max health on everything within 8 yards." Flashed on the body as
		-- the explosion's own hits land.
		id = "set_judgement", name = "Epic set: Judgement kills", shape = "enemy", trigger = "burst", atKill = true,
		kind = "Sets", radius = 8,
		desc = "With all 8 pieces of the Epic paladin armor set at 3 stars or more, enemies Judgement kills explode: where they do.",
		on = { source = "^set:paladin%.3" }, by = { spells = { 20271 } },
		match = { "set/epic/paladin/5", "set/epic/paladin" }, talentKeys = { "set/epic/paladin/5", "set/epic/paladin" }, showsItself = true,
		needName = "the Epic paladin set's 8 pieces at 3 stars or more",
		defaults = { mode = "event", flash = 0.5, line = { 1, 0.85, 0.4, 1 }, fill = { 1, 0.75, 0.25, 0.25 } },
	},
	{
		-- The T0.5 armor set's 8 pieces: "Hammer of Justice ... explodes for 40% of your remaining
		-- shield absorption within 10 yd of its target." Known from its first explosion; then around
		-- each Hammer of Justice's target.
		id = "set_hammer", name = "T0.5 set: Hammer of Justice", shape = "enemy", trigger = "hit", radius = 10,
		kind = "Sets",
		desc = "With all 8 pieces of the T0.5 paladin armor set, Hammer of Justice explodes around its target: the area it hits.",
		match = { "set/t05/paladin" }, talentKeys = { "set/t05/paladin" },
		needName = "the T0.5 paladin set's 8 pieces (known from its first explosion)",
		on = { spells = { 853 }, names = { "hammerofjustice" } },
		defaults = { mode = "event", flash = 0.45, line = { 1, 0.9, 0.55, 1 }, fill = { 1, 0.85, 0.45, 0.2 } },
	},
	{
		-- How far your targeted spells reach for an enemy.
		id = "paladin_range", name = "Spell range", shape = "circle",
		desc = "How far your targeted spells reach for an enemy.",
		tipNames = { "Exorcism", "Hammer of Wrath", "Holy Shock", "Judgement" },
		sizePattern = "within ([%d%.]+) yd", base = 25, unscaled = true,
		defaults = { enabled = false, mode = "always", line = { 0.96, 0.55, 0.73, 0.6 }, fill = { 0.96, 0.55, 0.73, 0 } },
	},
}, {
	icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
	gear = {
		{ "Amulet of the Inferno: Consecration", "item/consecration" },
		{ "Enemies Consecration kills explode", "item/consecration" },
		{ "Charm of the Fated Hour: Redemption", "item/redemption" },
		{ "Redemption: %+[%d%.]+%% area", "item/redemption" },
		{ "^Consecration: %+", "item/consecration" },
	},
});
