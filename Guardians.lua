-- Azeroth Survivors Telegraphs: guardians. Around a guardian asleep at its lair, how near you can
-- come before it wakes; around the lair of one that's chasing you, how far it follows before it
-- gives up (both warming to red as you near their edge, with a line of text); and on the minimap,
-- pins for the guardians (and their empty lairs' timers), the bosses and the caches, and a ring round
-- you as far as your chosen skill reaches, lit when a lair is within it. All on the Any class page,
-- under "Guardians".
--
-- How guardians behave:
--   * one at its lair (within 3 yd of it) wakes when it's hit, or when a hero comes within 20 yd
--     of it, centre to centre;
--   * awake, it chases while its hero is within 97.5 yd of its lair (not of itself). Past that it
--     gives up, walks home and heals to full; hit on the way, it turns and chases again. In a party
--     it first turns to another hero still within 97.5 yd of its lair.
-- The minimap shows 233 yd from its centre to its edge outdoors at its widest zoom (200, 167, 133,
-- 100, 67 closer in), 150 yd inside (120, 90, 60, 40, 25), north up: +x (north) up, +y (west) left.

local AGGRO, LEASH, HOME = 20, 97.5, 3;
local REACH_OUT = { 233.33, 200, 166.67, 133.33, 100, 66.67 };
local REACH_IN = { 150, 120, 90, 60, 40, 25 };
local VIEW = 160;                                   -- wake rings drawn for guardians this near
local WARN = { 1, 0.22, 0.12 };                     -- the colour a ring warms to
local PI = 3.14159265;

local G = { at = -100, units = {}, inside = false, lairsSeen = nil, lairsAt = 0 };
AST.guard = G;

local function Clamp(v)
	return math.max(0, math.min(1, v));
end

local function Dist(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by;
	return math.sqrt(dx * dx + dy * dy);
end

-- On the map you are on (an entry with no space is taken to be).
local function Here(e, p)
	return e.spaceId == nil or p.spaceId == nil or e.spaceId == p.spaceId;
end

local function RunClock()
	return (type(AZS_GetRunTime) == "function" and AZS_GetRunTime()) or GetTime();
end

-- You, the lairs, and where the guardians and bosses stand, read at most 10 times a second.
function G.Read()
	local t = GetTime();
	if ( G.p and t >= G.at and t - G.at < 0.1 ) then
		return G.p;
	end
	G.at = t;
	local p = type(AZS_GetPlayerPosition) == "function" and AZS_GetPlayerPosition();
	if ( type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" ) then
		G.p = nil;
		return nil;
	end
	G.p = p;
	local units = {};
	local res = type(AZS_GetWorldAnchors) == "function"
		and AZS_GetWorldAnchors({ kinds = { "guardian", "boss", "finalBoss" } }, nil, 256);
	local list = AST.draw.Entries(res) or {};
	for i = 1, table.getn(list) do
		local e = list[i];
		if ( type(e) == "table" and e.positionAvailable ~= false and type(e.x) == "number" and type(e.y) == "number"
			-- (the game's state is "alive": "living" left the guardians and bosses out, 2026-11-25)
			and ( e.state == nil or e.state == "alive" or e.state == "living" ) and Here(e, p)
			and ( e.kind == "guardian" or e.kind == "boss" or e.kind == "finalBoss" ) ) then
			table.insert(units, e);
		end
	end
	G.units = units;
	-- an empty lair's time to fill, counted down from when its line came
	if ( AZS_LAIRS_UPDATED ~= G.lairsSeen ) then
		G.lairsSeen, G.lairsAt = AZS_LAIRS_UPDATED, RunClock();
	end
	return p;
end

-- The lairs on your map (state "empty", "asleep" or "awake"; a held one's guardian by its id).
function G.Lairs(p)
	local all = (type(AZS_GetLairs) == "function" and AZS_GetLairs()) or AZS_LAIRS or {};
	local out = {};
	for i = 1, table.getn(all) do
		local l = all[i];
		if ( type(l) == "table" and type(l.x) == "number" and type(l.y) == "number" and Here(l, p) ) then
			table.insert(out, l);
		end
	end
	return out;
end

-- A lair's guardian where it stands now (its own id), or nil.
function G.UnitOf(lair)
	for i = 1, table.getn(G.units) do
		local e = G.units[i];
		if ( e.kind == "guardian" and lair.id ~= nil and tostring(e.unitId) == tostring(lair.id) ) then
			return e;
		end
	end
	return nil;
end

-- Seconds until an empty lair fills.
function G.Left(lair)
	if ( type(lair.left) ~= "number" ) then
		return nil;
	end
	return math.max(0, lair.left - (RunClock() - G.lairsAt));
end

---------------------------------------------------------------------------------------------
-- The rings in the world

-- `st` warmed toward red by w (0 to 1), pulsing faster as it nears 1: one table, reused.
local warm = setmetatable({ line = { 1, 1, 1, 1 }, fill = { 1, 1, 1, 0 } }, {});
local function Warm(st, w, now)
	if ( w <= 0 ) then
		return st;
	end
	getmetatable(warm).__index = st;
	local beat = 0.5 + 0.5 * math.sin(now * 2 * PI * (0.8 + 2.2 * w));
	for i = 1, 3 do
		warm.line[i] = st.line[i] + (WARN[i] - st.line[i]) * w;
		warm.fill[i] = st.fill[i] + (WARN[i] - st.fill[i]) * w;
	end
	warm.line[4] = math.min(1, st.line[4] * (1 + w * 0.6 * beat) + w * 0.2);
	warm.fill[4] = math.min(0.4, st.fill[4] + w * 0.08 * beat);
	warm.width = st.width * (1 + 0.5 * w);
	warm.size = st.size * (1 + 0.35 * w);
	return warm;
end

-- Each of j.points: a ring of j.size round it at its own height, warmed by its `warn`; the most
-- pressing one's line of text under you.
local function DrawPoints(j, p, now)
	local D = AST.draw;
	local st, R = j.st, j.size;
	local worst;
	for i = 1, table.getn(j.points) do
		local pt = j.points[i];
		local cu, cv = pt.x, pt.y;
		if ( not pt.rel ) then
			cu, cv = pt.x - p.x, pt.y - p.y;
			D.H.dz = ( type(pt.z) == "number" and type(p.z) == "number" ) and pt.z - p.z or 0;
		end
		local look = Warm(st, pt.warn or 0, now);
		local tex = look.style == "texture" and AST.lab and AST.lab.tex and AST.lab.tex.Circle;
		if ( not ( tex and tex(cu, cv, R, look, j.alpha, nil, nil) ) ) then
			D.Circle(cu, cv, R, look, j.alpha, nil, nil);
		end
		D.H.dz = 0;
		if ( ( pt.warn or 0 ) > 0 and ( not worst or pt.warn > worst.warn ) ) then
			worst = pt;
		end
	end
	if ( worst and st.warnText and j.def.say ) then
		local x, y = D.Map(0, 0);
		if ( x ) then
			D.Text(j.def.say(worst), x, y - 34, Warm(st, worst.warn, now).line, j.alpha);
		end
	end
end

local aggro, leash, pins, ranger;

aggro = {
	id = "guardian_aggro", name = "Guardian wake range", shape = "world", kind = "Guardians",
	radius = AGGRO, sizeLabel = "wakes it",
	desc = "Around each guardian asleep at its lair: come this near, or hit it, and it wakes. It warms to red as you close in.",
	points = function(now)
		local p = G.Read();
		if ( not p ) then
			return {};
		end
		local st = AST.Settings(aggro);
		local out = {};
		local lairs = G.Lairs(p);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			if ( l.state == "asleep" ) then
				local u = G.UnitOf(l);
				local x, y, z = l.x, l.y, l.z;
				if ( u ) then
					x, y, z = u.x, u.y, u.z or l.z;
				end
				-- only at home does coming near wake it (on its way back, only a hit does)
				local d = Dist(x, y, p.x, p.y);
				if ( Dist(x, y, l.x, l.y) <= HOME + 1 and d <= VIEW ) then
					local w = st.warnAt > 0 and Clamp((AGGRO + st.warnAt - d) / st.warnAt) or 0;
					table.insert(out, { x = x, y = y, z = z, warn = w, d = d, name = l.name });
				end
			end
		end
		return out;
	end,
	demo = function(t)
		-- one asleep 26 yd ahead, you walking up to it
		return { { rel = true, x = 26, y = 6, warn = Clamp(t / 2.5), d = AGGRO + 8 * (1 - t / 3), name = "Guardian" } };
	end,
	draw = DrawPoints,
	say = function(pt)
		local left = pt.d - AGGRO;
		if ( left <= 0 ) then
			return string.format(AST_L("%s wakes"), AST_L(tostring(pt.name or "Guardian")));
		end
		return string.format(AST_L("%s wakes in %d yd"), AST_L(tostring(pt.name or "Guardian")), math.ceil(left));
	end,
	defaults = { enabled = true, mode = "always", warnAt = 8, warnText = false,
		line = { 1, 0.62, 0.22, 0.6 }, fill = { 1, 0.5, 0.15, 0 } },
};

leash = {
	id = "guardian_leash", name = "Guardian leash", shape = "world", kind = "Guardians",
	radius = LEASH, sizeLabel = "from its lair", leash = true,
	desc = "Around the lair of a guardian that's chasing you: past this ring it gives up, walks home and heals to full. It warms to red as you near it.",
	points = function(now)
		local p = G.Read();
		if ( not p ) then
			return {};
		end
		local st = AST.Settings(leash);
		local out = {};
		local lairs = G.Lairs(p);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			if ( l.state == "awake" ) then
				local d = Dist(l.x, l.y, p.x, p.y);
				local w = st.warnAt > 0 and Clamp((d - (LEASH - st.warnAt)) / st.warnAt) or 0;
				table.insert(out, { x = l.x, y = l.y, z = l.z, warn = w, d = d, name = l.name });
			end
		end
		return out;
	end,
	demo = function(t)
		-- a lair 90 yd behind you, you running on toward its edge
		local d = 84 + 13 * t / 3;
		return { { rel = true, x = -d, y = 0, warn = Clamp((d - (LEASH - 15)) / 15), d = d, name = "Guardian" } };
	end,
	draw = DrawPoints,
	say = function(pt)
		local left = LEASH - pt.d;
		if ( left <= 0 ) then
			return string.format(AST_L("%s gives up: back to full health"), AST_L(tostring(pt.name or "Guardian")));
		end
		return string.format(AST_L("%s gives up in %d yd"), AST_L(tostring(pt.name or "Guardian")), math.ceil(left));
	end,
	defaults = { enabled = true, mode = "always", warnAt = 15, warnText = true,
		line = { 0.45, 0.75, 1, 0.55 }, fill = { 0.45, 0.75, 1, 0 } },
};

pins = {
	id = "guardian_pins", name = "Minimap pins", shape = "pins", kind = "Guardians", ownRows = "pins",
	desc = "Guardians, their empty lairs' timers, bosses and caches on the minimap. Ones past its edge wait on the rim.",
	defaults = { enabled = true, mode = "always" },
};

ranger = {
	id = "minimap_range", name = "Minimap range ring", shape = "pins", kind = "Guardians", ownRows = "mmrange",
	desc = "Your chosen skill's range round you on the minimap. It lights up when a guardian's lair is within it, so you can strike the guardian the moment it's up.",
	defaults = { enabled = true, mode = "always" },
};

AST_Register("common", { aggro, leash, pins, ranger });

---------------------------------------------------------------------------------------------
-- The minimap's pins

local LOOK = {
	-- texture, its corners (l, r, t, b), colour, size (x the pin size)
	asleep = { "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 0.75, 1, 0.25, 0.5, { 0.92, 0.92, 0.92, 1 }, 1 },
	awake = { "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 0.75, 1, 0.25, 0.5, { 1, 0.4, 0.3, 1 }, 1.2 },
	empty = { "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 0.75, 1, 0.25, 0.5, { 0.55, 0.55, 0.6, 0.75 }, 0.85 },
	boss = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", 0, 1, 0, 1, { 1, 1, 1, 1 }, 1.45 },
	cache = { "Interface\\Icons\\INV_Box_01", 0.14, 0.86, 0.14, 0.86, { 1, 1, 1, 1 }, 0.95 },
};

local frame = CreateFrame("Frame", "ASTPins", Minimap);
frame:SetAllPoints(Minimap);
if ( Minimap.GetFrameLevel and frame.SetFrameLevel ) then
	frame:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 4);
end
G.frame, G.icons, G.shown = frame, {}, 0;

local function Icon(n)
	local t = G.icons[n];
	if ( not t ) then
		t = frame:CreateTexture(nil, "OVERLAY");
		t.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		G.icons[n] = t;
	end
	return t;
end

-- Yards from the minimap's centre to its edge at its zoom now (outdoors or inside: told apart by
-- which zoom setting the zoom matches, while they differ).
function G.Reach()
	local z = ( Minimap.GetZoom and Minimap:GetZoom() ) or 0;
	local ok, zo = pcall(GetCVar, "minimapZoom");
	local ok2, zi = pcall(GetCVar, "minimapInsideZoom");
	zo, zi = ok and tonumber(zo), ok2 and tonumber(zi);
	if ( zo and zi and zo ~= zi ) then
		G.inside = ( z == zi );
	end
	local k = math.max(0, math.min(5, math.floor(z + 0.5))) + 1;
	return G.inside and REACH_IN[k] or REACH_OUT[k];
end

-- One pin `look` at dx, dy yards (north, west) from you; `timer`: a text under it.
local function Pin(n, look, dx, dy, s, half, st, timer)
	local L = LOOK[look];
	local size = st.pinSize * L[7];
	local ox, oy = -dy * s, dx * s;
	local r, edge = math.sqrt(ox * ox + oy * oy), half - size * 0.5;
	local alpha = L[6][4];
	if ( r > edge ) then
		if ( not st.pinEdge or r <= 0 ) then
			return n;
		end
		-- past the edge: on the rim, smaller and fainter
		ox, oy = ox * edge / r, oy * edge / r;
		size, alpha = size * 0.8, alpha * 0.6;
	end
	n = n + 1;
	local t = Icon(n);
	t:SetTexture(L[1]);
	t:SetTexCoord(L[2], L[3], L[4], L[5]);
	t:SetVertexColor(L[6][1], L[6][2], L[6][3], alpha);
	t:SetWidth(size);
	t:SetHeight(size);
	t:ClearAllPoints();
	t:SetPoint("CENTER", frame, "CENTER", ox, oy);
	t:Show();
	if ( timer ) then
		t.timer:SetText(timer);
		t.timer:ClearAllPoints();
		t.timer:SetPoint("TOP", t, "BOTTOM", 0, 0);
		t.timer:Show();
	else
		t.timer:Hide();
	end
	return n;
end

local function Clock(sec)
	sec = math.ceil(sec);
	return string.format("%d:%02d", math.floor(sec / 60), sec - 60 * math.floor(sec / 60));
end

function G.UpdatePins()
	local n = 0;
	local db = AST.State();
	local st = db and AST.Settings(pins);
	-- a Test press (or the showcase): its 3 seconds from its own timer, so it ends even with the pins off
	local endsAt = AST.preview and AST.preview[pins.id];
	local test = endsAt and GetTime() < endsAt and ( 3 - (endsAt - GetTime()) ) or nil;
	-- the showcase: the same, for as long as it plays
	local show = AST.showcase and AST.showcase.on and AST.showcase.Clock();
	if ( show ) then
		test = show;
	end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase();
	if ( st and ( show or not db.hidden ) and ( test or ( st.enabled and phase ~= nil and phase ~= "victory" ) ) ) then
		local half = (Minimap:GetWidth() or 140) / 2;
		local s = half / G.Reach();
		if ( test ) then
			-- a Test press: one of each round you (the awake one on the move, the empty lair's time
			-- counting down, again from 13 sec once it's run out)
			local w = test * 0.7;
			n = Pin(n, "asleep", 60, -40, s, half, st);
			n = Pin(n, "awake", -25 + 8 * math.cos(w), 30 + 8 * math.sin(w), s, half, st);
			n = Pin(n, "empty", 20, 70, s, half, st, Clock(13 - (test - math.floor(test / 13) * 13)));
			n = Pin(n, "boss", 400, 120, s, half, st);
			n = Pin(n, "cache", -45, -10, s, half, st);
		else
			local p = G.Read();
			if ( p ) then
				if ( st.pinCaches ) then
					local chests = AZS_CHESTS or {};
					for i = 1, table.getn(chests) do
						local c = chests[i];
						if ( type(c) == "table" and type(c.x) == "number" and type(c.y) == "number" and Here(c, p) ) then
							n = Pin(n, "cache", c.x - p.x, c.y - p.y, s, half, st);
						end
					end
				end
				if ( st.pinGuardians ) then
					local lairs = G.Lairs(p);
					for i = 1, table.getn(lairs) do
						local l = lairs[i];
						if ( l.state == "empty" ) then
							local left = st.pinTimers and G.Left(l);
							if ( st.pinTimers ) then
								n = Pin(n, "empty", l.x - p.x, l.y - p.y, s, half, st, left and Clock(left));
							end
						else
							local u = G.UnitOf(l);
							local x, y = l.x, l.y;
							if ( u ) then
								x, y = u.x, u.y;
							end
							n = Pin(n, l.state == "awake" and "awake" or "asleep", x - p.x, y - p.y, s, half, st);
						end
					end
				end
				if ( st.pinBosses ) then
					for i = 1, table.getn(G.units) do
						local e = G.units[i];
						if ( e.kind == "boss" or e.kind == "finalBoss" ) then
							n = Pin(n, "boss", e.x - p.x, e.y - p.y, s, half, st);
						end
					end
				end
			end
		end
	end
	n = G.UpdateRing(n);
	for i = n + 1, G.shown do
		G.icons[i]:Hide();
		G.icons[i].timer:Hide();
	end
	G.shown = n;
end

---------------------------------------------------------------------------------------------
-- The minimap's range ring: round you, how far your chosen skill reaches (each class its own
-- skill, or a range of your own), lit when a guardian's lair is within it, so you can strike the
-- guardian the moment it's up. Drawn under the pins, in round dots (solid or dotted).

local MR = {
	mmSkills = {}, mmOverride = 0,
	mmEmpty = true, mmSoon = 0, mmAsleep = true, mmAwake = false, mmBosses = false,
	mmNear = 0, mmNearC = { 1, 0.78, 0.3, 0.9 },
	mmStyle = "solid", mmWidth = 2, mmGap = 6,
	mmLine = { 0.75, 0.85, 1, 0.55 }, mmHot = { 0.35, 1, 0.45, 1 },
	mmFill = false, mmFillA = 0.12, mmPulse = true, mmGrow = true, mmMark = true, mmText = false,
	mmOnlyNear = false,
};
local NEAR = 50;            -- "only near a lair": shown while one is this far past the ring at most
local MAXDOTS = 400;

G.CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" };
G.NEAR = NEAR;

-- The ring's settings, its own defaults filled in (they live with its telegraph's, so Reset and
-- Start over put them back too).
function G.MR()
	local s = AST.Settings(ranger);
	for k, v in pairs(MR) do
		if ( s[k] == nil ) then
			if ( type(v) == "table" ) then
				local c = {};
				for i, x in pairs(v) do
					c[i] = x;
				end
				v = c;
			end
			s[k] = v;
		end
	end
	return s;
end

-- What a class can take its range from: its spell range (or shot range, strike reach) first, then
-- its skills' ranges, then the rest round you with a size. Its own rings and the flashes aren't.
G.skillLists = {};
function G.Skills(class)
	local have = G.skillLists[class];
	if ( have ) then
		return have;
	end
	local r = AST.registry[class];
	local first, reach, rest = {}, {}, {};
	for i = 1, table.getn(r and r.defs or {}) do
		local d = r.defs[i];
		local id = d.id;
		local sized = d.sizePattern or d.radius or d.radii or d.sizeOf or d.base;
		if ( sized and ( d.shape == "circle" or d.shape == "cone" ) and not d.hidden and not d.custom
			and not string.find(id, "_trigger$") and not string.find(id, "_cast$") ) then
			if ( id == "range" or id == class .. "_range" ) then
				table.insert(first, d);
			elseif ( string.find(id, "_reach$") ) then
				table.insert(reach, d);
			else
				table.insert(rest, d);
			end
		end
	end
	for i = 1, table.getn(reach) do
		table.insert(first, reach[i]);
	end
	for i = 1, table.getn(rest) do
		table.insert(first, rest[i]);
	end
	-- (built the first time it's asked, once every class file has registered)
	G.skillLists[class] = first;
	return first;
end

-- The longest range of the skills your hero has now (the class's own list; its talents' and
-- items' effects aren't skills), and that skill: read again each time, so a skill that grows past
-- the others takes over at once.
function G.Longest(class)
	local list = G.Skills(class);
	local best, bestDef;
	for i = 1, table.getn(list) do
		local d = list[i];
		if ( AST.HaveSkill(d) ) then
			local r, how = AST.RangeOf(d);
			-- a ring that isn't one skill's (spell range) counts only as read off one of your
			-- skills' tooltips: its usual size alone doesn't say you have a spell that reaches it
			if ( not d.spellKey and d.sizePattern and how ~= "tooltip" and how ~= "your override" ) then
				r = nil;
			end
			if ( type(r) == "number" and r > 0 and ( not best or r > best ) ) then
				best, bestDef = r, d;
			end
		end
	end
	return best, bestDef;
end

-- The skill a class's ring goes by: the one picked for it, else its first ("longest" picked: its
-- first too; RangeNow and the options ask for the longest themselves).
function G.SkillOf(class)
	local list = G.Skills(class);
	local want = G.MR().mmSkills[class];
	for i = 1, table.getn(list) do
		if ( list[i].id == want ) then
			return list[i];
		end
	end
	return list[1];
end

-- A skill's size before your Area (for another class's, which can't be read now), or nil.
function G.BaseOf(def)
	if ( def.sizeOf ) then
		for c, r in pairs(AST.registry) do
			for i = 1, table.getn(r.defs) do
				if ( r.defs[i].id == def.sizeOf ) then
					return G.BaseOf(r.defs[i]);
				end
			end
		end
		return nil;
	end
	return def.radius or def.base or ( def.radii and def.radii[1] );
end

-- The ring's range now in yd (nil: none) and the skill it's from (nil: your own range).
function G.RangeNow()
	local s = G.MR();
	if ( type(s.mmOverride) == "number" and s.mmOverride > 0 ) then
		return s.mmOverride, nil;
	end
	local _, _, myClass = AST.State();
	if ( myClass and s.mmSkills[myClass] == "longest" ) then
		return G.Longest(myClass);
	end
	local def = myClass and G.SkillOf(myClass);
	if ( not def ) then
		return nil, nil;
	end
	local r = AST.RangeOf(def);
	if ( type(r) ~= "number" or r <= 0 ) then
		return nil, def;
	end
	return r, def;
end

local ring = CreateFrame("Frame", "ASTRangeRing", Minimap);
ring:SetAllPoints(Minimap);
if ( Minimap.GetFrameLevel and ring.SetFrameLevel ) then
	-- under the pins
	ring:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3);
end
G.ring, G.dots, G.dotsShown, G.marks = ring, {}, 0, {};
G.disc = ring:CreateTexture(nil, "BORDER");
AST.SetPiece(G.disc, AST.round);
G.disc:Hide();
G.ringText = ring:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
G.ringText:Hide();

-- Dot n at x, y px from the minimap's centre: its calls only when something changed.
local function Dot(n, x, y, w, c, a)
	local t = G.dots[n];
	if ( not t ) then
		t = ring:CreateTexture(nil, "ARTWORK");
		AST.SetPiece(t, AST.round);
		G.dots[n] = t;
	end
	if ( t.x ~= x or t.y ~= y or t.w ~= w ) then
		t:SetWidth(w);
		t:SetHeight(w);
		t:ClearAllPoints();
		t:SetPoint("CENTER", ring, "CENTER", x, y);
		t.x, t.y, t.w = x, y, w;
	end
	if ( t.r ~= c[1] or t.g ~= c[2] or t.b ~= c[3] or t.a ~= a ) then
		t:SetVertexColor(c[1], c[2], c[3], a);
		t.r, t.g, t.b, t.a = c[1], c[2], c[3], a;
	end
	if ( not t.on ) then
		t:Show();
		t.on = true;
	end
end

-- A ring of dots `r` px round (cx, cy), from dot n + 1 on; returns the last dot's number. Solid:
-- the dots overlap, each fainter, so together they have opacity a; else `gap` px apart.
local function Circle(n, cx, cy, r, w, gap, solid, c, a)
	local around = 2 * PI * r;
	local step = solid and math.max(0.75, w * 0.5) or math.max(w + 1, gap);
	local count = math.max(solid and 12 or 6, math.min(MAXDOTS, math.floor(around / step + 0.5)));
	local each = a;
	if ( solid ) then
		local over = math.max(1, w / (around / count));
		each = 1 - math.pow(1 - math.min(a, 0.995), 1 / over);
	end
	for i = 1, count do
		local ang = 2 * PI * i / count;
		Dot(n + i, cx + r * math.cos(ang), cy + r * math.sin(ang), w, c, each);
	end
	return n + count;
end

function G.HideRing()
	for i = 1, G.dotsShown do
		G.dots[i]:Hide();
		G.dots[i].on = false;
	end
	G.dotsShown = 0;
	G.disc:Hide();
	G.ringText:Hide();
	G.ringState, G.hot, G.near = nil, false, false;
end

-- What's within reach (dx, dy yd from you, north and west): in range (hot), within the early
-- warning (near), within NEAR (close). Up to 4 in range kept, for their marks.
local reach = { R = 0, warn = 0, hot = false, near = false, close = false, n = 0 };
local function Take(dx, dy)
	local d = math.sqrt(dx * dx + dy * dy);
	if ( d <= reach.R ) then
		reach.hot = true;
		if ( reach.n < 4 ) then
			reach.n = reach.n + 1;
			G.marks[reach.n] = G.marks[reach.n] or {};
			G.marks[reach.n][1], G.marks[reach.n][2] = dx, dy;
		end
	elseif ( reach.warn > 0 and d <= reach.R + reach.warn ) then
		reach.near = true;
	end
	reach.close = reach.close or d <= reach.R + NEAR;
end

-- The ring, each 0.05 sec with the pins (n: the pins drawn so far; a Test press adds one of its own,
-- a guardian you come within range of). Returns the pins drawn.
function G.UpdateRing(n)
	local db = AST.State();
	local s = db and G.MR();
	local endsAt = AST.preview and AST.preview[ranger.id];
	local test = endsAt and GetTime() < endsAt and ( 3 - (endsAt - GetTime()) ) / 3 or nil;
	local show = AST.showcase and AST.showcase.on and AST.showcase.Clock();
	if ( show ) then
		test = (show - 4 * math.floor(show / 4)) / 4;
	end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase();
	local on = s and ( show or not db.hidden ) and ( test or ( s.enabled and phase ~= nil and phase ~= "victory" ) );
	local R = on and G.RangeNow();
	if ( on and test and not R ) then
		R = 28;
	end
	local p = R and not test and G.Read();
	if ( not R or not ( test or p ) ) then
		G.HideRing();
		return n;
	end
	local half = (Minimap:GetWidth() or 140) / 2;
	local sc = half / G.Reach();
	local pinSt = AST.Settings(pins);
	reach.R, reach.warn, reach.hot, reach.near, reach.close, reach.n = R, s.mmNear or 0, false, false, false, 0;
	if ( test ) then
		-- a guardian asleep at its lair, you coming within range of it
		local d = R + 24 - 34 * test;
		n = Pin(n, "asleep", d * 0.8, -d * 0.6, sc, half, pinSt);
		Take(d * 0.8, -d * 0.6);
	else
		local lairs = G.Lairs(p);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			local x, y, take = l.x, l.y, false;
			if ( l.state == "empty" ) then
				local left = G.Left(l);
				take = s.mmEmpty and ( s.mmSoon <= 0 or left == nil or left <= s.mmSoon );
			else
				take = ( l.state == "awake" and s.mmAwake ) or ( l.state ~= "awake" and s.mmAsleep );
				local u = G.UnitOf(l);
				if ( u ) then
					x, y = u.x, u.y;
				end
			end
			if ( take ) then
				Take(x - p.x, y - p.y);
			end
		end
		if ( s.mmBosses ) then
			for i = 1, table.getn(G.units) do
				local e = G.units[i];
				if ( e.kind == "boss" or e.kind == "finalBoss" ) then
					Take(e.x - p.x, e.y - p.y);
				end
			end
		end
		if ( s.mmOnlyNear and not reach.close ) then
			G.HideRing();
			return n;
		end
	end
	local hot, near = reach.hot, reach.near;
	local c = ( hot and s.mmHot ) or ( near and s.mmNearC ) or s.mmLine;
	local w = s.mmWidth * ( ( hot and s.mmGrow ) and 1.5 or 1 );
	local r, a = R * sc, c[4];
	if ( r > half - w ) then
		-- past the minimap's edge (zoomed in): kept on its rim, fainter
		r, a = half - w, a * 0.5;
	end
	r = math.max(3, r);
	local solid = s.mmStyle ~= "dotted";
	-- the ring's dots move only when its size or look does
	local key = r .. ":" .. w .. ":" .. s.mmGap .. ":" .. tostring(solid) .. ":" .. c[1] .. ":" .. c[2] .. ":" .. c[3] .. ":" .. a;
	local k;
	if ( G.ringState == key ) then
		k = G.ringDots;
	else
		k = Circle(0, 0, 0, r, w, s.mmGap, solid, c, a);
		G.ringState, G.ringDots = key, k;
	end
	-- a ring round each pin in range
	if ( hot and s.mmMark ) then
		local mr = pinSt.pinSize * 0.75;
		for i = 1, reach.n do
			local ox, oy = -G.marks[i][2] * sc, G.marks[i][1] * sc;
			local d, edge = math.sqrt(ox * ox + oy * oy), half - mr;
			if ( d > edge and d > 0 ) then
				ox, oy = ox * edge / d, oy * edge / d;
			end
			k = Circle(k, ox, oy, mr, 1.5, 0, true, s.mmHot, s.mmHot[4]);
		end
	end
	for i = k + 1, G.dotsShown do
		G.dots[i]:Hide();
		G.dots[i].on = false;
	end
	G.dotsShown = k;
	if ( s.mmFill ) then
		G.disc:SetWidth(2 * r);
		G.disc:SetHeight(2 * r);
		G.disc:ClearAllPoints();
		G.disc:SetPoint("CENTER", ring, "CENTER", 0, 0);
		G.disc:SetVertexColor(c[1], c[2], c[3], s.mmFillA);
		G.disc:Show();
	else
		G.disc:Hide();
	end
	if ( s.mmText ) then
		G.ringText:SetText(string.format(AST_L("%g yd"), math.floor(R * 2 + 0.5) / 2));
		G.ringText:SetTextColor(c[1], c[2], c[3], 1);
		G.ringText:ClearAllPoints();
		G.ringText:SetPoint("BOTTOM", ring, "CENTER", 0, math.min(r + w, half - 12));
		G.ringText:Show();
	else
		G.ringText:Hide();
	end
	-- in range: a slow beat
	local beat = 1;
	if ( hot and s.mmPulse ) then
		beat = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(GetTime() * 2 * PI * 1.1));
	end
	ring:SetAlpha(beat);
	G.hot, G.near, G.R = hot, near, R;
	return n;
end

-- The game's own red flag on the nearest guardian: always hidden while you play with this addon
-- (the pins show the guardians), shown again whenever you're not in a run: as you leave the world or
-- log out, or out of a run. It's the game's own setting and outlives the addon, so the addon never
-- leaves it off when it's gone: db.flagHid says the addon hid it, so it's put back even after a
-- crash, as soon as the addon runs out of a run.
function G.Flag(want)
	local db = AST.State();
	if ( not db or type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" ) then
		return;
	end
	if ( want ) then
		if ( AZS_IsHudShown("flag") ) then
			AZS_SetHudShown("flag", false);
		end
		db.flagHid = true;
	elseif ( db.flagHid ) then
		AZS_SetHudShown("flag", true);
		db.flagHid = nil;
	end
end

local since = 0;
frame:SetScript("OnUpdate", function()
	since = since + (arg1 or 0);
	if ( since >= 0.05 ) then
		since = 0;
		G.UpdatePins();
		local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase();
		-- (not for a moment after leaving: the world may still tick on its way out)
		G.Flag(phase ~= nil and not ( G.leaving and GetTime() - G.leaving < 3 ));
	end
end);
frame:RegisterEvent("PLAYER_LEAVING_WORLD");
frame:RegisterEvent("PLAYER_LOGOUT");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:SetScript("OnEvent", function()
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		G.leaving = nil;
	elseif ( event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" ) then
		-- leaving the game (or reloading): the flag back on
		G.leaving = GetTime();
		G.Flag(false);
	end
end);
