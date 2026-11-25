-- Azeroth Survivors Telegraphs: a telegraph for every skill that had none of its own, each off to
-- start with. Under "Ranges" on its class's page:
--   * how far a skill reaches for an enemy (its tooltip's "within N yd": a reach, which Area
--     doesn't widen), its cooldown filling it;
--   * how near enemies must come before a self-buff goes off ("Cast once enemies are within N yd");
--   * a ring round you as a heal or a shield with no reach goes off.
-- Under "Spells": where Searing Totem and a Lightwell can strike, round where they stand.
-- The fields are described at the top of Core.lua. `of` names the skill a ring is of, and
-- `ofFmt` / `descFmt` put that name in its name and line, so both can be put in the game's
-- language (Options.lua). `unlisted`: a skill the spell list may not show (Seal Fate's free
-- Eviscerates, Soulfire's, Faerie Fire's mark): known from the meter's ability list too, and then
-- drawn as a plain ring.

-- Each school's colour.
local SCHOOL = {
	physical = { 0.85, 0.75, 0.6 }, holy = { 1, 0.85, 0.35 }, arcane = { 0.9, 0.55, 1 }, nature = { 0.45, 0.9, 0.4 },
	fire = { 1, 0.5, 0.2 }, frost = { 0.5, 0.85, 1 }, shadow = { 0.7, 0.45, 1 },
};

local function Look(school, mode, line, fill)
	local c = SCHOOL[school];
	return { enabled = false, mode = mode, line = { c[1], c[2], c[3], line }, fill = { c[1], c[2], c[3], fill } };
end

-- A ring of `name` (a skill's own, by its key), named and described by the two formats.
local function Ring(key, suffix, name, ofFmt, descFmt, school, mode, line, fill)
	local def = {
		id = key .. suffix, name = string.format(ofFmt, name), of = name, ofFmt = ofFmt,
		desc = string.format(descFmt, name), descFmt = descFmt, kind = "Ranges", shape = "circle",
		spellKey = key, modes = { "cast", "cooldown" }, defaults = Look(school, mode, line, fill),
		-- its school, for the Lab's school themes (false: a reach, left as it is)
		school = suffix == "_cast" and school or false,
	};
	return def;
end

-- How far a targeted skill reaches for an enemy. `listedAs`: the meter's key for a skill the
-- spell list may not show.
local function Reach(key, name, base, school, listedAs)
	local def = Ring(key, "_reach", name, "%s range", "How far %s reaches for an enemy.", school, "cooldown", 0.45, 0.05);
	def.tipNames, def.sizePattern, def.base, def.unscaled = { name }, "within ([%d%.]+) yd", base, true;
	if ( listedAs ) then
		def.match, def.talentKeys, def.unlisted = { listedAs }, { listedAs }, true;
		def.needName = "the " .. name .. " ability";
	end
	return def;
end

-- How near enemies must come before a self-buff goes off: its tooltip says so in fixed words ("Cast
-- once enemies are within 30 yd."), not a number that changes, so a fixed size.
local function Trigger(key, name, base, school)
	local def = Ring(key, "_trigger", name, "%s trigger", "Enemies this near set off %s.", school, "cooldown", 0.35, 0.03);
	def.radius, def.sizeLabel = base, "fixed";
	return def;
end

-- A heal or a shield with no reach: a ring round you as it goes off.
local function Flash(key, name, school)
	local def = Ring(key, "_cast", name, "%s", "Flashes round you when %s goes off.", school, "cast", 0.8, 0.15);
	def.radius, def.sizeLabel = 3, "fixed";
	return def;
end

AST_Register("warrior", {
	Reach("mortal_strike", "Mortal Strike", 7, "physical"),
	Reach("execute", "Execute", 10, "physical"),
	Reach("bloodthirst", "Bloodthirst", 7, "physical"),
	Reach("rend", "Rend", 8, "physical"),
	Reach("shield_slam", "Shield Slam", 7, "physical"),
	Trigger("battle_shout", "Battle Shout", 30, "physical"),
});

AST_Register("paladin", {
	Reach("exorcism", "Exorcism", 25, "holy"),
	Reach("hammer_of_wrath", "Hammer of Wrath", 28, "holy"),
	Reach("holy_shock", "Holy Shock", 22, "holy"),
	Reach("judgement", "Judgement", 12, "holy"),
	Reach("hammer_of_justice", "Hammer of Justice", 12, "holy"),
	Trigger("holy_shield", "Holy Shield", 30, "holy"),
	Flash("holy_light", "Holy Light", "holy"),
	Flash("divine_shield", "Divine Shield", "holy"),
});

AST_Register("hunter", {
	Reach("auto_shot", "Auto Shot", 32, "physical"),
	Reach("arcane_shot", "Arcane Shot", 32, "arcane"),
	Reach("multi_shot", "Multi-Shot", 30, "physical"),
	Reach("serpent_sting", "Serpent Sting", 30, "nature"),
	Reach("concussive_shot", "Concussive Shot", 30, "arcane"),
	Reach("aimed_shot", "Aimed Shot", 35, "physical"),
});

AST_Register("rogue", {
	Reach("sinister_strike", "Sinister Strike", 8, "physical"),
	Reach("eviscerate", "Eviscerate", 8, "physical"),
	Reach("rupture", "Rupture", 8, "physical"),
	Reach("kidney_shot", "Kidney Shot", 8, "physical"),
	Reach("gouge", "Gouge", 8, "physical"),
	Reach("ghostly_strike", "Ghostly Strike", 8, "physical"),
	Reach("backstab", "Backstab", 8, "physical"),
	Reach("seal_fate", "Seal Fate", 8, "physical", "sealfate"),
	Trigger("adrenaline_rush", "Adrenaline Rush", 30, "physical"),
	Trigger("slice_and_dice", "Slice and Dice", 30, "physical"),
});

AST_Register("priest", {
	Reach("smite", "Smite", 28, "holy"),
	Reach("sw_pain", "Shadow Word: Pain", 28, "shadow"),
	Reach("mind_blast", "Mind Blast", 28, "shadow"),
	Reach("holy_fire", "Holy Fire", 28, "holy"),
	Reach("devouring_plague", "Devouring Plague", 28, "shadow"),
	Flash("renew", "Renew", "holy"),
	Flash("pw_shield", "Power Word: Shield", "holy"),
	{
		-- "Every 20 sec, once enemies are within 25 yd, a Lightwell rises where you stand. For 10 sec
		-- it strikes the nearest enemy within 25 yd of it": 25 yd (a reach) for 1.4 x 7.15 sec.
		-- Placed by its cast in the spell list; its strikes land on enemies, not round it, so they
		-- don't size it.
		id = "lightwell", name = "Lightwell", shape = "ground", spellKey = "lightwell", atFeet = true,
		desc = "Where a Lightwell can strike: the ring around it fills in until it's gone.",
		on = { spells = {}, names = {} }, range = 0,
		tipNames = { "Lightwell" }, sizePattern = "within ([%d%.]+) yd of it", durationPattern = "For ([%d%.]+) sec it strikes",
		base = 25, unscaled = true, duration = 10, every = 1, recDuration = 7.15, tail = 0,
		defaults = { enabled = false, mode = "duration", line = { 1, 0.9, 0.5, 0.6 }, fill = { 1, 0.85, 0.4, 0.05 } },
	},
});

AST_Register("shaman", {
	Reach("lightning_bolt", "Lightning Bolt", 30, "nature"),
	Reach("chain_lightning", "Chain Lightning", 28, "nature"),
	Reach("earth_shock", "Earth Shock", 20, "nature"),
	Reach("flame_shock", "Flame Shock", 20, "fire"),
	Reach("frost_shock", "Frost Shock", 20, "frost"),
	Reach("stormstrike", "Stormstrike", 10, "nature"),
	Reach("rockbiter", "Rockbiter Weapon", 10, "nature"),
	Trigger("lightning_shield", "Lightning Shield", 30, "nature"),
	Flash("healing_wave", "Healing Wave", "nature"),
	{
		-- "Drops a totem beside you for 21 sec once enemies are within 25 yd. Every 1.5 sec it shoots
		-- the nearest enemy within 22 yd": 22 yd (a reach) round a totem set as Magma Totem's is,
		-- 1.5 yd ahead of where you face, for 1.4 x 15 sec. Its shots land on enemies, not round
		-- it, so they don't size it.
		id = "searing_totem", name = "Searing Totem", shape = "ground", spellKey = "searing_totem",
		atFeet = true, offset = 1.5,
		desc = "Where Searing Totem can shoot: the ring around the totem fills in until it's gone.",
		on = { spells = {}, names = {} }, range = 0,
		tipNames = { "Searing Totem" }, sizePattern = "shoots the nearest enemy within ([%d%.]+) yd",
		durationPattern = "beside you for ([%d%.]+) sec",
		base = 22, unscaled = true, duration = 21, every = 1.5, recDuration = 15, tail = 0,
		defaults = { enabled = false, mode = "duration", line = { 1, 0.5, 0.2, 0.6 }, fill = { 1, 0.4, 0.1, 0.05 } },
	},
});

AST_Register("mage", {
	Reach("fireball", "Fireball", 30, "fire"),
	Reach("frostbolt", "Frostbolt", 30, "frost"),
	Reach("arcane_missiles", "Arcane Missiles", 28, "arcane"),
	Reach("fire_blast", "Fire Blast", 22, "fire"),
	Reach("pyroblast", "Pyroblast", 35, "fire"),
	Flash("ice_barrier", "Ice Barrier", "frost"),
});

AST_Register("warlock", {
	Reach("shadow_bolt", "Shadow Bolt", 30, "shadow"),
	Reach("corruption", "Corruption", 30, "shadow"),
	Reach("immolate", "Immolate", 30, "fire"),
	Reach("curse_of_agony", "Curse of Agony", 30, "shadow"),
	Reach("death_coil", "Death Coil", 25, "shadow"),
	Reach("searing_pain", "Searing Pain", 26, "fire"),
	Reach("drain_life", "Drain Life", 22, "shadow"),
	Reach("fear", "Fear", 20, "shadow"),
	Reach("soul_fire", "Soulfire", 35, "fire", "soulfire"),
	Trigger("demonic_empowerment", "Demonic Empowerment", 30, "shadow"),
});

AST_Register("druid", {
	Reach("wrath", "Wrath", 30, "nature"),
	Reach("moonfire", "Moonfire", 30, "arcane"),
	Reach("starfire", "Starfire", 32, "arcane"),
	Reach("insect_swarm", "Insect Swarm", 28, "nature"),
	Reach("entangling_roots", "Entangling Roots", 25, "nature"),
	Reach("faerie_fire", "Faerie Fire", 30, "nature", "faeriefire"),
	Reach("shred", "Shred", 7, "physical"),
	Trigger("thorns", "Thorns", 30, "nature"),
	Flash("rejuvenation", "Rejuvenation", "nature"),
	Flash("regrowth", "Regrowth", "nature"),
});
