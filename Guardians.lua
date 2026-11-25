-- Azeroth Survivors Telegraphs: guardians. Around a guardian asleep at its lair, how near you can
-- come before it wakes; around the lair of one that's chasing you, how far it follows before it
-- gives up (both warming to red as you near their edge, with a line of text); and on the minimap,
-- pins for the guardians (and their empty lairs' timers), the bosses and the caches. All on the Any
-- class page, under "Guardians".
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
			and ( e.state == nil or e.state == "living" ) and Here(e, p)
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

local aggro, leash, pins;

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

AST_Register("common", { aggro, leash, pins });

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
	for i = n + 1, G.shown do
		G.icons[i]:Hide();
		G.icons[i].timer:Hide();
	end
	G.shown = n;
end

local since = 0;
frame:SetScript("OnUpdate", function()
	since = since + (arg1 or 0);
	if ( since >= 0.05 ) then
		since = 0;
		G.UpdatePins();
	end
end);
