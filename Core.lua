-- Azeroth Survivors Telegraphs: ground telegraphs for every class's spells and their area
-- effects. /ast opens the options.
--
-- How it draws: the client can't project an arbitrary world point, but AZS_ProjectWorldAnchors
-- projects an anchor (an enemy, cache, lair...) plus an offset in yards. Each frame four ground
-- points close around the hero are projected that way; the ground-to-screen mapping of a flat
-- plane through a perspective camera is a homography, so those four fix it exactly and every
-- shape is placed from it without more calls. With no anchor on the map there is nothing to
-- project from, and the telegraphs hide until one shows up.
--
-- Two styles. Smooth fills a shape with thin screen-wide strips and strokes its outline with
-- solid quads; Dots marks it out in round dots.
--
-- Each class's telegraphs are in a file of their own (ClassPriest.lua...), and those any class
-- can use in ClassCommon.lua. Such a file hands them to AST_Register(class, defs, extras); your
-- class's and the common ones are drawn, and the options window (Options.lua) has a page for
-- each. A telegraph (a def):
--   id (one telegraph's across every class: its settings are kept by it), name; desc: a line on
--     what it shows, for the options; kind: its heading in the options' list ("Spells",
--     "Talents", "Amulets", "Sets", "Other"; worked out when left out);
--   shape: "cone" (apex at the hero, along its facing), "circle" (around the hero),
--     "enemy" (where an effect goes off on an enemy), "ground" (a spot a spell lands on and
--     covers for a while: on the thickest group of enemies within `range` yd, its hits of `on`
--     telling its size; it lasts `duration`, or what its tooltip's durationPattern reads, and
--     ticks every `every` sec, the first `firstTick` sec after it lands; atFeet: set where you
--     stand, a trap, `offset` yd ahead of where you face; freeFall: one that falls without a
--     cast of the spell it is, that telegraph's id: placed by its first tick; follows: the key
--     (an armor set's) that makes its spots move with you) or
--     "downed" (around downed teammates), "world" (places it finds itself: points(now) lists
--     { x, y, z, ... } in the world, demo(t) a Test press's near you, draw(j, p, now) draws
--     j.points; Guardians.lua) or "pins" (shown on the minimap, never in the world);
--   modes: { "cast", "cooldown" } when it can show either way;
--   spellKey: its key in AZS_SPELLS (its cooldown and casts); unlisted: a skill that list may not
--     show (Seal Fate): known by `match` (the meter's ability list) too, then a plain ring;
--   of, ofFmt, descFmt: the skill a ring is of and the formats its name and line are made with
--     (Skills.lua), so the options can put each part in the game's language;
--   tipNames, sizePattern: the action bar tooltips to read its size from; base, reachTalent,
--     reachPerRank: the formula when none can be read (unscaled: base is a reach, which your
--     Area doesn't widen; areaItem: the key of an item whose "+N% area" widens it too);
--     sizeOf: another telegraph's size;
--   radius / radii: a fixed size (per matched key); with none of these, the `radius` setting;
--   halfAngle: a cone's half width in degrees;
--   match: the keys that give it (an item's or a talent's); talentKeys: those that are talents;
--     showsItself: its own hits show it, so it's watched for before your hero is known to have it;
--   needs: the damage over time an enemy must die with (or, for a "hit" trigger, carry), per
--     matched key ("any" for any);
--   trigger: "kill", "crit", "hit" (each hit of `on` = { spells, names, ticks: its damage over
--     time's ticks too }) or "burst" (the hits of `on` together, flashed where they centre; atKill:
--     on each body they went off from, atHero: only those around you); by: the spells a kill must
--     come from ({ spells, names }); cap: its "at most N times a second";
--   buffSpells: the buff it shows with; procOn: the hits that set it off; spot: the hits that
--     show your hero has it (after a procOn hit, and not your own cast of spot.ownSpell);
--   free: a spell going off without your casting it ({ spells, names, ownSpell, unless: a proc
--     whose hits these are not }); clock: a talent's own timer ({ names, every: seconds });
--   needName: what to tell a hero without it; defaults: its settings to start with.
-- A "ground" telegraph that picks its spot, or is placed by its first tick (freeFall), is
-- experimental (its spot can be off): it's marked so in the options and starts off, unless it's
-- `trusted` (none is now). One set at your feet when the spell list shows its cast is where you stood
-- then, and isn't.
-- extras: gear = { { text on an item, key it gives } }, dots = { key = { spells, names, keys } },
--   auras = { { key, textures, spells, name } }; icon: the class's tab icon; blurb: a line under
--   its page's heading.

local MODES = { cast = { "Briefly on cast", 100 }, cooldown = { "Always + cooldown fill", 150 },
	proc = { "When it goes off", 112 } };
local REGISTRY = {};   -- class -> { defs, gear, dots, auras, icon, blurb }

function AST_Register(class, defs, extras)
	local r = REGISTRY[class];
	if ( not r ) then
		r = { defs = {}, gear = {}, dots = {}, auras = {} };
		REGISTRY[class] = r;
	end
	extras = extras or {};
	r.icon = extras.icon or r.icon;
	r.blurb = extras.blurb or r.blurb;
	for i = 1, table.getn(defs) do
		for other, o in pairs(REGISTRY) do
			for j = 1, table.getn(o.defs) do
				if ( o.defs[j].id == defs[i].id ) then
					DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: two telegraphs have the id \""
						.. defs[i].id .. "\" (" .. other .. ", " .. class .. "): they would share settings.");
				end
			end
		end
		defs[i].group = class;
		if ( defs[i].shape == "ground" and ( defs[i].freeFall or not defs[i].atFeet ) and not defs[i].trusted ) then
			defs[i].experimental = true;
			defs[i].defaults = defs[i].defaults or {};
			defs[i].defaults.enabled = false;
		end
		table.insert(r.defs, defs[i]);
	end
	for i = 1, table.getn(extras.gear or {}) do
		table.insert(r.gear, extras.gear[i]);
	end
	for key, dot in pairs(extras.dots or {}) do
		r.dots[key] = dot;
	end
	for i = 1, table.getn(extras.auras or {}) do
		table.insert(r.auras, extras.auras[i]);
	end
end

-- What this hero uses (SetupClass fills these): its class's telegraphs, then the common ones.
local DEFS, byId = {}, {};
local GEAR, DOTS, AURAS, TALENT_KEYS = {}, {}, {}, {};
local myClass;

-- Telegraphs Priest Telegraphs draws as well: while it runs, they are left to it.
local PRIEST_TELEGRAPHS = { mind_flay = true, holy_nova = true, chastise = true, psychic_scream = true,
	shield = true, range = true, choker = true, pendant = true, shadowform = true, onyxia = true,
	revive = true, ring = true };
local skipped = {};

local COMMON = {
	enabled = true, mode = "cooldown", style = "texture", flash = 0.6,
	-- subdued to start with (people like them quiet): a 2 px outline, no glow, small dots
	line = { 1, 1, 1, 0.8 }, fill = { 1, 1, 1, 0.15 },
	width = 2, glow = false, strip = 3,                                    -- Smooth
	size = 4, spacing = 10, fillSpacing = 12, fillStyle = "solid",         -- Dots
	length = 0, radius = 8,
	most = 0,                                                              -- enemy effects: 0 = no cap
	-- every telegraph starts as just its ring (the user, 2026-11-24): no fill, no cooldown or
	-- duration shown in it, no glow; each can be turned on on its page or the All telegraphs tab
	cdFill = false, durFill = false, uptime = false,                       -- the time it shows
	-- its parts, each of which can go entirely: the outline, the fill, the faint area still to fill,
	-- the fill's bright front line, a cast's pulse and shockwave (the glow is `glow`). A settings
	-- table without them (a Lab demo's) has them all: only false turns one off.
	lineOn = true, fillOn = false, areaOn = true, frontOn = true, pulseOn = true,
	-- depth helpers for rings round you and cones (fx.Depth), off to start with
	wallOn = false, wallHeight = 1, bands = false, bandEvery = 5, bandNumbers = true, marks = false,
	-- guardians (Guardians.lua): a ring's warning from warnAt yd before its edge, with a line of text;
	-- the minimap's pins
	warnAt = 15, warnText = true,
	pinGuardians = true, pinBosses = true, pinCaches = true, pinTimers = true, pinEdge = true, pinSize = 14,
};

-- The two kinds of piece every shape is made of, white, tinted to its colours (SetPiece).
local SOLID, ROUND = "solid", "round";
local MAX_QUADS = 8000;
local MAX_FILL_DOTS = 600;
local MAX_STRIPS = 400;
local SOFT_CAP = 70;
local PI = 3.14159265;
local PAD = 50;            -- how far past the screen's edge a shape is still drawn

-- Static anchors first: their position never changes, so the offset can't drift.
local PRIORITY = { cache = 1, guardianLair = 2, guardian = 3, boss = 4, finalBoss = 5, elite = 6, enemy = 7 };
local KINDS = { "cache", "guardianLair", "guardian", "boss", "finalBoss", "elite", "enemy" };
local STATIC = { cache = true, guardianLair = true };

local db;

-- A line in the chat, in the game's language when it is one of the addon's own.
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: " .. AST_L(msg));
end

-- Is `v` in the list `t`?
local function In(t, v)
	if ( not t or v == nil ) then
		return false;
	end
	for i = 1, table.getn(t) do
		if ( t[i] == v ) then
			return true;
		end
	end
	return false;
end

local function Copy(v)
	if ( type(v) ~= "table" ) then
		return v;
	end
	local t = {};
	for k, x in pairs(v) do
		t[k] = Copy(x);
	end
	return t;
end

local function ErrText(err)
	if ( type(err) == "table" ) then
		return tostring(err.code) .. ": " .. tostring(err.message);
	end
	return tostring(err);
end

local function Entries(res, key)
	if ( type(res) ~= "table" ) then
		return nil;
	end
	if ( type(res[key or "entries"]) == "table" ) then
		return res[key or "entries"];
	end
	return res;
end

-- A telegraph's settings, its defaults filled in.
local function Settings(def)
	local s = db.t[def.id];
	if ( not s ) then
		s = {};
		db.t[def.id] = s;
	end
	for k, v in pairs(COMMON) do
		if ( s[k] == nil ) then
			if ( def.defaults and def.defaults[k] ~= nil ) then
				s[k] = Copy(def.defaults[k]);
			else
				s[k] = Copy(v);
			end
		end
	end
	-- an experimental one is off, even if it was on from before it was marked so (just this once:
	-- after that, on or off is yours)
	if ( def.experimental and not s.offOnce ) then
		s.enabled, s.offOnce = false, true;
	elseif ( not def.experimental and s.offOnce and not s.onAgain ) then
		-- turned off while it was experimental, and it isn't any more: on again, just this once
		s.enabled, s.onAgain = true, true;
	end
	return s;
end

local function ResetSettings(def)
	db.t[def.id] = nil;
	return Settings(def);
end

---------------------------------------------------------------------------------------------
-- Quads: every dot, strip and outline piece is one texture from this pool

local canvas = CreateFrame("Frame", "ASTCanvas", WorldFrame);
canvas:SetAllPoints(WorldFrame);
canvas:SetFrameStrata("BACKGROUND");

local pool, used, shown = {}, 0, 0;
local screenW, screenH = 1024, 768;

-- Texture `t` as a piece of `kind` (SOLID or ROUND): the game's own round mask, whole for a dot,
-- its centre (all one white) for a solid piece. The game's own, not a file of the addon's, so it
-- loads wherever the game runs: its browser version loads no texture files of an addon's.
local function SetPiece(t, kind)
	t:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask");
	if ( kind == ROUND ) then
		t:SetTexCoord(0, 1, 0, 1);
	else
		t:SetTexCoord(0.3, 0.7, 0.3, 0.7);
	end
end

local function Quad(tex, x, y, w, h, c, alpha)
	if ( used >= MAX_QUADS or x > screenW + PAD or y > screenH + PAD or x + w < -PAD or y + h < -PAD ) then
		return;
	end
	used = used + 1;
	local t = pool[used];
	if ( not t ) then
		t = canvas:CreateTexture(nil, "OVERLAY");
		pool[used] = t;
	end
	if ( t.tex ~= tex ) then
		SetPiece(t, tex);
		t.tex = tex;
	end
	local a = c[4] * alpha;
	if ( a > 1 ) then
		a = 1;
	end
	if ( t.r ~= c[1] or t.g ~= c[2] or t.b ~= c[3] or t.a ~= a ) then
		t:SetVertexColor(c[1], c[2], c[3], a);
		t.r, t.g, t.b, t.a = c[1], c[2], c[3], a;
	end
	-- a piece where it was last frame (within a third of a unit: a shape round the hero holds still
	-- on the screen) isn't moved or resized again: most of a still scene costs no calls
	if ( not t.w or math.abs(t.w - w) > 0.33 or math.abs(t.h - h) > 0.33 ) then
		t:SetWidth(w);
		t:SetHeight(h);
		t.w, t.h = w, h;
	end
	if ( not t.x or math.abs(t.x - x) > 0.33 or math.abs(t.y - y) > 0.33 ) then
		t:ClearAllPoints();
		t:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", x, y);
		t.x, t.y = x, y;
	end
	if ( not t.on ) then
		t:Show();
		t.on = true;
	end
end

local function FinishQuads()
	for i = used + 1, shown do
		local t = pool[i];
		if ( t and t.on ) then
			t:Hide();
			t.on = false;
		end
	end
	shown = used;
	used = 0;
end

---------------------------------------------------------------------------------------------
-- Ground to screen

-- The homography: yards from the hero (u, v) -> WorldFrame offsets (1 to 8), and how a height
-- shows on the screen (9 to 11: what a yard up adds to x's and y's tops and to the bottom). dz:
-- the height above (below) the hero's feet the shape being drawn is at: 0 for one that goes out
-- from the hero, the enemies' height for one on them, the ground's for a spot left there.
local H = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, dz = 0 };
-- True circles (the Lab's): H.round on; ell: the whole circle a shape began with (AddArc), which
-- FillPoly can draw as one piece; ex, ey: that circle's points on the screen.
H.round, H.ell, H.ex, H.ey, H.lod = false, { on = false, n = -1 }, {}, {}, 1;
local scale = 10;      -- screen units per yard at the hero
local anchor;          -- the entry projected from
local requests = {};
local lastError;

local function PickAnchor(p)
	local res, err = AZS_GetWorldAnchors({ kinds = KINDS }, nil, 64);
	if ( not res ) then
		res, err = AZS_GetWorldAnchors(nil, nil, 64);
	end
	local list = Entries(res);
	if ( not list ) then
		lastError = "anchor query: " .. ErrText(err);
		return nil;
	end
	local best, bestRank;
	for i = 1, table.getn(list) do
		local e = list[i];
		if ( type(e) == "table" and e.anchorId and e.positionAvailable ~= false
			and type(e.x) == "number" and type(e.y) == "number" and type(e.z) == "number"
			and ( e.spaceId == nil or p.spaceId == nil or e.spaceId == p.spaceId ) ) then
			local rank = PRIORITY[e.kind] or 99;
			if ( not best or rank < bestRank ) then
				best, bestRank = e, rank;
			end
		end
	end
	if ( not best ) then
		lastError = "no anchor with a position on this map yet";
		return nil;
	end
	return { anchorId = best.anchorId, kind = best.kind, x = best.x, y = best.y, z = best.z };
end

-- Solves the 8x8 system a * h = b (a has b as its 9th column) by elimination.
local function Solve(a)
	for col = 1, 8 do
		local pivot, best = col, math.abs(a[col][col]);
		for row = col + 1, 8 do
			if ( math.abs(a[row][col]) > best ) then
				pivot, best = row, math.abs(a[row][col]);
			end
		end
		if ( best < 1e-9 ) then
			return nil;
		end
		a[col], a[pivot] = a[pivot], a[col];
		for row = 1, 8 do
			if ( row ~= col ) then
				local f = a[row][col] / a[col][col];
				if ( f ~= 0 ) then
					for k = col, 9 do
						a[row][k] = a[row][k] - f * a[col][k];
					end
				end
			end
		end
	end
	local h = {};
	for i = 1, 8 do
		h[i] = a[i][9] / a[i][i];
	end
	return h;
end

local function Map(u, v)
	local dz = H.dz;
	local w = H[7] * u + H[8] * v + 1 + H[11] * dz;
	if ( w <= 1e-4 ) then
		return nil;   -- past the horizon
	end
	return (H[1] * u + H[2] * v + H[3] + H[9] * dz) / w, (H[4] * u + H[5] * v + H[6] + H[10] * dz) / w;
end

-- A screen point back on the ground `dz` yd above (below) the hero's feet (nil: at them).
local function Unmap(x, y, dz)
	dz = dz or 0;
	local a, b, c = H[1] - x * H[7], H[2] - x * H[8], x * (1 + H[11] * dz) - H[3] - H[9] * dz;
	local d, e, f = H[4] - y * H[7], H[5] - y * H[8], y * (1 + H[11] * dz) - H[6] - H[10] * dz;
	local det = a * e - b * d;
	if ( math.abs(det) < 1e-9 ) then
		return nil;
	end
	return (c * e - b * f) / det, (a * f - c * d) / det;
end

local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } };
-- How far out the four points go, in yards. The game gives no screen position for a point off
-- the screen, so they stay close to the hero: the mapping they fix holds for the whole ground
-- anyway. Closer still if the camera is zoomed in so far that even these are off it.
local SPANS = { 5, 2.5, 1.25 };
-- states that are the point's, not the anchor's: a smaller span may fix them
local OFF_VIEW = { offscreen = true, clipped = true, behindCamera = true };

-- The four points `s` yards around the hero, projected, and the same four 3 yd up (how a height
-- shows on the screen; those may fail): their entries, or nil and whether the anchor itself failed.
local function ProjectCorners(p, s)
	local dx, dy, dz = p.x - anchor.x, p.y - anchor.y, p.z - anchor.z;
	for i = 1, 8 do
		local r = requests[i];
		if ( not r ) then
			r = { attachment = "position", offset = {} };
			requests[i] = r;
		end
		local c = CORNERS[i > 4 and i - 4 or i];
		r.anchorId = anchor.anchorId;
		r.offset.x = dx + c[1] * s;
		r.offset.y = dy + c[2] * s;
		r.offset.z = dz + ( i > 4 and 3 or 0 );
	end
	local res, err = AZS_ProjectWorldAnchors(requests);
	local list = Entries(res);
	if ( not list ) then
		lastError = "projection: " .. ErrText(err);
		return nil, true;
	end
	for i = 1, 4 do
		local e = list[i];
		if ( type(e) ~= "table" or type(e.x) ~= "number" or type(e.y) ~= "number" or e.state == "behindCamera" ) then
			local state = type(e) == "table" and e.state;
			lastError = string.format("point %g yd from you gave no screen position (state %s, reason %s)",
				s, tostring(state), tostring(type(e) == "table" and e.reason));
			return nil, not OFF_VIEW[state];
		end
	end
	return list, false;
end

-- Fixes H for this frame from four ground points projected around the hero.
local function BuildMap(p)
	if ( not anchor or not STATIC[anchor.kind] ) then
		anchor = PickAnchor(p);
	end
	if ( not anchor ) then
		return false;
	end
	local list, s;
	for i = 1, table.getn(SPANS) do
		s = SPANS[i];
		local anchorFailed;
		list, anchorFailed = ProjectCorners(p, s);
		if ( list ) then
			break;
		elseif ( anchorFailed ) then
			-- the anchor went away (cache opened, enemy died, new map): another one next frame
			anchor = nil;
			return false;
		end
	end
	if ( not list ) then
		return false;
	end
	local a = {};
	for i = 1, 4 do
		local e = list[i];
		local u, v = CORNERS[i][1] * s, CORNERS[i][2] * s;
		a[2 * i - 1] = { u, v, 1, 0, 0, 0, -u * e.x, -v * e.x, e.x };
		a[2 * i] = { 0, 0, 0, u, v, 1, -u * e.y, -v * e.y, e.y };
	end
	local h = Solve(a);
	if ( not h ) then
		lastError = "the projected points were degenerate";
		return false;
	end
	for i = 1, 8 do
		H[i] = h[i];
	end
	-- How a height shows: for a point `lift` yd up, x * (H7 u + H8 v + 1 + H11 lift) =
	-- H1 u + H2 v + H3 + H9 lift (and so for y), a perspective camera's projection, exact. Its
	-- three numbers from the raised four (eight equations, least squares). Without them every
	-- shape is drawn at the hero's height, as it was.
	H[9], H[10], H[11], H.dz = 0, 0, 0, 0;
	local lift = requests[5].offset.z - requests[1].offset.z;
	local m11, m22, m33, m13, m23, r1, r2, r3, n = 0, 0, 0, 0, 0, 0, 0, 0, 0;
	for i = 5, 8 do
		local e = list[i];
		if ( type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" and e.state ~= "behindCamera" ) then
			local u, v = CORNERS[i - 4][1] * s, CORNERS[i - 4][2] * s;
			local w = H[7] * u + H[8] * v + 1;
			local bx = e.x * w - (H[1] * u + H[2] * v + H[3]);
			local by = e.y * w - (H[4] * u + H[5] * v + H[6]);
			-- rows (lift, 0, -x lift | bx) and (0, lift, -y lift | by)
			m11, m22 = m11 + lift * lift, m22 + lift * lift;
			m13, m23 = m13 - e.x * lift * lift, m23 - e.y * lift * lift;
			m33 = m33 + (e.x * e.x + e.y * e.y) * lift * lift;
			r1, r2, r3 = r1 + lift * bx, r2 + lift * by, r3 - (e.x * bx + e.y * by) * lift;
			n = n + 1;
		end
	end
	-- (m12 = 0; symmetric) solved by Cramer's rule
	local det = m11 * (m22 * m33 - m23 * m23) - m13 * m13 * m22;
	if ( n >= 2 and math.abs(det) > 1e-9 ) then
		H[9] = (r1 * (m22 * m33 - m23 * m23) + m13 * (r2 * m23 - m22 * r3)) / det;
		H[10] = (m11 * (r2 * m33 - m23 * r3) + m13 * (r1 * m23 - m13 * r2)) / det;
		H[11] = (m11 * (m22 * r3 - r2 * m23) - m13 * m22 * r1) / det;
	end
	local x0, y0 = Map(0, 0);
	local x1, y1 = Map(1, 0);
	local x2, y2 = Map(0, 1);
	if ( not x0 or not x1 or not x2 ) then
		return false;
	end
	scale = (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
		+ math.sqrt((x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0))) / 2;
	lastError = nil;
	return true;
end

---------------------------------------------------------------------------------------------
-- Smooth: polygons on screen, filled with strips and stroked with quads

local PX, PY, PN = {}, {}, 0;

local function Add(u, v)
	local x, y = Map(u, v);
	if ( not x ) then
		return false;
	end
	PN = PN + 1;
	PX[PN], PY[PN] = x, y;
	return true;
end

-- Points along an arc around (cu, cv), one every few screen units (up to 256 with true circles).
local function AddArc(cu, cv, r, a0, a1)
	local most = H.round and 256 or 128;
	local n = math.ceil(r * math.abs(a1 - a0) * scale / 5);
	if ( n < 4 ) then
		n = 4;
	elseif ( n > most ) then
		n = most;
	end
	-- a whole circle a shape begins with: FillPoly may draw it in one piece
	local E = H.ell;
	local full = math.abs(math.abs(a1 - a0) - 2 * PI) < 1e-3;
	E.on = PN == 0 and full;
	E.cu, E.cv, E.r = cu, cv, r;
	-- reaching past the horizon (a big ring, the camera tilted up): the part in front of it, not
	-- nothing. Its depth w along the circle is W0 + k7 cos a + k8 sin a; points nearer the horizon than
	-- w = 0.05 are left out (they'd be far off the screen anyway). A whole circle starts where it is
	-- furthest past, so the part in front is one run.
	local k7, k8 = H[7] * r, H[8] * r;
	local W0 = H[7] * cu + H[8] * cv + 1 + H[11] * H.dz;
	local K = math.sqrt(k7 * k7 + k8 * k8);
	if ( W0 - K < 0.05 ) then
		E.on = false;
		if ( W0 + K < 0.05 ) then
			return false;
		end
		if ( full ) then
			local back = math.atan2(-k8, -k7);
			a0, a1 = back, back + ( a1 > a0 and 2 * PI or -2 * PI );
		end
		local added = 0;
		for i = 0, n do
			local a = a0 + (a1 - a0) * i / n;
			local ca, sa = math.cos(a), math.sin(a);
			if ( W0 + k7 * ca + k8 * sa >= 0.05 and Add(cu + r * ca, cv + r * sa) ) then
				added = added + 1;
			end
		end
		return added >= 2;
	end
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n;
		if ( not Add(cu + r * math.cos(a), cv + r * math.sin(a)) ) then
			E.on = false;
			return false;
		end
	end
	E.n = PN;
	return true;
end

-- A whole circle on the ground as one stretched round piece: exact when it shows on the screen as an
-- upright ellipse (round the hero it does); false when it doesn't (at a slant, off to one side, or
-- partly past the horizon), and the caller fills it with strips instead.
H.Ellipse = function(cu, cv, r, c, alpha)
	local xs, ys = H.ex, H.ey;
	local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9;
	for i = 1, 24 do
		local a = (i - 1) * PI / 12;
		local x, y = Map(cu + r * math.cos(a), cv + r * math.sin(a));
		if ( not x ) then
			return false;
		end
		xs[i], ys[i] = x, y;
		x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y);
	end
	local cx, cy, ax, ay = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2;
	if ( ax < 1 or ay < 1 ) then
		return false;
	end
	-- upright: each point within three quarters of a unit of the ellipse in that box
	local big = math.max(ax, ay);
	for i = 1, 24 do
		local dx, dy = (xs[i] - cx) / ax, (ys[i] - cy) / ay;
		if ( math.abs(math.sqrt(dx * dx + dy * dy) - 1) * big > 0.75 ) then
			return false;
		end
	end
	Quad(ROUND, x0, y0, x1 - x0, y1 - y0, c, alpha);
	return true;
end

local BK = {};

-- Fills the polygon PX/PY (even-odd) with horizontal strips `strip` units tall.
local function FillPoly(c, alpha, strip)
	if ( PN < 3 or c[4] * alpha <= 0.003 ) then
		return;
	end
	if ( H.round ) then
		-- true circles: a whole circle in one piece; anything else in finer strips
		local E = H.ell;
		if ( E.on and E.n == PN and H.Ellipse(E.cu, E.cv, E.r, c, alpha) ) then
			return;
		end
	end
	local ymin, ymax = PY[1], PY[1];
	for i = 2, PN do
		local y = PY[i];
		if ( y < ymin ) then
			ymin = y;
		elseif ( y > ymax ) then
			ymax = y;
		end
	end
	if ( ymin < 0 ) then
		ymin = 0;
	end
	if ( ymax > screenH ) then
		ymax = screenH;
	end
	if ( ymax <= ymin ) then
		return;
	end
	local s = strip;
	if ( (ymax - ymin) / s > MAX_STRIPS ) then
		s = (ymax - ymin) / MAX_STRIPS;
	end
	local k0, k1 = math.floor(ymin / s), math.floor(ymax / s);
	for k = 1, k1 - k0 + 1 do
		local b = BK[k];
		if ( b ) then
			b.n = 0;
		else
			BK[k] = { n = 0 };
		end
	end
	for i = 1, PN do
		local j = i + 1;
		if ( j > PN ) then
			j = 1;
		end
		local x1, y1, x2, y2 = PX[i], PY[i], PX[j], PY[j];
		if ( y1 ~= y2 ) then
			if ( y1 > y2 ) then
				x1, y1, x2, y2 = x2, y2, x1, y1;
			end
			-- the strips whose middle, (k + 0.5) s, lies in [y1, y2)
			local ka, kb = math.ceil(y1 / s - 0.5), math.ceil(y2 / s - 0.5) - 1;
			if ( ka < k0 ) then
				ka = k0;
			end
			if ( kb > k1 ) then
				kb = k1;
			end
			local slope = (x2 - x1) / (y2 - y1);
			for k = ka, kb do
				local b = BK[k - k0 + 1];
				b.n = b.n + 1;
				b[b.n] = x1 + ((k + 0.5) * s - y1) * slope;
			end
		end
	end
	for k = k0, k1 do
		local b = BK[k - k0 + 1];
		local n = b.n;
		if ( n >= 2 ) then
			for i = 2, n do
				local v, j = b[i], i - 1;
				while ( j >= 1 and b[j] > v ) do
					b[j + 1] = b[j];
					j = j - 1;
				end
				b[j + 1] = v;
			end
			for i = 1, n - 1, 2 do
				local xa, xb = b[i], b[i + 1];
				if ( xa < -PAD ) then
					xa = -PAD;
				end
				if ( xb > screenW + PAD ) then
					xb = screenW + PAD;
				end
				if ( xb > xa ) then
					Quad(SOLID, xa, k * s, xb - xa, s, c, alpha);
				end
			end
		end
	end
end

-- One stroke piece from (x1, y1) to (x2, y2), `w` wide, as runs of quads along its long axis.
-- Each run climbs at most 3 units, so a thick stroke's edge is as fine as a thin one's.
local function Segment(x1, y1, x2, y2, c, alpha, w, cap1, cap2)
	local dx, dy = x2 - x1, y2 - y1;
	local hw = w * 0.5;
	local rise = math.min(w, 3);
	if ( math.abs(dx) >= math.abs(dy) ) then
		if ( dx < 0 ) then
			x1, y1, x2, y2, dx, dy, cap1, cap2 = x2, y2, x1, y1, -dx, -dy, cap2, cap1;
		end
		local n = math.ceil(math.abs(dy) / rise);
		if ( n < 1 ) then
			n = 1;
		end
		for i = 0, n - 1 do
			local xa, xb = x1 + dx * i / n, x1 + dx * (i + 1) / n;
			if ( i == 0 and cap1 ) then
				xa = xa - hw;
			end
			if ( i == n - 1 and cap2 ) then
				xb = xb + hw;
			end
			Quad(SOLID, xa, y1 + dy * (i + 0.5) / n - hw, xb - xa, w, c, alpha);
		end
	else
		if ( dy < 0 ) then
			x1, y1, x2, y2, dx, dy, cap1, cap2 = x2, y2, x1, y1, -dx, -dy, cap2, cap1;
		end
		local n = math.ceil(math.abs(dx) / rise);
		if ( n < 1 ) then
			n = 1;
		end
		for i = 0, n - 1 do
			local ya, yb = y1 + dy * i / n, y1 + dy * (i + 1) / n;
			if ( i == 0 and cap1 ) then
				ya = ya - hw;
			end
			if ( i == n - 1 and cap2 ) then
				yb = yb + hw;
			end
			Quad(SOLID, x1 + dx * (i + 0.5) / n - hw, ya, w, yb - ya, c, alpha);
		end
	end
end

-- Is the turn at point i sharp enough to need its corner covered?
local function Sharp(i, closed)
	local p, n = i - 1, i + 1;
	if ( p < 1 ) then
		if ( not closed ) then
			return true;
		end
		p = PN;
	end
	if ( n > PN ) then
		if ( not closed ) then
			return true;
		end
		n = 1;
	end
	local ax, ay, bx, by = PX[i] - PX[p], PY[i] - PY[p], PX[n] - PX[i], PY[n] - PY[i];
	local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by);
	if ( la < 1e-6 or lb < 1e-6 ) then
		return false;
	end
	return (ax * bx + ay * by) / (la * lb) < 0.8;
end

-- True circles' wide see-through strokes (a glow): the band either side of the line, filled with
-- strips 3 units tall (soft and faint: the steps don't show), as overlapping round pieces would
-- show their overlaps as blobs. PX/PY are
-- put back after, for the stroke drawn over it. False when there's nothing to fill.
H.sx, H.sy, H.ox, H.oy, H.ix, H.iy = {}, {}, {}, {}, {}, {};
H.Band = function(closed, c, alpha, w)
	local n = PN;
	if ( n < 2 ) then
		return false;
	end
	local sx, sy, ox, oy, ix, iy = H.sx, H.sy, H.ox, H.oy, H.ix, H.iy;
	for i = 1, n do
		sx[i], sy[i] = PX[i], PY[i];
	end
	local hw = w / 2;
	for i = 1, n do
		local p = i > 1 and i - 1 or ( closed and n or i );
		local q = i < n and i + 1 or ( closed and 1 or i );
		local dx, dy = sx[q] - sx[p], sy[q] - sy[p];
		local l = math.sqrt(dx * dx + dy * dy);
		if ( l < 1e-6 ) then
			dx, dy, l = 1, 0, 1;
		end
		local nx, ny = -dy / l * hw, dx / l * hw;
		ox[i], oy[i], ix[i], iy[i] = sx[i] + nx, sy[i] + ny, sx[i] - nx, sy[i] - ny;
	end
	-- one side, then back along the other (closed: the two loops joined by a step taken both ways,
	-- which the even-odd fill cancels)
	PN = 0;
	for i = 1, n do
		PN = PN + 1;
		PX[PN], PY[PN] = ox[i], oy[i];
	end
	if ( closed ) then
		PN = PN + 1;
		PX[PN], PY[PN] = ox[1], oy[1];
		PN = PN + 1;
		PX[PN], PY[PN] = ix[1], iy[1];
		for i = n, 2, -1 do
			PN = PN + 1;
			PX[PN], PY[PN] = ix[i], iy[i];
		end
		PN = PN + 1;
		PX[PN], PY[PN] = ix[1], iy[1];
	else
		for i = n, 1, -1 do
			PN = PN + 1;
			PX[PN], PY[PN] = ix[i], iy[i];
		end
	end
	H.ell.on = false;
	FillPoly(c, alpha, 3);
	for i = 1, n do
		PX[i], PY[i] = sx[i], sy[i];
	end
	PN = n;
	return true;
end

-- Strokes the polyline PX/PY (closed: back to its first point). True circles: round pieces close
-- together along it, so it bends smoothly; each piece's opacity is such that the overlap of about
-- w / step of them gives the stroke's, its edges fading off as they thin out.
local function Stroke(closed, c, alpha, w)
	if ( PN < 2 or c[4] * alpha <= 0.003 ) then
		return;
	end
	if ( H.round ) then
		local last = closed and PN or PN - 1;
		-- how long it is on the screen (a big ring mostly off it costs only its part on it)
		local total, lo, hiX, hiY = 0, -PAD, screenW + PAD, screenH + PAD;
		for i = 1, last do
			local j = i < PN and i + 1 or 1;
			local x1, y1, x2, y2 = PX[i], PY[i], PX[j], PY[j];
			if ( not ( ( x1 < lo and x2 < lo ) or ( x1 > hiX and x2 > hiX ) or ( y1 < lo and y2 < lo ) or ( y1 > hiY and y2 > hiY ) ) ) then
				total = total + math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
			end
		end
		-- a wide see-through stroke (a glow) is filled as a band: round pieces would only look even a
		-- quarter of a width apart. Unless the band costs more than twice that (a big ring mostly off
		-- the screen still spans it all): one strip piece a side for each 3 units it spans
		if ( w >= 7 and c[4] * alpha < 0.999 ) then
			local y0, y1 = PY[1], PY[1];
			for i = 2, PN do
				y0, y1 = math.min(y0, PY[i]), math.max(y1, PY[i]);
			end
			local rows = (math.min(y1 + w, screenH) - math.max(y0 - w, 0)) / 3;
			if ( rows * ( closed and 2 or 1 ) <= 2 * total / (w * 0.25) and H.Band(closed, c, alpha, w) ) then
				return;
			end
		end
		-- Each piece is round, or stretched along the line where it runs near level or upright and
		-- bends gently: up to 4 widths long, as long as the line, tilted off the stretch, stays within
		-- a tenth of its width and the bend keeps the piece's ends within a quarter unit of the curve.
		-- Pieces are 0.6 of their length apart (0.5 when see-through, so their overlaps even out); a
		-- crowded frame (H.lod, from the last one's count) spreads them up to 0.75; at most 1000.
		local a = math.min(1, c[4] * alpha);
		local gap = math.min(0.75, (a >= 0.999 and 0.6 or 0.5) * H.lod);
		local least = math.max(0.75, total / 1000);
		local t, hw = 0, w / 2;
		for i = 1, last do
			local j = i < PN and i + 1 or 1;
			local x1, y1 = PX[i], PY[i];
			local x2, y2 = PX[j], PY[j];
			local dx, dy = x2 - x1, y2 - y1;
			local len = math.sqrt(dx * dx + dy * dy);
			local L = w;
			local flat = math.abs(dx) >= math.abs(dy);
			if ( len > 1e-6 ) then
				local off = flat and dy / len or dx / len;
				local s2 = off * off;
				local e = s2 > 1e-6 and math.sqrt(1 + 0.21 / s2) or 4;
				-- the bend into the next piece of the line
				local k = j < PN and j + 1 or ( closed and 1 or nil );
				if ( k and ( closed or j < PN ) ) then
					local ex, ey = PX[k] - x2, PY[k] - y2;
					local len2 = math.sqrt(ex * ex + ey * ey);
					local turn = len2 > 1e-6 and math.abs(dx * ey - dy * ex) / (len * len2) or 0;
					if ( turn > 1e-4 ) then
						e = math.min(e, math.sqrt(2 * len / turn) / w);
					end
				end
				L = w * math.max(1, math.min(4, e));
			end
			local step = math.max(least, L * gap);
			local per = a >= 0.999 and 1 / c[4] or (1 - math.pow(1 - a, step / L)) / c[4];
			if ( ( x1 < lo and x2 < lo ) or ( x1 > hiX and x2 > hiX ) or ( y1 < lo and y2 < lo ) or ( y1 > hiY and y2 > hiY ) ) then
				-- off the screen: past it, keeping the spacing
				if ( t <= len ) then
					t = t + math.ceil((len - t) / step + 1e-9) * step;
				end
			else
				local hl = L / 2;
				while ( t <= len ) do
					local f = len > 0 and t / len or 0;
					local px, py = x1 + dx * f, y1 + dy * f;
					if ( flat ) then
						Quad(ROUND, px - hl, py - hw, L, w, c, per);
					else
						Quad(ROUND, px - hw, py - hl, w, L, c, per);
					end
					t = t + step;
				end
			end
			t = t - len;
		end
		local per = a >= 0.999 and 1 / c[4] or (1 - math.pow(1 - a, 0.5)) / c[4];
		if ( not closed ) then
			Quad(ROUND, PX[PN] - hw, PY[PN] - hw, w, w, c, per);
		end
		return;
	end
	local last = PN - 1;
	if ( closed ) then
		last = PN;
	end
	for i = 1, last do
		local j = i + 1;
		if ( j > PN ) then
			j = 1;
		end
		Segment(PX[i], PY[i], PX[j], PY[j], c, alpha, w, Sharp(i, closed), Sharp(j, closed));
	end
end

-- Outline with its glow under it.
local function Outline(closed, st, alpha, wide)
	local w = st.width * (wide or 1);
	if ( st.glow ) then
		Stroke(closed, st.line, alpha * 0.22, w * 3);
	end
	if ( st.lineOn ~= false ) then
		Stroke(closed, st.line, alpha, w);
	end
end

local function Bright(c)
	return { math.min(1, c[1] * 0.4 + 0.6), math.min(1, c[2] * 0.4 + 0.6), math.min(1, c[3] * 0.4 + 0.6), 1 };
end

---------------------------------------------------------------------------------------------
-- Dots

local function Dot(x, y, c, alpha, size)
	Quad(ROUND, x - size / 2, y - size / 2, size, size, c, alpha);
end

local function DotArc(cu, cv, r, a0, a1, c, alpha, size, spacing)
	if ( r <= 0 ) then
		return;
	end
	local n = math.ceil(r * math.abs(a1 - a0) * scale / spacing);
	if ( n < 2 ) then
		n = 2;
	end
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n;
		local x, y = Map(cu + r * math.cos(a), cv + r * math.sin(a));
		if ( x ) then
			Dot(x, y, c, alpha, size);
		end
	end
end

local function DotRay(r, a, c, alpha, st)
	local n = math.ceil(r * scale / st.spacing);
	local ca, sa = math.cos(a), math.sin(a);
	for i = 1, n do
		local d = r * i / n;
		local x, y = Map(d * ca, d * sa);
		if ( x ) then
			Dot(x, y, c, alpha, st.size);
		end
	end
end

-- Concentric arcs from the middle out to `front`: the Dots style's fill.
local function DotFill(cu, cv, front, a0, a1, st, alpha)
	-- a filled sector of radius R at spacing s takes about angle * (R / s)^2 / 2 dots: widen the
	-- spacing when zoomed in, so the fill stays under MAX_FILL_DOTS
	local spacing = math.max(st.fillSpacing, front * scale * math.sqrt(math.abs(a1 - a0) / 2 / MAX_FILL_DOTS));
	if ( st.fillStyle == "solid" and st.fillOn ~= false ) then
		local step = spacing / scale;
		local r = step;
		while ( r < front - step * 0.5 ) do
			DotArc(cu, cv, r, a0, a1, st.fill, alpha, st.size, spacing);
			r = r + step;
		end
	end
	if ( st.frontOn ~= false ) then
		DotArc(cu, cv, front, a0, a1, Bright(st.fill), alpha, st.size, st.spacing);
	end
end

---------------------------------------------------------------------------------------------
-- Telegraphs

-- job: def, st, alpha, size, facing, progress (0..1, the cooldown), since (seconds since a cast).
-- Each part only when its setting has it: the outline (lineOn, glow), the fill (fillOn), the faint
-- area still to fill (areaOn), the fill's front line (frontOn), a cast's pulse (pulseOn).
local function DrawCone(job)
	local st, alpha, L = job.st, job.alpha, job.size;
	local h = job.def.halfAngle * PI / 180;
	local a0, a1 = job.facing - h, job.facing + h;
	local p = job.progress;
	local fill, area, front = st.fillOn ~= false, st.areaOn ~= false, st.frontOn ~= false;
	local pulse = 0;
	if ( job.since and job.since < 0.35 and st.pulseOn ~= false ) then
		pulse = 1 - job.since / 0.35;
	end
	if ( st.style == "dots" ) then
		if ( st.lineOn ~= false ) then
			local x, y = Map(0, 0);
			if ( x ) then
				Dot(x, y, st.line, alpha, st.size);
			end
			DotRay(L, a0, st.line, alpha, st);
			DotRay(L, a1, st.line, alpha, st);
			DotArc(0, 0, L, a0, a1, st.line, alpha, st.size, st.spacing);
		end
		if ( p and p > 0 ) then
			DotFill(0, 0, L * p, a0, a1, st, alpha);
		end
		return;
	end
	if ( p ) then
		-- what is still to fill, faint (the band from the fill's front out); what has filled, full
		if ( p < 1 and area ) then
			PN = 0;
			local ok = AddArc(0, 0, L, a0, a1);
			if ( ok and p > 0 ) then
				ok = AddArc(0, 0, L * p, a1, a0);
			elseif ( ok ) then
				ok = Add(0, 0);
			end
			if ( ok ) then
				FillPoly(st.fill, alpha * 0.35, st.strip);
			end
		end
		PN = 0;
		if ( fill and p > 0 and Add(0, 0) and AddArc(0, 0, L * p, a0, a1) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	elseif ( fill ) then
		PN = 0;
		if ( Add(0, 0) and AddArc(0, 0, L, a0, a1) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	end
	PN = 0;
	if ( Add(0, 0) and AddArc(0, 0, L, a0, a1) ) then
		Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	if ( front and p and p > 0 and p < 1 ) then
		PN = 0;
		if ( AddArc(0, 0, L * p, a0, a1) ) then
			Stroke(false, Bright(st.fill), alpha, st.width);
		end
	end
end

-- A ring at (cu, cv) yards from the hero: filled, outlined, `progress` filling it from the centre
-- out; each part as DrawCone has them.
local function DrawCircleAt(cu, cv, R, st, alpha, p, since)
	local fill, area, front, pulsing = st.fillOn ~= false, st.areaOn ~= false, st.frontOn ~= false, st.pulseOn ~= false;
	local pulse = 0;
	if ( since and since < 0.35 and pulsing ) then
		pulse = 1 - since / 0.35;
	end
	if ( st.style == "dots" ) then
		if ( st.lineOn ~= false ) then
			DotArc(cu, cv, R, 0, 2 * PI, st.line, alpha, st.size, st.spacing);
		end
		if ( p and p > 0 ) then
			DotFill(cu, cv, R * p, 0, 2 * PI, st, alpha);
		elseif ( not p and st.fill[4] > 0 and fill ) then
			DotFill(cu, cv, R, 0, 2 * PI, st, alpha * 0.5);
		end
		if ( pulsing and since and since < 0.4 ) then
			DotArc(cu, cv, R * (0.3 + 0.7 * since / 0.4), 0, 2 * PI, Bright(st.line), alpha * (1 - since / 0.4), st.size, st.spacing);
		end
		return;
	end
	if ( p ) then
		-- the whole area faint, what has filled full, and the fill's front a bright ring
		PN = 0;
		if ( area and p < 1 and AddArc(cu, cv, R, 0, 2 * PI) ) then
			FillPoly(st.fill, alpha * 0.35, st.strip);
		end
		PN = 0;
		if ( fill and p > 0 and AddArc(cu, cv, R * p, 0, 2 * PI) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
		PN = 0;
		if ( front and p > 0 and p < 1 and AddArc(cu, cv, R * p, 0, 2 * PI) ) then
			Stroke(true, Bright(st.fill), alpha, st.width);
		end
	elseif ( fill ) then
		PN = 0;
		if ( AddArc(cu, cv, R, 0, 2 * PI) ) then
			FillPoly(st.fill, alpha * (1 + pulse), st.strip);
		end
	end
	PN = 0;
	if ( AddArc(cu, cv, R, 0, 2 * PI) ) then
		Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	-- a cast: a shockwave runs out to the edge
	if ( pulsing and since and since < 0.4 ) then
		PN = 0;
		if ( AddArc(cu, cv, R * (0.3 + 0.7 * since / 0.4), 0, 2 * PI) ) then
			Stroke(true, Bright(st.line), alpha * (1 - since / 0.4), st.width * 1.5);
		end
	end
end

-- A spot on the ground that lasts: its whole area faint, filled from the centre out as its time
-- runs (grow 0 to 1); each part as DrawCone has them.
local function DrawSpot(cu, cv, R, st, alpha, grow)
	if ( st.style == "dots" ) then
		if ( st.lineOn ~= false ) then
			DotArc(cu, cv, R, 0, 2 * PI, st.line, alpha, st.size, st.spacing);
		end
		if ( grow > 0 ) then
			DotFill(cu, cv, R * grow, 0, 2 * PI, st, alpha);
		end
		return;
	end
	PN = 0;
	if ( st.areaOn ~= false and grow < 1 and AddArc(cu, cv, R, 0, 2 * PI) ) then
		FillPoly(st.fill, alpha * 0.35, st.strip);
	end
	PN = 0;
	if ( st.fillOn ~= false and grow > 0 and AddArc(cu, cv, R * grow, 0, 2 * PI) ) then
		FillPoly(st.fill, alpha, st.strip);
	end
	PN = 0;
	if ( AddArc(cu, cv, R, 0, 2 * PI) ) then
		Outline(true, st, alpha, 1);
	end
end

---------------------------------------------------------------------------------------------
-- Sizes: the action bar tooltip first (it has every bonus), the formula if it can't be read

local made, scan = pcall(CreateFrame, "GameTooltip", "ASTScanTip", nil);
if ( not made ) then
	scan = nil;
end
for i = 1, 30 do
	if ( scan and not getglobal("ASTScanTipTextLeft" .. i) ) then
		local l = scan:CreateFontString("ASTScanTipTextLeft" .. i, "ARTWORK", "GameFontNormal");
		local r = scan:CreateFontString("ASTScanTipTextRight" .. i, "ARTWORK", "GameFontNormal");
		if ( scan.AddFontStrings ) then
			pcall(scan.AddFontStrings, scan, l, r);
		end
	end
end

-- A tooltip's lines, as scan[method](a, b) fills it: SetAction(slot), SetInventoryItem("player", slot)...
local function TipLines(method, a, b)
	if ( not scan or not scan[method] ) then
		return nil;
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE");
	scan:ClearLines();
	local ok = pcall(scan[method], scan, a, b);
	if ( not ok ) then
		return nil;
	end
	local lines = {};
	local n = scan.NumLines and scan:NumLines() or 30;
	for i = 1, n do
		local fs = getglobal("ASTScanTipTextLeft" .. i);
		local text = fs and fs:GetText();
		if ( text ) then
			table.insert(lines, text);
		end
	end
	scan:Hide();
	return lines;
end

local function ScanAction(slot)
	return TipLines("SetAction", slot);
end

-- Tooltip reads: tipSize by def id { value, slot }; nextFullScan by def id; readAt: def id ->
-- when its tooltip size was last read.
local tips = { tipSize = {}, nextFullScan = {}, readAt = {} };

local function ReadSize(def, now)
	local c = tips.tipSize[def.id];
	if ( not c ) then
		c = {};
		tips.tipSize[def.id] = c;
	end
	local function TryRead(slot)
		if ( HasAction and not HasAction(slot) ) then
			return false;
		end
		local lines = ScanAction(slot);
		if ( not lines or not lines[1] ) then
			return false;
		end
		-- its name and its texts as the game shows them in its language
		local mine = false;
		for i = 1, table.getn(def.tipNames) do
			if ( lines[1] == def.tipNames[i] or lines[1] == AST_GameName(def.tipNames[i]) ) then
				mine = true;
			end
		end
		if ( not mine ) then
			return false;
		end
		local sizes, lasts = AST_Patterns(def.sizePattern), def.durationPattern and AST_Patterns(def.durationPattern);
		for i = 2, table.getn(lines) do
			for p = 1, table.getn(sizes) do
				local _, _, v = string.find(lines[i], sizes[p]);
				if ( AST_Number(v) ) then
					c.value, c.slot = AST_Number(v), slot;
					-- how long it lasts, for a spot on the ground: the first the size's line gives
					-- after the size, else any line's
					local d;
					for k = 1, table.getn(lasts or {}) do
						_, _, d = string.find(lines[i], lasts[k]);
						for l = 2, table.getn(lines) do
							if ( not d ) then
								_, _, d = string.find(lines[l], lasts[k]);
							end
						end
						if ( d ) then
							break;
						end
					end
					c.duration = AST_Number(d) or c.duration;
					return true;
				end
			end
		end
		return false;
	end
	if ( c.slot and TryRead(c.slot) ) then
		return;
	end
	c.slot = nil;
	if ( now < (tips.nextFullScan[def.id] or 0) ) then
		return;
	end
	tips.nextFullScan[def.id] = now + 5;
	for slot = 1, 120 do
		if ( TryRead(slot) ) then
			return;
		end
	end
	-- not on the bar any more: the formula takes over
	c.value = nil;
end

-- Talent ranks by name ("shadowreach"), from the client's talent list (ReadTalents fills it).
local talentRanks = {};
-- What your hero has: its talents and jewelry off the meter's loadout, and per key the numbers
-- its item's text states (RefreshOwned fills it)
-- (loadoutRead: the meter's talent list was read this run; freeGoes: def id -> the free goes of
-- its spell seen while it wasn't, see ProcHits)
local owned = { at = -100, keys = {}, from = {}, caps = {}, radii = {}, areas = {}, durs = {}, freeGoes = {} };

local function TalentRank(key, now)
	if ( not key ) then
		return 0;
	end
	local rank = talentRanks[string.lower((string.gsub(key, "[^%w]", "")))];
	if ( rank ) then
		return rank;
	end
	return 0;
end

-- A telegraph's size in yards and where it came from. `has` is the key that gives an effect,
-- for effects whose size depends on which one it is; `stated` the radius its item's text gives.
local function SizeOf(def, st, now, has, stated)
	if ( not def.sizePattern and not def.radius and not def.radii and not def.sizeOf and not def.base ) then
		return st.radius, "your setting";
	end
	if ( st.length and st.length > 0 ) then
		return st.length, "your override";
	end
	local other = def.sizeOf and byId[def.sizeOf];
	if ( other ) then
		-- another spell's size: Chastise's novas are your Holy Nova
		return SizeOf(other, Settings(other), now), other.name .. "'s size";
	elseif ( stated ) then
		return stated, "item text";
	elseif ( def.radii ) then
		return def.radii[has] or 10, def.sizeLabel or "fixed";
	elseif ( def.radius ) then
		return def.radius, def.sizeLabel or "fixed";
	end
	local c = tips.tipSize[def.id];
	if ( c and c.value ) then
		return c.value, "tooltip";
	elseif ( not def.base ) then
		return st.radius, "your setting";
	end
	local area = def.unscaled and 1 or (AZS_STATS and tonumber(AZS_STATS.area)) or 1;
	local more = def.areaItem and owned.areas[def.areaItem] or 0;
	local l = def.base * area * (1 + more / 100) * (1 + (def.reachPerRank or 0) * TalentRank(def.reachTalent, now));
	if ( l > SOFT_CAP ) then
		l = SOFT_CAP + 10 * math.log(1 + (l - SOFT_CAP) / 10);
	end
	return l, "formula";
end

-- How long a spot on the ground lasts, start to end. The spell lasts 1.4 x its own duration
-- (recDuration) x its bonuses, and its tooltip says so with every bonus, but from 9.95 sec up as a
-- whole number: the formula with the "+N% duration" of the item that gives one (durationItem) when
-- it rounds to the tooltip's, else the tooltip's. A spot ticks on `tail` sec more (0.3, its last
-- tick 0.25 sec after the time is up; a totem 0).
local function DurationOf(def)
	local t = tips.tipSize[def.id];
	local tip = (t and t.duration) or def.duration or 5;
	local d = tip;
	if ( def.recDuration ) then
		local more = def.durationItem and owned.durs[def.durationItem] or 0;
		local f = 1.4 * def.recDuration * (1 + more / 100);
		if ( math.abs(f - tip) < ( tip >= 9.95 and 0.5 or 0.05 ) + 0.001 ) then
			d = f;
		end
	end
	return d + (def.tail or 0.3);
end

---------------------------------------------------------------------------------------------
-- Cooldowns and casts, off the server's AZSSPELLS line ({ key, spell, rank, cd, cdmax })

local cds = {};        -- by spell key: { left, max, castAt, up, down, lineCd, lineAt }
local lastLine, lastRun;
-- The telegraphs' clock is GetTime() less clockGap: it stands still while the game does
-- (choosing an upgrade or a chest, the pause screen), so nothing fills or runs out meanwhile.
-- A time GetTime() gave a moment ago is on it less clockGap too.
local clockGap = 0;
local spellKeys = "none yet";   -- the keys the last line listed, for the options window

-- "mind_flay", "Mind Flay" and "mindflay" are the same spell. Letters past ASCII stay (names in
-- the game's other languages) as they are: only ASCII spaces, controls and punctuation go, and
-- only A to Z is lowered (string.lower and %p follow the system's code page, which would turn
-- a UTF-8 byte into another).
local function Norm(k)
	local s = string.gsub(tostring(k or ""), "[\1-\32\127!\"#$%%&'()*+,%-./:;<=>?@%[\\%]%^_`{|}~]", "");
	return (string.gsub(s, "[A-Z]", function(c) return string.char(string.byte(c) + 32); end));
end

local function SpellOf(def)
	if ( not def.spellKey ) then
		return nil;
	end
	return cds[Norm(def.spellKey)] or cds[Norm(def.name)];
end

local function UpdateCooldowns(now, dt, playing)
	-- A new run starts with whatever spells it rolled: nothing carries over, and the spells line
	-- is read again, as it may have come just before the run did.
	local run = AZS_ZONE and AZS_ZONE.run;
	if ( run ~= lastRun ) then
		lastRun = run;
		cds = {};
		lastLine = nil;
	end
	if ( AZS_SPELLS_UPDATED and AZS_SPELLS_UPDATED ~= lastLine ) then
		lastLine = AZS_SPELLS_UPDATED;
		local list = AZS_SPELLS or {};
		local have, keys = {}, {};
		-- when the line came: it comes as it changes, so a cast's comes with the cast
		local came = (tonumber(AZS_SPELLS_UPDATED) or (now + clockGap)) - clockGap;
		for i = 1, table.getn(list) do
			local e = list[i];
			table.insert(keys, tostring(e.key) .. " r" .. tostring(e.rank));
			local cd, mx = tonumber(e.cd), tonumber(e.cdmax);
			if ( e.key and cd and mx and mx > 0 and (tonumber(e.rank) or 1) > 0 ) then
				local key = Norm(e.key);
				have[key] = true;
				local c = cds[key];
				if ( not c ) then
					c = { up = 0, down = 0 };
					cds[key] = c;
				end
				-- Which way does `cd` run? Between two close lines it moves with the clock: down if it
				-- is the time left (the usual), up if it is the time gone. Only two lines well inside
				-- the cooldown tell: a ready spell with nothing in reach retries every 0.2 sec, its
				-- lines' cd a sawtooth under 0.2 that would count "up" as often as not and, over a
				-- run's waits, turn the spell over (its casts then missed, its retries taken for casts).
				-- And only two lines less than half a cooldown apart: two either side of a cast look just
				-- like time gone when they are about half a cooldown apart (0.6 left, then 1.15 left of
				-- 1.8 half a second on; it went off in between). With a short cooldown (Haste, cards) and
				-- a line about once a second, most pairs are like that: Blizzard's and Flamestrike's
				-- spots stopped after a few casts until a /reload.
				if ( c.lineCd and now - c.lineAt < 1.5 and now - c.lineAt >= 0.2 and now - c.lineAt <= 0.45 * mx - 0.2
					and math.min(cd, c.lineCd) >= 0.5 and math.abs(cd - c.lineCd) >= 0.15 ) then
					local d, t = cd - c.lineCd, now - c.lineAt;
					if ( d < -0.02 and math.abs(-d - t) < 0.3 ) then
						c.down = c.down + 1;
					elseif ( d > 0.02 and math.abs(d - t) < 0.3 ) then
						c.up = c.up + 1;
					end
				end
				c.lineCd, c.lineAt = cd, now;
				local left = cd;
				if ( c.up > c.down + 3 ) then
					left = mx - cd;
				end
				-- the ground spells' lines, into the trail /ast debug saves: a jump up at once, else once a second
				local T = AST.trail;
				if ( T and T.keys[key] and ( not T.seen[key] or now - T.seen[key] >= 1 or ( c.left and left > c.left + 0.1 ) ) ) then
					T.seen[key] = now;
					AST.Trail(now, string.format("line %s cd %.2f max %.2f left %.2f was %s up %d down %d%s%s%s", key, cd, mx, left,
						c.left and string.format("%.2f", c.left) or "-", c.up, c.down, c.waits and " waits" or "",
						c.guessed and " guessed" or "", c.armed and " armed" or ""));
				end
				if ( c.left and left > c.left + 0.25 and left >= 0.5 * mx ) then
					-- the cooldown started again: a cast (unless the local clock already called it). A
					-- short wait while it is ready (a retry with nothing in range) is not one.
					-- a cast the line shows (sureAt): what a spot on the ground goes by. It went off
					-- when the line came, less what the cooldown shows run already (to the tenth).
					c.sureAt = came - math.min(1, math.max(0, mx - left));
					c.cameAt, c.ran = came, math.max(0, mx - left);
					if ( AST.trail and AST.trail.keys[key] ) then
						AST.Trail(now, string.format("cast %s seen by the line, at %.2f", key, c.sureAt));
					end
					if ( not c.castAt or now - c.castAt > 0.4 ) then
						c.castAt = now;
					end
					if ( c.guessed ) then
						-- it went off later than the local clock guessed: it waited for enemies
						c.waits = true;
					end
					c.armed, c.guessed = true, nil;
				elseif ( c.guessed and left >= c.max - (now - c.guessed) - 0.5 ) then
					-- the local clock's cast was right: the line counts down with it. The line still
					-- says best when it went off.
					c.guessed = nil;
					c.sureAt = came - math.min(1, math.max(0, mx - left));
					c.cameAt, c.ran = came, math.max(0, mx - left);
					if ( AST.trail and AST.trail.keys[key] ) then
						AST.Trail(now, string.format("cast %s guessed and the line agrees, at %.2f", key, c.sureAt));
					end
				elseif ( c.guessed and now - c.guessed > 0.3 ) then
					-- it wasn't: this spell waits for enemies in range once ready (Psychic Scream), so
					-- for the rest of the run only the line says when it goes off. It's ready now.
					c.waits, c.guessed = true, nil;
					left = 0;
					if ( AST.trail and AST.trail.keys[key] ) then
						AST.Trail(now, "waits " .. key .. ": its guessed cast didn't come");
					end
				elseif ( c.left and c.left <= 0.05 and left < 0.5 * mx ) then
					-- ready and waiting for an enemy in range: the line's short retries don't count it
					-- down again, so the cooldown fill stays full
					left = 0;
				end
				c.left, c.max, c.seen = left, mx, now;
			end
		end
		spellKeys = table.getn(keys) > 0 and table.concat(keys, ", ") or "an empty list";
		-- a spell the line no longer lists is one the hero doesn't have: its telegraph goes
		for key in pairs(cds) do
			if ( not have[key] ) then
				cds[key] = nil;
			end
		end
	end
	if ( playing ) then
		for key, c in pairs(cds) do
			if ( c.left ) then
				local before = c.left;
				c.left = c.left - dt;
				if ( before > 0 and c.left <= 0 and c.armed and not c.waits
					and ( not c.guessed or c.lineAt < c.guessed ) ) then
					-- ready after a cast: most spells go off again at once, so the fill starts over
					-- now rather than when the next line says so (a guess no line has answered yet
					-- doesn't hold the next one back)
					c.castAt, c.guessed = now, now;
					c.left = c.left + c.max;
				elseif ( c.left < 0 ) then
					c.left, c.armed = 0, false;
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Your shield, off the AZSBUFFS line ({ spell, left })

local shield = { up = false };   -- line: the AZSBUFFS line last seen, lineAt: when, on our clock

local function UpdateShield(now, def)
	local set = def.buffSet;
	if ( not set ) then
		set = {};
		for i = 1, table.getn(def.buffSpells) do
			set[def.buffSpells[i]] = true;
		end
		def.buffSet = set;
	end
	local up, ends = false, nil;
	local list = AZS_BUFFS or {};
	if ( AZS_BUFFS_UPDATED and AZS_BUFFS_UPDATED ~= shield.line ) then
		shield.line, shield.lineAt = AZS_BUFFS_UPDATED, AZS_BUFFS_UPDATED - clockGap;
	end
	for i = 1, table.getn(list) do
		if ( set[tonumber(list[i].spell)] ) then
			up = true;
			local left = tonumber(list[i].left);
			if ( left and left > 0 and shield.lineAt ) then
				ends = shield.lineAt + left;
			end
		end
	end
	-- gone before its time: it broke (a shield that runs out doesn't burst)
	if ( shield.up and not up and not ( shield.endsAt and now > shield.endsAt - 0.5 ) ) then
		shield.brokeAt = now;
	end
	shield.up = up;
	if ( up ) then
		shield.endsAt = ends;
	end
end

---------------------------------------------------------------------------------------------
-- What your hero has (owned, above), and the effects whose own damage the combat text has shown
-- this run

-- What the effects have seen (CheckRun wipes learned, killed, dots, procHit, spotCast and lags
-- when a new run starts):
--   learned: key -> when that effect's own damage was last seen this run
--   killed: target id -> when, so one death counts once
--   dots: DoT key -> { target id -> the last tick of your DoT on it }
--   procHit: def id -> when its procOn last hit
--   spotCast: def id -> the cast its newest spot came of
--   lags: def id -> how late the spell list showed its latest casts (8), in sec
--   bursts: def id -> { xs, ys }: the hits of a burst in this read of the feed
--   bodies: where enemies died lately, the latest 24: { x, y, at, t: who, ev: the killing hit }
--   past: the enemies seen lately (see Remember)
--   blind: def id -> a cast of its that found no enemies to land on (its hits place its spot)
--   read: what the last read of the enemy list gave (for /ast debug's trail)
local fx = { learned = {}, killed = {}, dots = {}, procHit = {}, spotCast = {}, lags = {}, bursts = {},
	bodies = {}, past = { reach = 0 }, blind = {}, read = {} };

-- Every key a meter source answers to: its name, item, talent and spell, and "item/<spell>"
-- for an amulet that remakes a spell.
local function SourceKeys(s, into)
	into = into or {};
	if ( type(s) ~= "table" ) then
		return into;
	end
	local item = s.itemKey or s.itemInstanceKey or s.itemId;
	if ( s.name ) then
		into[Norm(s.name)] = true;
		into[AST_Alias(Norm(s.name))] = true;
	end
	if ( s.itemKey ) then
		into[Norm(s.itemKey)] = true;
	end
	if ( s.talentKey ) then
		into[Norm(s.talentKey)] = true;
	end
	local spell = s.variantKey or s.abilityKey;
	if ( spell and item ) then
		into["item/" .. Norm(spell)] = true;
	elseif ( s.abilityKey ) then
		into[Norm(s.abilityKey)] = true;
	end
	return into;
end

-- An armor set's quality by its number (0 Common ... 5 PvP), and a class by its number. An armor
-- piece's item number is 1, its class (2 digits), its place in the set (0 head, 1 shoulders,
-- 2 chest, 3 waist, 4 legs, 5 feet, 6 wrists, 7 hands), the set's quality, then 0: 102630 is
-- the Epic paladin set's bracers.
local SET_QUALITY = { [0] = "common", "uncommon", "rare", "epic", "legendary", "pvp" };
local SET_CLASS = { [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue", [5] = "priest",
	[7] = "shaman", [8] = "mage", [9] = "warlock", [11] = "druid" };

-- What your gear gives, by what the items' tooltips say (GEAR, from the class files; a
-- legendary amulet is named "<amulet>: <the spell it remakes>"): keys, and per key the item and
-- the numbers its own text states (an empowered amulet's grow). Returns how many items it saw.
-- TALENT_KEYS are the keys a talent gives; every other is an item's, and items can be swapped
-- mid-run. An armor set's 8-piece bonus is all eight of its pieces worn at 3 stars or more
-- ("set/epic/paladin"), empowered with all eight at the most ("set/epic/paladin/5"); each
-- piece's stars are in its tooltip ("Upgraded: 4/5 stars").
local function ReadGear(keys, from, caps, radii, areas, durs)
	local seen, worn = 0, {};
	for slot = 1, 19 do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot);
		if ( link ) then
			seen = seen + 1;
			local lines = TipLines("SetInventoryItem", "player", slot) or {};
			local _, _, name = string.find(link, "%[(.-)%]");
			if ( name and lines[1] ~= name ) then
				table.insert(lines, 1, name);
			end
			-- the first number a text's patterns (in the game's language, then English) find
			local function Find(line, p)
				local list = AST_Patterns(p);
				for i = 1, table.getn(list) do
					local _, _, v = string.find(line, list[i]);
					if ( AST_Number(v) ) then
						return AST_Number(v);
					end
				end
			end
			for i = 1, table.getn(lines) do
				local line = lines[i];
				for r = 1, table.getn(GEAR) do
					local rule = GEAR[r][1];
					local own = AST_GearRule(rule);
					if ( string.find(line, own) or ( own ~= rule and string.find(line, rule) ) ) then
						local key = GEAR[r][2];
						keys[key] = true;
						from[key] = from[key] or (lines[1] or "an item");
						caps[key] = Find(line, "at most (%d+) times? a second") or caps[key];
						radii[key] = Find(line, "within ([%d%.]+) y") or radii[key];
						areas[key] = Find(line, "%+([%d%.]+)%% area") or areas[key];
						durs[key] = Find(line, "%+([%d%.]+)%% duration") or durs[key];
					end
				end
			end
			-- an armor piece: which set it is of, and its stars
			local _, _, id = string.find(link, "item:(%d+)");
			id = tonumber(id) or 0;
			local class, piece, q = math.floor(id / 1000) - 100, math.floor(id / 100) - 10 * math.floor(id / 1000),
				math.floor(id / 10) - 10 * math.floor(id / 100);
			if ( SET_CLASS[class] and SET_QUALITY[q] and piece <= 7 and id == 10 * math.floor(id / 10) ) then
				local stars, most;
				for i = 1, table.getn(lines) do
					local n = Find(lines[i], "Upgraded: ([%d%.]+)/");
					if ( n ) then
						stars, most = n, Find(lines[i], "/([%d%.]+) stars");
					end
				end
				worn[piece] = { set = SET_QUALITY[q] .. "/" .. SET_CLASS[class], stars = stars, most = most };
			end
		end
	end
	local set, low, top = nil, 99, true;
	for piece = 0, 7 do
		local w = worn[piece];
		if ( not w or not w.stars or ( set and w.set ~= set ) ) then
			set = false;
			break;
		end
		set, low = w.set, math.min(low, w.stars);
		top = top and w.most ~= nil and w.stars >= w.most;
	end
	if ( set and low >= 3 ) then
		set = "set/" .. set;
		keys[set] = true;
		from[set] = from[set] or "the armor you wear";
		if ( top ) then
			keys[set .. "/5"] = true;
			from[set .. "/5"] = from[set .. "/5"] or "the armor you wear";
		end
	end
	return seen;
end

-- What your talents give, through the client's talent list, and the auras that show a talent
-- (AURAS, from the class files: Shadowform's capstone keeps you in it all run).
local function ReadTalents(keys, from)
	if ( GetNumTalentTabs and GetNumTalents and GetTalentInfo ) then
		for tab = 1, (GetNumTalentTabs() or 0) do
			for i = 1, (GetNumTalents(tab) or 0) do
				local name, _, _, _, rank = GetTalentInfo(tab, i);
				if ( name and (tonumber(rank) or 0) > 0 ) then
					-- its English key, whatever language the game shows it in
					local key = AST_Alias(Norm(name));
					keys[key] = true;
					from[key] = from[key] or "talent";
					talentRanks[key] = tonumber(rank);
				end
			end
		end
	end
	if ( table.getn(AURAS) == 0 ) then
		return;
	end
	local textures, spells = {}, {};
	for i = 1, 40 do
		local texture = UnitBuff and UnitBuff("player", i);
		if ( not texture ) then
			break;
		end
		table.insert(textures, texture);
	end
	local buffs = AZS_BUFFS or {};
	for i = 1, table.getn(buffs) do
		table.insert(spells, tonumber(buffs[i].spell));
	end
	for a = 1, table.getn(AURAS) do
		local aura = AURAS[a];
		local on = false;
		for i = 1, table.getn(spells) do
			on = on or In(aura.spells, spells[i]);
		end
		for i = 1, table.getn(textures) do
			for t = 1, table.getn(aura.textures or {}) do
				on = on or string.find(textures[i], aura.textures[t], 1, true) ~= nil;
			end
		end
		if ( on ) then
			keys[aura.key] = true;
			from[aura.key] = from[aura.key] or aura.name;
		end
	end
end

-- The meter's list of your talents with their ranks. Its own copy is read when it has one;
-- while it doesn't, it is asked for one at most every 5 seconds (/ast meter off stops that),
-- and its last answer kept for the run.
local meter = { at = -100, asks = 0, status = "not read yet", list = {} };

local function MeterLoadout(now)
	local mst = AZS_ML and AZS_ML.st;
	local l = type(mst) == "table" and type(mst.loadouts) == "table" and mst.loadouts[mst.owner];
	if ( type(l) == "table" and type(l.talents) == "table" and type(mst.sources) == "table" ) then
		meter.how = "its copy";
		return l.talents, mst.sources, l;
	end
	if ( db.meterOff or now - meter.at < 5 or type(AZS_GetMeterContext) ~= "function"
		or type(AZS_GetMeterLoadout) ~= "function" ) then
		return meter.talents, meter.sources, meter.loadout;
	end
	meter.at = now;
	meter.asks = meter.asks + 1;
	local why;
	local ok, ctx, err = pcall(AZS_GetMeterContext);
	if ( not ok ) then
		why = ctx;
	elseif ( type(ctx) ~= "table" or not ctx.runId ) then
		why = err;
	else
		ok, l, err = pcall(AZS_GetMeterLoadout, { apiVersion = 1, runId = ctx.runId });
		if ( ok and type(l) == "table" and type(l.talents) == "table" and type(l.sources) == "table" ) then
			meter.how = "asking it";
			meter.talents, meter.sources, meter.loadout = l.talents, l.sources, l;
			return l.talents, l.sources, l;
		end
		why = ok and err or l;
	end
	if ( not meter.talents ) then
		meter.status = string.format(AST_L("asked %d times this run, not in yet (%s)"), meter.asks, ErrText(why));
	end
	return meter.talents, meter.sources, meter.loadout;
end

local function RefreshOwned(now)
	if ( now - owned.at < 2 ) then
		return;
	end
	owned.at = now;
	local keys, from, caps, radii, areas, durs = {}, {}, {}, {}, {}, {};
	-- ranks as they are now: last run's talents don't carry over
	talentRanks = {};
	owned.gearSeen = ReadGear(keys, from, caps, radii, areas, durs) > 0;
	ReadTalents(keys, from);
	local talents, sources, loadout = MeterLoadout(now);
	if ( talents ) then
		meter.list = {};
		for i = 1, table.getn(talents) do
			local t = talents[i];
			local s = sources[t.sourceKey];
			if ( (tonumber(t.rank) or 0) > 0 ) then
				table.insert(meter.list, tostring(type(s) == "table" and s.name or t.sourceKey) .. " " .. t.rank);
				for key in pairs(SourceKeys(s)) do
					keys[key] = true;
					from[key] = from[key] or "the meter's talent list";
					talentRanks[key] = tonumber(t.rank);
				end
			end
		end
		-- the abilities you have learned (Redemption, Bloodrage...) and the jewelry you wear, off
		-- the same loadout
		local lists = type(loadout) == "table" and { loadout.abilities or {}, loadout.runJewelry or {} } or {};
		for n = 1, table.getn(lists) do
			for i = 1, table.getn(lists[n]) do
				local x = lists[n][i];
				if ( type(x) == "table" and x.learned ~= false ) then
					for key in pairs(SourceKeys(sources[x.sourceKey])) do
						keys[key] = true;
						from[key] = from[key] or (n == 1 and "the meter's ability list" or "the meter's jewelry list");
					end
				end
			end
		end
		meter.status = string.format(AST_L("%d talents, from %s"), table.getn(meter.list), AST_L(tostring(meter.how)))
			.. (meter.asks > 0 and string.format(AST_L(" (asked %d times this run)"), meter.asks) or "");
	end
	owned.keys, owned.from, owned.caps, owned.radii, owned.areas, owned.durs = keys, from, caps, radii, areas, durs;
	owned.loadoutRead = talents ~= nil;
end

-- The key that gives `def` to your hero and how that is known (the item, "talent", "loadout"
-- or "seen"), or nil. An effect seen going off proves a talent for the whole run; an item only
-- while the gear can't be read, and only for 15 seconds after it last went off, as amulets get
-- swapped mid-run.
local function Has(def, now)
	if ( not def.match ) then
		return true;
	end
	for i = 1, table.getn(def.match) do
		if ( owned.keys[def.match[i]] ) then
			return def.match[i], owned.from[def.match[i]] or "loadout";
		end
	end
	for i = 1, table.getn(def.match) do
		local k = def.match[i];
		local at = fx.learned[k];
		if ( at and ( TALENT_KEYS[k] or ( not owned.gearSeen and now - at < 15 ) ) ) then
			return k, "seen";
		end
	end
	return nil;
end

---------------------------------------------------------------------------------------------
-- Effects around enemies, off the combat text feed: every hit you land, with its target, its
-- spell, whether it crit, its meter source and an anchor where it landed. A kill is a hit whose
-- target is dead (targetState) when its anchor is projected.

local rings = {};          -- { kind = def id, x, y (world), at }
-- The combat text feed's reader: ctCursor, ctPrimed, ctNext, ctStatus, lastEvent, lastProjection.
local feed = { ctPrimed = false, ctNext = 0, ctStatus = "not read yet" };
local fired = {};          -- def id -> how many times it went off
local lastFire = {};       -- def id -> when, for the "at most N times a second" caps

local function Truthy(v)
	return v == true or v == 1 or v == "1" or v == "true";
end

-- The meter's descriptor of a hit's source.
local function SourceOf(ev)
	local st = AZS_ML and AZS_ML.st;
	if ( type(ev) == "table" and ev.meterSourceKey and type(st) == "table" and type(st.sources) == "table" ) then
		return st.sources[ev.meterSourceKey];
	end
end

-- Which of your damage-over-time effects (DOTS, from the class files) a tick is, or nil.
local function DotOf(ev, keys)
	local spell, name = tonumber(ev.spellId), AST_Alias(Norm(ev.abilityName));
	for key, d in pairs(DOTS) do
		if ( In(d.spells, spell) or In(d.names, name) ) then
			return key;
		end
		for i = 1, table.getn(d.keys or {}) do
			if ( keys[d.keys[i]] ) then
				return key;
			end
		end
	end
end

-- Did your DoT `key` (any of them, for "any") tick on target t lately?
local function Afflicted(key, t, now, window)
	if ( key == "any" ) then
		for k in pairs(DOTS) do
			if ( Afflicted(k, t, now, window) ) then
				return true;
			end
		end
		return false;
	end
	local list = fx.dots[key];
	return list ~= nil and list[t] ~= nil and now - list[t] < window;
end

-- How long after its last tick a DoT surely still sits on an enemy: a tick every second at
-- base, faster with DoT haste.
local function DotWindow()
	local haste = (AZS_STATS and tonumber(AZS_STATS.doth)) or 0;
	return 1.3 / (1 + math.max(0, haste)) + 0.25;
end

-- Effects around you that go off on their own: id -> when it last did (chastise), and the time
-- between its last two goes.
local procs, procGap = {}, {};

local function Proc(id, now, gap)
	if ( not procs[id] or now - procs[id] > gap ) then
		if ( procs[id] ) then
			procGap[id] = now - procs[id];
		end
		procs[id] = now;
	end
end

-- A talent's own timer (def.clock): the seconds left to its next go and the whole wait, from the
-- clocks the build screen shows (AZS_GetTimers), or else counted from the goes seen. A clock that
-- starts over is a go.
local clk = { clocks = {}, clocksAt = -1, clockLeft = {} };

local function ClockOf(def, now)
	if ( now - clk.clocksAt >= 0.1 ) then
		clk.clocksAt = now;
		local list = type(AZS_GetTimers) == "function" and AZS_GetTimers();
		clk.clocks = type(list) == "table" and list or {};
	end
	for i = 1, table.getn(clk.clocks) do
		local t = clk.clocks[i];
		local left, max, named = nil, nil, false;
		if ( type(t) == "table" ) then
			left, max = tonumber(t.remaining), tonumber(t.duration);
			for k = 1, table.getn(def.clock.names) do
				named = named or Norm(def.clock.names[k]) == AST_Alias(Norm(t.name));
			end
		end
		if ( named and left and max and max > 0 ) then
			if ( clk.clockLeft[def.id] and left > clk.clockLeft[def.id] + 0.5 ) then
				Proc(def.id, now, 1);
			end
			clk.clockLeft[def.id] = left;
			return left, max;
		end
	end
	local at = procs[def.id];
	if ( not at ) then
		return nil;
	end
	-- the wait it was seen to take, near the one it should (Haste shortens a talent's wait as it
	-- does a cooldown: AZS_STATS.cd is what a cooldown is left at)
	local cdm = AZS_STATS and tonumber(AZS_STATS.cd);
	local every = def.clock.every * ((cdm and cdm > 0 and cdm <= 1) and cdm or 1);
	local gap = procGap[def.id];
	if ( gap and gap > every * 0.5 and gap < every * 1.5 ) then
		every = gap;
	end
	local gone = now - at;
	return every - (gone - every * math.floor(gone / every)), every;
end

-- Every key a hit answers to: its meter source's, when the meter has that source, and the
-- source and ability names and the source key the hit carries itself.
local function HitKeys(ev)
	local keys = SourceKeys(SourceOf(ev));
	if ( type(ev.meterSource) == "string" ) then
		keys[AST_Alias(Norm(ev.meterSource))] = true;
	end
	if ( type(ev.abilityName) == "string" ) then
		keys[AST_Alias(Norm(ev.abilityName))] = true;
	end
	local key = ev.meterSourceKey;
	if ( type(key) == "string" ) then
		keys[Norm(key)] = true;
		-- an armor set's bonus, "set:<class>.<quality>" (".empowered" too with all eight at 5 stars):
		-- "set/epic/paladin" (and "set/epic/paladin/5"); a set past the six qualities is T0.5's
		local _, _, class, q, rest = string.find(key, "^set:(%a+)%.(%d+)(.*)$");
		if ( q ) then
			local set = "set/" .. (SET_QUALITY[tonumber(q)] or "t05") .. "/" .. string.lower(class);
			keys[set] = true;
			if ( string.find(rest, "empowered") ) then
				keys[set .. "/5"] = true;
			end
		end
		local pos = 1;
		while ( true ) do
			local s, e, part = string.find(key, "([^:/|%.]+)", pos);
			if ( not s ) then
				break;
			end
			keys[Norm(part)] = true;
			pos = e + 1;
		end
	end
	return keys;
end

-- Does hit `ev` match `rule` ({ spells, names, source, crit, ticks })? A damage-over-time tick does
-- only for a rule with ticks. Its names are the ability's or the meter line's it is credited to;
-- source, a pattern its meter source key fits ("^set:paladin%.3": an armor set's bonus).
local function Hits(ev, rule)
	if ( ( Truthy(ev.periodic) and not rule.ticks ) or ( rule.crit and not Truthy(ev.critical) ) ) then
		return false;
	end
	return In(rule.spells, tonumber(ev.spellId)) or In(rule.names, AST_Alias(Norm(ev.abilityName)))
		or ( type(ev.meterSource) == "string" and In(rule.names, AST_Alias(Norm(ev.meterSource))) )
		or ( rule.source and type(ev.meterSourceKey) == "string" and string.find(ev.meterSourceKey, rule.source) ~= nil );
end

-- Effects that go off on their own (a def's procOn: Chastise on a Smite crit), and the hits that
-- show your hero has one (its spot: a hit of the spot's spell soon after a procOn hit, that isn't
-- your own cast of spot.ownSpell, which comes when that spell is ready or just went off).

local function ProcHits(ev, now)
	for j = 1, table.getn(DEFS) do
		local def = DEFS[j];
		if ( def.procOn and Hits(ev, def.procOn) ) then
			fx.procHit[def.id] = now;
			Proc(def.id, now, def.procOn.gap or 0.25);
		elseif ( def.procOn and ev.effect == def.id ) then
			Proc(def.id, now, def.procOn.gap or 0.25);
		end
		local spot = def.spot;
		if ( spot and fx.procHit[def.id] and now - fx.procHit[def.id] < (spot.window or 0.6) and Hits(ev, spot) ) then
			local own = spot.ownSpell and byId[spot.ownSpell];
			local c = own and SpellOf(own);
			if ( not ( c and ( (c.left or 0) <= 0.5 or ( c.castAt and math.abs(now - c.castAt) < 0.6 ) ) ) ) then
				fx.learned[def.match[1]] = now;
			end
		end
		-- a free go of a spell (Radiance's Holy Nova): its hits while your own is on cooldown and
		-- wasn't just cast, and not those of another proc (Chastise's nova after a Smite crit)
		local free = def.free;
		if ( free and Hits(ev, free) and not ( free.unless and procs[free.unless] and now - procs[free.unless] < 0.8 ) ) then
			local c = free.ownSpell and cds[Norm(free.ownSpell)];
			if ( not ( c and ( (c.left or 0) <= 0.5 or ( c.castAt and math.abs(now - c.castAt) < 1.2 ) ) ) ) then
				if ( Has(def, now) ) then
					Proc(def.id, now, 1);
				elseif ( not owned.loadoutRead ) then
					-- One such go is weak proof when the meter's talent list can't say: your own cast's
					-- late hits, a second ring or an Echo look the same. It takes two, about the timer's
					-- wait apart (within a minute, with no timer), unless you can't cast the spell at all.
					local goes = owned.freeGoes[def.id] or {};
					owned.freeGoes[def.id] = goes;
					local n = table.getn(goes);
					if ( n == 0 or now - goes[n] > 1 ) then
						local sure = not free.ownSpell;
						local cdm = AZS_STATS and tonumber(AZS_STATS.cd);
						local every = def.clock and def.clock.every * ((cdm and cdm > 0 and cdm <= 1) and cdm or 1);
						for k = 1, n do
							local gap = now - goes[k];
							if ( every and gap > every * 0.75 and gap < every * 1.25 )
								or ( not def.clock and gap < 60 ) then
								sure = true;
							end
						end
						if ( n >= 8 ) then
							table.remove(goes, 1);
						end
						table.insert(goes, now);
						if ( sure ) then
							fx.learned[def.match[1]] = now;
							Proc(def.id, now, 1);
						end
					end
				end
			end
		end
	end
end

-- Did the spells of `rule` ({ spells, names, source }) land hit `ev`, a damage-over-time tick
-- included?
local function KilledBy(ev, rule)
	return In(rule.spells, tonumber(ev.spellId)) or In(rule.names, AST_Alias(Norm(ev.abilityName)))
		or ( rule.source and type(ev.meterSourceKey) == "string" and string.find(ev.meterSourceKey, rule.source) ~= nil );
end

-- Is `ev` a hit that one of the "hit" effects your hero has goes off on (its own damage aside),
-- or one of a spot's or a burst's?
local function HitTrigger(ev, active)
	for j = 1, table.getn(active) do
		local a = active[j];
		if ( a.def.trigger == "hit" and ev.effect ~= a.def.id and Hits(ev, a.def.on) ) then
			return true;
		elseif ( ( a.def.shape == "ground" or a.def.trigger == "burst" ) and KilledBy(ev, a.def.on) ) then
			return true;
		end
	end
	return false;
end

---------------------------------------------------------------------------------------------
-- Spells that land on a spot of the ground (Blizzard, Flamestrike): "the thickest group of enemies
-- within its range". When the spell list shows one cast, the spot is worked out the same way from
-- where the enemies stood when it went off, and stays there. Its first tick (a quarter second on)
-- tells how big the spell is closer than its tooltip does, for the casts after. Ticks with no such
-- spot (a cast the list didn't show) place one of their own. Bursts (a sheep popping) flash where
-- their hits centre.

local spots = {};          -- { id = def id, x, y (world), at, dur, xs, ys: its latest hits,
                           --   cands: the enemies it can be on (a cast's spot), tip, r: its
                           --   tooltip's radius and the one it was placed with, first: the enemies
                           --   its first tick hit, by id; shown: a spot of hits alone, on screen }
local sizes = {};          -- def id -> { lo, hi }: its size before your Area, as its ticks bound it
local FIRST_TICK = 0.25;   -- a spot's first tick, after its cast
local FOES = { "enemy", "elite", "guardian", "boss", "finalBoss" };
local FOE = { enemy = true, elite = true, guardian = true, boss = true, finalBoss = true };
local GONE = { fallen = true, dead = true, departed = true };

-- /ast spotlog: what spots on the ground go by (casts, where they land, their hits), kept with the
-- saved settings, the latest 80, for working out one that lands wrong.
local function SpotLog(entry)
	if ( type(db.spotLog) ~= "table" ) then
		return;
	end
	entry.t = math.floor((GetTime() - clockGap) * 100 + 0.5) / 100;
	table.insert(db.spotLog, entry);
	if ( table.getn(db.spotLog) > 80 ) then
		table.remove(db.spotLog, 1);
	end
end

local function XY(x, y)
	return string.format("%.1f,%.1f", x, y);
end

-- The query every page of a read is asked with: a page's cursor belongs to the query it came from,
-- and the game refuses it with another ("this cursor belongs to another query"). Living enemies
-- ("alive"; the game has no "living", which it refused, so page 1 came from a second query without
-- the filter and page 2 was refused: once a run's list passed a page, mostly of the dead, the
-- enemies near you weren't read and the ground spells' spots stopped). If the game won't take the
-- filter, or its pages come back empty while there are enemies, every enemy (the dead are skipped
-- here), for good. foeQn: the one in use; foeOk: "alive" has given enemies, so it's kept.
fx.foeQ, fx.foeQn = { { kinds = FOES, states = { "alive" } }, { kinds = FOES } }, 1;

-- The living enemies within `reach` yd of you, into t: t.xs, t.ys, t.zs, t.ids (the first t.n of
-- them) and where you stood (t.px, t.py, t.pz). The game hands them out 256 at a time, in no order
-- of distance (hasMore and a nextCursor while there are more): every page is read, all with the
-- same query. A catalog that changes between pages is read again from the start, once.
local function ReadFoes(p, reach, t)
	local cursor, page, again = nil, 0, true;
	t.n, t.px, t.py, t.pz = 0, p.x, p.y, p.z;
	t.zs = t.zs or {};
	-- what the list gave, for the trail: enemies in it, pages, the nearest, ones with no position
	local R = fx.read;
	R.total, R.pages, R.nearest, R.nopos, R.over, R.err = 0, 0, nil, 0, nil, nil;
	while ( page < 32 ) do
		page = page + 1;
		local res, err = AZS_GetWorldAnchors(fx.foeQ[fx.foeQn], cursor, 256);
		local list = Entries(res);
		if ( page == 1 and fx.foeQn == 1 and ( ( not res and type(err) == "table" and err.code == "INVALID_ARGUMENT" )
			or ( not fx.foeOk and list and table.getn(list) == 0 ) ) ) then
			-- the filter refused, or (not yet seen working) nothing with it: try without it
			local res2, err2 = AZS_GetWorldAnchors(fx.foeQ[2], nil, 256);
			local list2 = Entries(res2);
			if ( list2 and ( not res or table.getn(list2) > 0 ) ) then
				fx.foeQn, res, err, list = 2, res2, err2, list2;
			end
		elseif ( fx.foeQn == 1 and list and table.getn(list) > 0 ) then
			fx.foeOk = true;
		end
		R.pages = page;
		if ( type(res) == "table" and res.overflowed ) then
			R.over = true;
		end
		if ( not list and type(err) == "table" ) then
			R.err = tostring(err.code) .. ( err.message and ( " (" .. tostring(err.message) .. ")" ) or "" );
		end
		if ( not list and cursor and again and type(err) == "table" and err.code == "CATALOG_CHANGED" ) then
			again, cursor, page, t.n = false, nil, 0, 0;
			list = {};
		elseif ( not list ) then
			break;
		end
		for i = 1, table.getn(list) do
			local e = list[i];
			if ( type(e) == "table" and FOE[e.kind] and not GONE[e.state] and e.positionAvailable == false ) then
				R.nopos = R.nopos + 1;
			end
			if ( type(e) == "table" and FOE[e.kind] and not GONE[e.state] and e.positionAvailable ~= false
				and type(e.x) == "number" and type(e.y) == "number" ) then
				local dx, dy = e.x - p.x, e.y - p.y;
				R.total = R.total + 1;
				if ( not R.nearest or dx * dx + dy * dy < R.nearest ) then
					R.nearest = dx * dx + dy * dy;
				end
				if ( dx * dx + dy * dy <= reach * reach ) then
					t.n = t.n + 1;
					t.xs[t.n], t.ys[t.n], t.ids[t.n] = e.x, e.y, e.unitId or e.anchorId or false;
					t.zs[t.n] = type(e.z) == "number" and e.z or p.z;
				end
			end
		end
		if ( page > 0 ) then
			-- the next page: while the answer names one (a new one, and this page wasn't empty)
			local nxt = type(res) == "table" and res.hasMore ~= false and ( res.nextCursor or res.cursor );
			if ( type(nxt) ~= "string" or nxt == "" or nxt == cursor or table.getn(list) == 0 ) then
				break;
			end
			cursor = nxt;
		end
	end
end

-- What the last read of the enemy list gave, as text (for the trail).
fx.ReadText = function()
	local R = fx.read;
	return string.format("list: %d enemies with a place, %d without, %d pages, nearest %s%s%s", R.total or 0, R.nopos or 0,
		R.pages or 0, R.nearest and string.format("%.0f yd", math.sqrt(R.nearest)) or "none",
		R.over and ", overflowed" or "", R.err and (", error " .. R.err) or "") .. ( fx.foeQn == 2 and ", unfiltered" or "" );
end

-- The enemies' heights, for where hits are: the living ones as last read (cur), and as read before
-- that (old: one killed since was still there). Read again once 0.2 sec old.
fx.near = { cur = { xs = {}, ys = {}, zs = {}, ids = {}, n = 0 }, old = { xs = {}, ys = {}, zs = {}, ids = {}, n = 0 },
	at = -1 };

-- The height of the enemy nearest x, y, within 10 yd of it; nil with none that near.
fx.FoeZ = function(x, y, p, now)
	local h = fx.near;
	if ( now - h.at > 0.2 or now < h.at ) then
		h.cur, h.old = h.old, h.cur;
		ReadFoes(p, 80, h.cur);
		h.at = now;
	end
	local best, z = 100, nil;
	for k = 1, 2 do
		local t = ( k == 1 ) and h.cur or h.old;
		for i = 1, t.n do
			local dx, dy = t.xs[i] - x, t.ys[i] - y;
			if ( dx * dx + dy * dy < best ) then
				best, z = dx * dx + dy * dy, t.zs[i];
			end
		end
	end
	return z;
end

---------------------------------------------------------------------------------------------
-- Depth helpers for rings round you and cones (each a setting of its own, off to start with): a
-- see-through wall standing on the edge (wallOn, wallHeight yd), faint arcs every bandEvery yd
-- with their distance (bands, bandNumbers), and a mark under every enemy inside (marks). Seen from
-- low down a flat shape on the ground gets thin; these keep its reach readable.

-- Texts on the screen this frame (the bands' numbers), from a pool: hidden when not used again.
fx.texts = { list = {}, used = 0, shown = 0 };
fx.Text = function(text, x, y, c, alpha)
	local T = fx.texts;
	T.used = T.used + 1;
	local f = T.list[T.used];
	if ( not f ) then
		f = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		T.list[T.used] = f;
	end
	f:SetText(text);
	f:SetTextColor(c[1], c[2], c[3], math.min(1, alpha));
	f:ClearAllPoints();
	f:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y);
	f:Show();
end
fx.TextsDone = function()
	local T = fx.texts;
	for i = T.used + 1, T.shown do
		T.list[i]:Hide();
	end
	T.shown, T.used = T.used, 0;
end

-- A thin faint arc round you (a band, a wall's top): the ring texture's line in the Texture style
-- (far fewer pieces than Core's for a thin see-through line); false where it can't be (then dotted).
fx.ThinArc = function(R, a0, a1, st, c, alpha)
	local tx = st.style == "texture" and AST.lab and AST.lab.tex;
	return tx ~= nil and tx ~= false and tx.Arc ~= nil and tx.Arc(0, 0, R, math.max(1.5, st.width * 0.6), c, alpha, a0, a1) ~= false;
end

-- The wall on the edge of a ring R round you (a0..a1: a cone's arc): two bands, fainter as it
-- rises, and a faint line along its top.
fx.Wall = function(R, a0, a1, cone, st, alpha)
	local hgt, c = st.wallHeight or 1, st.line;
	for k = 0, 1 do
		local z0, z1 = hgt * k / 2, hgt * (k + 1) / 2;
		PN = 0;
		H.dz = z0;
		local ok = AddArc(0, 0, R, a0, a1);
		H.dz = z1;
		ok = ok and AddArc(0, 0, R, a1, a0);
		H.dz = 0;
		if ( ok ) then
			FillPoly(c, alpha * ( k == 0 and 0.3 or 0.16 ), 3);
		end
	end
	H.dz = hgt;
	if ( not fx.ThinArc(R, a0, a1, st, c, alpha * 0.5) ) then
		DotArc(0, 0, R, a0, a1, c, alpha * 0.5, 2, 5);
	end
	H.dz = 0;
end

-- Faint arcs every bandEvery yd inside a ring or cone, each with its distance at its side.
fx.Bands = function(R, a0, a1, cone, st, alpha)
	local every = math.max(1, st.bandEvery or 5);
	local c = st.line;
	local n = 0;
	local d = every;
	while ( d < R - 0.25 and n < 30 ) do
		if ( not fx.ThinArc(d, a0, a1, st, c, alpha * 0.4) ) then
			DotArc(0, 0, d, a0, a1, c, alpha * 0.5, 2, 7);
		end
		if ( st.bandNumbers ) then
			-- just outside the cone's first side (a ring's: toward the screen's right)
			local a = cone and a0 - 0.12 or 0;
			local x, y = Map(d * math.cos(a), d * math.sin(a));
			if ( x ) then
				fx.Text(string.format("%g", d), x, y, c, alpha * 0.9);
			end
		end
		d = d + every;
		n = n + 1;
	end
end

-- The enemies, for the marks: read about 30 times a second (they move).
fx.foes = { xs = {}, ys = {}, zs = {}, ids = {}, n = 0, at = -1 };

-- A mark under every enemy inside a ring R round you (or a cone a0..a1): a soft disc and a bright
-- centre (texture rings: the ring texture, when the Lab's textures are there).
fx.Marks = function(R, a0, a1, cone, st, alpha, p, now)
	local F = fx.foes;
	if ( now - F.at > 0.033 or now < F.at ) then
		ReadFoes(p, R + 2, F);
		F.at = now;
	end
	local c = st.line;
	local mid, half = (a0 + a1) / 2, (a1 - a0) / 2;
	local tex = st.style == "texture" and AST.lab and AST.lab.Ground;
	for i = 1, F.n do
		local u, v = F.xs[i] - p.x, F.ys[i] - p.y;
		local inside = u * u + v * v <= R * R;
		if ( inside and cone ) then
			local da = math.atan2(v, u) - mid;
			da = da - math.floor((da + PI) / (2 * PI)) * 2 * PI;
			inside = math.abs(da) <= half;
		end
		if ( inside ) then
			H.dz = F.zs[i] - p.z;
			if ( tex ) then
				AST.lab.Ground("Spells\\GENERICGLOW2_64", u, v, 0.9, 0, c, alpha * 0.55, "BLEND");
				AST.lab.Ground("Spells\\Circle", u, v, 0.95 / 0.965, 0, c, alpha, "ADD");
			else
				-- one piece each where the ellipse stands upright, else filled as a polygon
				if ( not H.Ellipse(u, v, 0.9, c, alpha * 0.4) ) then
					PN = 0;
					if ( AddArc(u, v, 0.9, 0, 2 * PI) ) then
						FillPoly(c, alpha * 0.4, 3);
					end
				end
				H.Ellipse(u, v, 0.32, Bright(c), alpha * 0.85);
			end
			H.dz = 0;
		end
	end
end

-- The depth helpers a ring or cone's settings ask for (after it is drawn, however it is drawn).
fx.Depth = function(j, p, now)
	local st = j.st.real or j.st;
	if ( not ( st.wallOn or st.bands or st.marks ) or not j.size or j.size <= 0 ) then
		return;
	end
	local cone = j.def.shape == "cone";
	local a0, a1 = 0, 2 * PI;
	if ( cone ) then
		local h = j.def.halfAngle * PI / 180;
		a0, a1 = j.facing - h, j.facing + h;
	end
	if ( st.bands ) then
		fx.Bands(j.size, a0, a1, cone, st, j.alpha);
	end
	if ( st.wallOn ) then
		fx.Wall(j.size, a0, a1, cone, st, j.alpha);
	end
	if ( st.marks ) then
		fx.Marks(j.size, a0, a1, cone, st, j.alpha, p, now);
	end
end

-- Where a hit shown at screen sx, sy is, and its height: where the line to it meets the ground at
-- the height of the enemy there (the enemy nearest it, looked for again from each better spot,
-- three times at most). With no enemy near, on the ground at your height, as before.
fx.HitSpot = function(sx, sy, p, now)
	local u, v = Unmap(sx, sy);
	if ( not u ) then
		return nil;
	end
	local z;
	for k = 1, 3 do
		local nz = fx.FoeZ(p.x + u, p.y + v, p, now);
		if ( not nz or ( z and math.abs(nz - z) < 0.05 ) ) then
			break;
		end
		local u2, v2 = Unmap(sx, sy, nz - p.z);
		if ( not u2 ) then
			break;
		end
		u, v, z = u2, v2, nz;
	end
	return p.x + u, p.y + v, z or p.z;
end

-- The mean of a list's numbers; nil when it has none.
fx.Mean = function(list)
	local sum, n = 0, 0;
	for i = 1, table.getn(list) do
		sum, n = sum + list[i], n + 1;
	end
	return n > 0 and sum / n or nil;
end

-- A ground spell that moves with you (a set's Consecration): a ring on you, as the rings around
-- you are, `p` filling it from the centre as its time runs and a shockwave on each cast. While
-- each lasts until the next (running), the ring is full and gently breathes, and two small comets
-- (a bright head, a fading tail) slowly circle its edge.
fx.Aura = function(R, st, alpha, p, since, running, now)
	if ( not running ) then
		DrawCircleAt(0, 0, R, st, alpha, p, since);
		return;
	end
	local breath = 0.8 + 0.2 * math.sin(now * 2 * PI / 3);
	local turn, tail, n = -now * 2 * PI / 8, 70 * PI / 180, 7;
	local bright = Bright(st.line);
	if ( st.style == "dots" ) then
		if ( st.lineOn ~= false ) then
			DotArc(0, 0, R, 0, 2 * PI, st.line, alpha, st.size, st.spacing);
		end
		if ( st.fill[4] > 0 and st.fillOn ~= false ) then
			DotFill(0, 0, R, 0, 2 * PI, st, alpha * 0.5 * breath);
		end
	else
		PN = 0;
		if ( st.fillOn ~= false and AddArc(0, 0, R, 0, 2 * PI) ) then
			FillPoly(st.fill, alpha * breath, st.strip);
		end
		PN = 0;
		if ( AddArc(0, 0, R, 0, 2 * PI) ) then
			Outline(true, st, alpha, 1);
		end
	end
	-- the comets: head first (it turns toward lower angles), each piece of the tail fainter
	for i = 0, 1 do
		local head = turn + i * PI;
		for k = 1, n do
			local a0, a1, f = head + tail * (k - 1) / n, head + tail * k / n, 1 - (k - 1) / n;
			if ( st.style == "dots" ) then
				DotArc(0, 0, R, a0, a1, bright, alpha * f, st.size * (1 + 0.6 * f), st.spacing);
			else
				PN = 0;
				if ( AddArc(0, 0, R, a0, a1) ) then
					Stroke(false, bright, alpha * 0.3 * f, st.width * 4);
				end
				PN = 0;
				if ( AddArc(0, 0, R, a0, a1) ) then
					Stroke(false, bright, alpha * f, st.width * (1 + f));
				end
			end
		end
	end
end

-- Where the enemies stood a moment ago, while you have a spell that lands on a spot: every frame
-- while a cast or a first tick is due (`close`), else every 0.1 sec once a cast could come. The
-- latest 48: every frame of the last 0.2 sec, one every 0.1 sec before. The oldest first; their
-- tables are reused. `reach`: the farthest any of those spells looks (its range and its radius).
local function Remember(p, now, reach, close)
	fx.past.reach = math.max(fx.past.reach, reach);
	local last = fx.past[table.getn(fx.past)];
	if ( last and now >= last.at and ( now - last.at < 0.1 and not close or now == last.at ) ) then
		return;
	end
	local t;
	if ( table.getn(fx.past) >= 48 ) then
		local k = 1;
		for i = 2, table.getn(fx.past) - 1 do
			if ( now - fx.past[i].at > 0.2 and fx.past[i + 1].at - fx.past[i - 1].at < 0.1 ) then
				k = i;
				break;
			end
		end
		t = table.remove(fx.past, k);
	else
		t = { xs = {}, ys = {}, zs = {}, ids = {} };
	end
	ReadFoes(p, fx.past.reach, t);
	t.at = now;
	table.insert(fx.past, t);
end

-- Where they stood at `when`: between the two kept either side of it, each enemy in both moved
-- along by how far between them `when` is, and one in only one of them there if `when` is nearer
-- it. Two kept far apart say nothing of between (enemies came and went): the one nearer `when`.
-- Nil when none kept is within 0.15 sec of it.
local function Blend(when)
	local a, b;
	for i = 1, table.getn(fx.past) do
		if ( fx.past[i].at <= when ) then
			a = fx.past[i];
		elseif ( not b ) then
			b = fx.past[i];
		end
	end
	if ( not ( a and b ) or b.at - a.at > 0.25 ) then
		if ( a and b and b.at - when < when - a.at ) then
			a = b;
		end
		a = a or b;
		return a and math.abs(a.at - when) <= 0.15 and a or nil;
	end
	local w, q, at = (when - a.at) / (b.at - a.at), { n = 0, xs = {}, ys = {}, zs = {}, ids = {}, at = when }, {};
	q.px, q.py, q.pz = a.px + (b.px - a.px) * w, a.py + (b.py - a.py) * w, a.pz + (b.pz - a.pz) * w;
	for i = 1, b.n do
		if ( b.ids[i] ) then
			at[b.ids[i]] = i;
		end
	end
	for i = 1, a.n do
		local k = a.ids[i] and at[a.ids[i]];
		if ( k ) then
			q.n = q.n + 1;
			q.xs[q.n], q.ys[q.n], q.ids[q.n] = a.xs[i] + (b.xs[k] - a.xs[i]) * w, a.ys[i] + (b.ys[k] - a.ys[i]) * w, a.ids[i];
			q.zs[q.n] = a.zs[i] + (b.zs[k] - a.zs[i]) * w;
			at[a.ids[i]] = false;
		elseif ( w < 0.5 ) then
			q.n = q.n + 1;
			q.xs[q.n], q.ys[q.n], q.ids[q.n], q.zs[q.n] = a.xs[i], a.ys[i], a.ids[i], a.zs[i];
		end
	end
	for i = 1, b.n do
		if ( w >= 0.5 and not ( b.ids[i] and at[b.ids[i]] == false ) ) then
			q.n = q.n + 1;
			q.xs[q.n], q.ys[q.n], q.ids[q.n], q.zs[q.n] = b.xs[i], b.ys[i], b.ids[i], b.zs[i];
		end
	end
	return q;
end

-- Where such a spell lands, from the enemies in t: of those within `range` yd of you, the 24
-- nearest; of those, the one with the most enemies (itself too) within `radius` yd of it, the
-- farther one on a tie. Its position, the 24, how many it has around it, and which it is (its
-- height: z).
local function LandingSpot(t, range, radius)
	local near, cands = {}, {};
	for i = 1, t.n do
		local dx, dy = t.xs[i] - t.px, t.ys[i] - t.py;
		if ( dx * dx + dy * dy <= range * range ) then
			table.insert(near, { x = t.xs[i], y = t.ys[i], z = t.zs and t.zs[i], d = dx * dx + dy * dy });
		end
	end
	table.sort(near, function(a, b) return a.d < b.d; end);
	local best, most = nil, -1;
	for i = 1, math.min(24, table.getn(near)) do
		local a, n = near[i], 0;
		table.insert(cands, a);
		for k = 1, t.n do
			local ex, ey = t.xs[k] - a.x, t.ys[k] - a.y;
			if ( ex * ex + ey * ey <= radius * radius ) then
				n = n + 1;
			end
		end
		a.n = n;
		if ( n >= most ) then
			best, most = a, n;
		end
	end
	if ( best ) then
		return best.x, best.y, cands, most, best;
	end
	return nil, nil, cands, 0, nil;
end

-- For each enemy such a spell can land on (cands, from the enemies in t), the radii between lo and
-- hi with which it is the one it lands on: e.plo to e.phi (none: it isn't with any). Going out from
-- lo, each enemy passed adds to the count of the one it is around.
local function PickRanges(t, cands, lo, hi)
	local steps, n = {}, {};
	for c = 1, table.getn(cands) do
		local e = cands[c];
		e.plo, e.phi, n[c] = nil, nil, 0;
		for i = 1, t.n do
			local dx, dy = t.xs[i] - e.x, t.ys[i] - e.y;
			local d = math.sqrt(dx * dx + dy * dy);
			if ( d <= lo ) then
				n[c] = n[c] + 1;
			elseif ( d <= hi ) then
				table.insert(steps, { d = d, c = c });
			end
		end
	end
	table.sort(steps, function(a, b) return a.d < b.d; end);
	local from, k = lo, 1;
	while ( true ) do
		-- the one it lands on from `from` to the next step: the most around it, the farther on a tie
		local best, most = 1, -1;
		for c = 1, table.getn(cands) do
			if ( n[c] >= most ) then
				best, most = c, n[c];
			end
		end
		local e, to = cands[best], steps[k] and steps[k].d or hi;
		e.plo, e.phi = math.min(e.plo or from, from), math.max(e.phi or to, to);
		if ( not steps[k] ) then
			return;
		end
		from = steps[k].d;
		while ( steps[k] and steps[k].d == from ) do
			n[steps[k].c] = n[steps[k].c] + 1;
			k = k + 1;
		end
	end
end

-- The centre of the smallest circle around the points, near enough (each step moves toward the
-- farthest point, by less each time), and that circle's radius.
local function Middle(xs, ys)
	local cx, cy = xs[1], ys[1];
	local n = table.getn(xs);
	for k = 1, 30 do
		local far, most = 1, -1;
		for i = 1, n do
			local dx, dy = xs[i] - cx, ys[i] - cy;
			if ( dx * dx + dy * dy > most ) then
				far, most = i, dx * dx + dy * dy;
			end
		end
		cx = cx + (xs[far] - cx) / (k + 1);
		cy = cy + (ys[far] - cy) / (k + 1);
	end
	local most = 0;
	for i = 1, n do
		local dx, dy = xs[i] - cx, ys[i] - cy;
		most = math.max(most, dx * dx + dy * dy);
	end
	return cx, cy, math.sqrt(most);
end

-- The radii a tooltip's number stands for: it gives a tenth of a yard under 10 yd, the nearest yard
-- from there.
local function TipRange(r)
	if ( r < 9.95 ) then
		return r - 0.05, r + 0.05;
	end
	return math.max(9.95, r - 0.5), r + 0.5;
end

-- A spot spell's radius: its tooltip's, or closer once its first ticks have bounded its size
-- before your Area (the stats line gives Area to the thousandth), while that still fits the
-- tooltip (it doesn't once the spell's own bonuses change).
local function GroundSize(def, tip)
	local L, area = sizes[def.id], AZS_STATS and tonumber(AZS_STATS.area);
	if ( not ( L and area and area > 0 ) ) then
		return tip, false;
	end
	local lo, hi = TipRange(tip);
	local r = (L.lo + L.hi) / 2 * area;
	if ( r < lo or r > hi ) then
		sizes[def.id] = nil;
		return tip, false;
	end
	return r, true;
end

-- What a tick says of its spell's size, from where the enemies stood as it went off (`q`, taken
-- then): every enemy it hit (`ids`) was within the radius of the spot, and every other one beyond
-- it (but one, in case a hit went missing), give or take how far off the positions can be. The spot
-- is one of the enemies it could land on, as they stood at the cast: each that has fit the hits of
-- every tick so far within the tooltip's range keeps the radii they all allow (e.lo, e.hi), and the
-- size lies in what any of them allows (the one the ring is on need not be it); of those, what the
-- ones it would have landed on with those radii allow, if any is. Kept as the size before your
-- Area, narrowed by each tick that agrees with it; three ticks in a row that don't replace it.
local SLACK = 0.04;
local function Learn(s, def, q, ids)
	local area = AZS_STATS and tonumber(AZS_STATS.area);
	if ( not ( q and area and area > 0 and s.tip ) ) then
		return;
	end
	local hits = 0;
	for i = 1, q.n do
		if ( q.ids[i] and ids[q.ids[i]] ) then
			hits = hits + 1;
		end
	end
	local entry = { ev = "size", id = def.id, hits = hits, area = area, tip = s.tip,
		tick = math.floor((q.at - s.at) * 100 + 0.5) / 100 };
	if ( hits < 3 ) then
		-- too few to tell
		entry.kept = false;
		SpotLog(entry);
		return;
	end
	local tlo, thi = TipRange(s.tip);
	local lo, hi, plo, phi, fit;
	for c = 1, table.getn(s.cands) do
		local e = s.cands[c];
		if ( not e.out ) then
			local clo, out1, out2 = 0, 1e9, 1e9;
			for i = 1, q.n do
				local dx, dy = q.xs[i] - e.x, q.ys[i] - e.y;
				local d = dx * dx + dy * dy;
				if ( q.ids[i] and ids[q.ids[i]] ) then
					clo = math.max(clo, d);
				elseif ( d < out1 ) then
					out1, out2 = d, out1;
				elseif ( d < out2 ) then
					out2 = d;
				end
			end
			-- as sizes before your Area, within what its earlier ticks allowed
			clo = math.max(math.sqrt(clo) - SLACK, tlo) / area;
			local chi = math.min(math.sqrt(out2) + SLACK, thi) / area;
			clo, chi = math.max(clo, e.lo or clo), math.min(chi, e.hi or chi);
			if ( clo <= chi ) then
				e.lo, e.hi = clo, chi;
				lo, hi, fit = math.min(lo or clo, clo), math.max(hi or chi, chi), (fit or 0) + 1;
				-- and with a radius it would have landed on
				local a, b = e.plo and math.max(clo, (e.plo - SLACK) / area), e.phi and math.min(chi, (e.phi + SLACK) / area);
				if ( a and a <= b ) then
					plo, phi = math.min(plo or a, a), math.max(phi or b, b);
				end
			else
				e.out = true;
			end
		end
	end
	entry.fit = fit;
	if ( not lo ) then
		entry.kept = false;
		SpotLog(entry);
		return;
	end
	lo, hi = plo or lo, phi or hi;
	local L = sizes[def.id];
	if ( L and lo <= L.hi and hi >= L.lo ) then
		L.lo, L.hi, L.off = math.max(L.lo, lo), math.min(L.hi, hi), 0;
	elseif ( L and (L.off or 0) < 2 ) then
		-- it disagrees: once or twice is a bad read
		L.off = (L.off or 0) + 1;
		entry.kept = false;
	else
		L = { lo = lo, hi = hi, off = 0 };
		sizes[def.id] = L;
	end
	entry.r = string.format("%.2f-%.2f", L.lo * area, L.hi * area);
	SpotLog(entry);
end

-- Does a hit at x, y belong to spot t? A spot placed at a cast takes the hits within its radius
-- (give or take); one of hits alone, any hit that still fits a single spot with its others.
local function Fits(t, x, y, R)
	local dx, dy = x - t.x, y - t.y;
	local d = dx * dx + dy * dy;
	if ( t.cands ) then
		return d <= (R + 2) * (R + 2), d;
	elseif ( d > 4 * R * R ) then
		return false, d;
	end
	table.insert(t.xs, x);
	table.insert(t.ys, y);
	local _, _, r = Middle(t.xs, t.ys);
	table.remove(t.xs);
	table.remove(t.ys);
	return r <= R * 1.1 + 1, d;
end

-- A hit of a spot's spell on enemy `id` at `at` (each one in the feed, whether or not it can be
-- placed): it counts for the tick due then of each of the spell's spots that has one, as one of
-- the enemies that tick hit. The first tick's first hit says when the cast was.
local function TickHit(def, id, at)
	for i = 1, table.getn(spots) do
		local t = spots[i];
		if ( t.id == def.id and t.cands and at > t.tickAt - 0.2 and at < t.tickAt + t.every / 2 ) then
			t.ids[id] = true;
			if ( t.tickN == 0 ) then
				t.firstAt = math.min(t.firstAt or at, at);
			end
		end
	end
end

-- A hit of a spot's spell at x, y. It belongs to the nearest spot it fits; else to a spot placed
-- at a cast that no hit has landed in yet; else, while the spell list has shown none of the
-- spell's casts this run, it starts a spot of its own, if the spell can have another out (as many
-- as its duration spans cooldowns). Once it has, every storm has its cast's spot, and a hit none
-- takes is a stray. A spot of hits alone sits where they centre until it shows (a cast the list
-- shows late takes it over first), then stays. z: the hit's height; a spot of hits alone is drawn
-- at theirs.
local function SpotHit(def, x, y, now, R, dur, ev, freed, z)
	local s, near, fresh, live, latest = nil, nil, nil, 0, nil;
	local unit = ev and ( ev.targetUnitId or ev.targetId );
	for i = 1, table.getn(spots) do
		local t = spots[i];
		if ( t.id == def.id and now - t.at < t.dur + 0.5 ) then
			live, latest = live + 1, t;
			local ok, d = Fits(t, x, y, R);
			if ( ok and ( not near or d < near ) ) then
				s, near = t, d;
			end
			if ( t.cands and table.getn(t.xs) == 0 ) then
				fresh = t;
			end
		end
	end
	-- (one set at your feet is where it is: a hit off it isn't its)
	s = s or ( not def.atFeet and fresh ) or nil;
	if ( s and near and def.freeFall ) then
		-- a free one's: not a hit nearer one of its spell's own casts
		for i = 1, table.getn(spots) do
			local t = spots[i];
			local dx, dy = x - t.x, y - t.y;
			if ( t.id == def.freeFall and now - t.at < t.dur + 0.5 and dx * dx + dy * dy < near ) then
				return;
			end
		end
	end
	-- a cast that found no enemies to land on (the enemy list held none near you): its first hits
	-- place its spot, as they do before the spell list has shown a cast
	local blind = fx.blind[def.id];
	if ( blind and now - blind > (def.firstTick or FIRST_TICK) + 2.5 ) then
		fx.blind[def.id], blind = nil, nil;
	end
	if ( not s and fx.spotCast[def.id] and not blind ) then
		-- a stray: the first few of each storm go in the spot log
		if ( latest ) then
			latest.strays = (latest.strays or 0) + 1;
			if ( latest.strays <= 6 ) then
				SpotLog({ ev = "stray", id = def.id, at = XY(x, y), spot = XY(latest.x, latest.y), unit = unit,
					spell = ev and ev.spellId, name = ev and ev.abilityName, periodic = ev and ev.periodic,
					source = ev and ev.meterSourceKey, effect = ev and ev.effect });
			end
		end
		return;
	elseif ( not s and def.freeFall ) then
		-- one that fell on its own (Rain of Chaos), unless the hit is of one of the spell's own casts
		-- (a spot of def.freeFall's has it, or the spell list showed a cast just then): it fell its
		-- first tick's time before this, its first hit, where the spell lands from where the
		-- enemies stood then (one set at your feet: where you stood). Placed that once.
		local own = byId[def.freeFall];
		local c = own and SpellOf(own);
		local at = (ev and ev.shownAt or now) - (def.firstTick or FIRST_TICK);
		for i = 1, table.getn(spots) do
			local t = spots[i];
			local dx, dy = x - t.x, y - t.y;
			if ( t.id == def.freeFall and now - t.at < t.dur + 0.5 and dx * dx + dy * dy <= (R + 2) * (R + 2) ) then
				return;
			end
		end
		if ( c and c.sureAt and math.abs(at - c.sureAt) < 1 ) then
			return;
		end
		local q = Blend(at);
		local fx, fy, fz = nil, nil, nil;
		if ( q and def.atFeet ) then
			fx, fy, fz = q.px, q.py, q.pz;
		elseif ( q ) then
			local _, _, _, _, best = LandingSpot(q, def.range or 30, R);
			if ( best ) then
				fx, fy, fz = best.x, best.y, best.z;
			end
		end
		SpotLog({ ev = "fall", id = def.id, spot = fx and XY(fx, fy) or "none", late = math.floor((now - at) * 100) / 100 });
		if ( not fx ) then
			return;
		end
		s = { id = def.id, at = at, dur = dur, x = fx, y = fy, z = fz, xs = {}, ys = {}, shown = true, r = R };
		table.insert(spots, s);
	elseif ( not s ) then
		local c = SpellOf(def);
		if ( def.atFeet or freed or ( not blind and live >= ((c and c.max and c.max > 0) and math.ceil(dur / c.max) or 2) ) ) then
			-- one set at your feet shows only with its cast: its hits alone don't say where you stood;
			-- with a free one out, hits with no cast are the free one's
			return;
		end
		s = { id = def.id, at = now, dur = dur, x = x, y = y, z = z, xs = {}, ys = {} };
		table.insert(spots, s);
		if ( blind ) then
			-- that cast's: shown at once (settling where its hits land for a second), ending when its
			-- storm does
			s.dur = math.max(1, dur - (now - blind));
			s.shown, s.settle = true, now + 1;
			fx.blind[def.id] = nil;
			AST.Trail(now, "spot " .. def.id .. ": placed by its hits (its cast found no enemies)");
		end
	end
	table.insert(s.xs, x);
	table.insert(s.ys, y);
	if ( z ) then
		s.zsum, s.zn = (s.zsum or 0) + z, (s.zn or 0) + 1;
	end
	-- a tick past the time it was given: it lasts longer than its tooltip said, so it runs on
	local when = ev and ev.shownAt or now;
	if ( when - s.at > s.dur - 0.03 ) then
		s.dur = when - s.at + 0.1;
	end
	if ( table.getn(s.xs) > 40 ) then
		table.remove(s.xs, 1);
		table.remove(s.ys, 1);
	end
	-- a cast's spot stays where the cast put it
	if ( not s.cands and ( not s.shown or ( s.settle and now < s.settle ) ) ) then
		s.x, s.y = Middle(s.xs, s.ys);
		if ( s.zn ) then
			s.z = s.zsum / s.zn;
		end
	end
	if ( table.getn(s.xs) <= 12 ) then
		SpotLog({ ev = "hit", id = def.id, at = XY(x, y), spot = XY(s.x, s.y), unit = unit,
			spell = ev and ev.spellId, name = ev and ev.abilityName, periodic = ev and ev.periodic,
			source = ev and ev.meterSourceKey, effect = ev and ev.effect });
	end
end

-- An effect went off at x, y (z: its height; nil: drawn at yours).
local function Fire(def, x, y, now, cap, z)
	if ( cap and lastFire[def.id] and now - lastFire[def.id] < 1 / cap ) then
		return;
	end
	lastFire[def.id] = now;
	fired[def.id] = (fired[def.id] or 0) + 1;
	table.insert(rings, { kind = def.id, x = x, y = y, z = z, at = now });
end

-- The bodies a burst's hits `b` went off from (atKill), each flashed once: those that died lately
-- the way it needs (by: Judgement's kills; needs: with your Rupture on them) all went off, so each
-- with a hit within its reach does; for one that may or may not go off (Redemption's chance),
-- the fewest bodies the hits fit around, latest first. Hits around a body that flashed already are
-- its late ones. Hits no body takes (their death unseen): one flash where they centre, if no body
-- flashed for these.
local function KillBursts(a, b, now)
	local reach, window = (a.size + 1.5) * (a.size + 1.5), DotWindow();
	local need = a.def.needs and a.def.needs[a.has];
	local sure, left, n, any = a.def.by or need, {}, table.getn(b.xs), false;
	local function Near(d, i)
		local dx, dy = b.xs[i] - d.x, b.ys[i] - d.y;
		return dx * dx + dy * dy <= reach;
	end
	for i = 1, n do
		left[i] = true;
		for k = 1, table.getn(fx.bodies) do
			local d = fx.bodies[k];
			if ( d.shown and d.shown[a.def.id] and now - d.at < 3 and Near(d, i) ) then
				left[i] = nil;
			end
		end
	end
	while ( true ) do
		local best, most = nil, 0;
		for k = table.getn(fx.bodies), 1, -1 do
			local d = fx.bodies[k];
			if ( now - d.at < 3 and not ( d.shown and d.shown[a.def.id] )
				and ( not a.def.by or ( d.ev and KilledBy(d.ev, a.def.by) ) )
				and ( not need or Afflicted(need, d.t, d.at, window) ) ) then
				local count = 0;
				for i = 1, n do
					if ( ( sure or left[i] ) and Near(d, i) ) then
						count = count + 1;
					end
				end
				if ( count > most ) then
					best, most = d, count;
				end
			end
		end
		if ( not best ) then
			break;
		end
		best.shown = best.shown or {};
		best.shown[a.def.id] = true;
		for i = 1, n do
			if ( Near(best, i) ) then
				left[i] = nil;
			end
		end
		any = true;
		Fire(a.def, best.x, best.y, now, a.def.cap, best.z);
	end
	local xs, ys, zs = {}, {}, {};
	for i = 1, n do
		if ( left[i] ) then
			table.insert(xs, b.xs[i]);
			table.insert(ys, b.ys[i]);
			table.insert(zs, b.zs[i]);
		end
	end
	if ( not any and table.getn(xs) > 0 ) then
		local x, y = Middle(xs, ys);
		Fire(a.def, x, y, now, a.def.cap, fx.Mean(zs));
	end
end

-- A burst's hits in this read of the feed (active: as PollEvents has them; p: where you are).
local function FlushBursts(now, p, active)
	-- a burst's hits in this read: one flash where they centre, or, for one that goes off from a
	-- body (atKill), on each body it went off from (KillBursts). One that goes off around you
	-- (atHero: a free trap) counts when they centre within its reach of you and your own cast of it
	-- (ownSpell) isn't what they are; its flash is where you are.
	for j = 1, table.getn(active) do
		local a = active[j];
		local b = fx.bursts[a.def.id];
		local own = b and a.def.atHero and a.def.ownSpell and cds[Norm(a.def.ownSpell)];
		if ( b and a.def.atHero ) then
			local x, y = Middle(b.xs, b.ys);
			if ( (x - p.x) * (x - p.x) + (y - p.y) * (y - p.y) <= a.size * a.size
				and not ( own and ( (own.left or 0) <= 0.5 or ( own.castAt and math.abs(now - own.castAt) < 1.2 ) ) ) ) then
				Fire(a.def, p.x, p.y, now, a.def.cap, p.z);
			end
			fx.bursts[a.def.id] = nil;
		elseif ( b and a.def.atKill ) then
			KillBursts(a, b, now);
			fx.bursts[a.def.id] = nil;
		elseif ( b ) then
			local x, y = Middle(b.xs, b.ys);
			Fire(a.def, x, y, now, a.def.cap, fx.Mean(b.zs));
			fx.bursts[a.def.id] = nil;
		end
	end
end

-- active: the enemy effects your hero has, { def, has } each. onShield: a shield burst's own
-- damage was seen.
local function PollEvents(now, p, active, onShield)
	-- every 0.1 sec of GetTime()'s, the game standing still or not: the feed keeps 5 sec of them
	local real = now + clockGap;
	if ( real < feed.ctNext or type(AZS_GetCombatTextEvents) ~= "function" ) then
		return;
	end
	feed.ctNext = real + 0.1;
	local res, err = AZS_GetCombatTextEvents(feed.ctCursor, 256);
	if ( not res ) then
		feed.ctStatus = "feed: " .. ErrText(err);
		if ( type(err) == "table" and ( err.code == "STREAM_CHANGED" or err.code == "INVALID_ARGUMENT" ) ) then
			feed.ctCursor, feed.ctPrimed = nil, false;
		end
		return;
	end
	feed.ctCursor = res.nextCursor or res.cursor or feed.ctCursor;
	local events = Entries(res, "events") or {};
	-- the feed's clock now, for when each hit was shown
	local clock = tonumber(res.clockSeconds);
	if ( not feed.ctPrimed ) then
		-- the feed keeps 5 seconds: those happened before we looked
		feed.ctPrimed = true;
		feed.ctStatus = "listening";
		return;
	end
	local wantKills, wantCrits, wantHits = false, false, false;
	for i = 1, table.getn(active) do
		local trigger = active[i].def.trigger;
		if ( trigger == "kill" ) then
			wantKills = true;
		elseif ( trigger == "crit" ) then
			wantCrits = true;
		else
			-- a hit effect, a spot's hits, a burst's
			wantHits = true;
		end
		-- a burst that goes off from a body needs to know where enemies die
		wantKills = wantKills or active[i].def.atKill;
	end
	-- lastOf: each target's last hit in this batch, the blow that killed it if it died
	local ids, evs, lastOf = {}, {}, {};
	for i = 1, table.getn(events) do
		local ev = events[i];
		if ( type(ev) == "table" and ev.kind ~= "miss" ) then
			feed.lastEvent = ev;
			local keys = HitKeys(ev);
			-- an effect's own damage: your hero has it, and it just went off
			for j = 1, table.getn(DEFS) do
				local def = DEFS[j];
				if ( def.match ) then
					for k = 1, table.getn(def.match) do
						if ( keys[def.match[k]] ) then
							fx.learned[def.match[k]] = now;
							ev.effect = def.id;
						end
					end
				end
			end
			if ( ev.effect and byId[ev.effect] and byId[ev.effect].buffSpells ) then
				-- a shield burst's own damage
				onShield(now);
			end
			ProcHits(ev, now);
			local t = ev.targetId or ev.targetUnitId;
			local unit, shown = ev.targetUnitId or ev.targetId, tonumber(ev.presentedAt);
			if ( shown and clock ) then
				shown = now - (clock - shown);
			elseif ( shown and shown > real - 10 and shown < real + 0.5 ) then
				shown = shown - clockGap;
			else
				shown = now;
			end
			ev.shownAt = shown;
			for j = 1, table.getn(active) do
				if ( unit and active[j].def.shape == "ground" and KilledBy(ev, active[j].def.on) ) then
					TickHit(active[j].def, unit, shown);
				end
			end
			if ( t and Truthy(ev.periodic) ) then
				local dot = DotOf(ev, keys);
				if ( dot ) then
					fx.dots[dot] = fx.dots[dot] or {};
					fx.dots[dot][t] = now;
				end
			end
			if ( ev.anchorId and ev.anchorStatus ~= "unavailable" and table.getn(ids) < 256
				and ( wantKills or ( wantCrits and Truthy(ev.critical) ) or ( wantHits and HitTrigger(ev, active) ) ) ) then
				table.insert(ids, tostring(ev.anchorId));
				table.insert(evs, ev);
				if ( t ) then
					lastOf[t] = table.getn(evs);
				end
			end
		end
	end
	if ( table.getn(ids) > 0 ) then
		local pres, perr = AZS_ProjectCombatTextAnchors(ids, "impact");
		local list = Entries(pres);
		if ( not list ) then
			feed.ctStatus = "projection: " .. ErrText(perr);
			return;
		end
		local window = DotWindow();
		for i = 1, table.getn(ids) do
			local ev, e = evs[i], list[i];
			if ( type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" ) then
				feed.lastProjection = e;
				-- where it is, at its enemy's own height (z)
				local x, y, z = fx.HitSpot(e.x, e.y, p, now);
				if ( x ) then
					local t = ev.targetId or ev.targetUnitId or ev.anchorId;
					-- a combat text anchor's target: "alive", "dead" or "unavailable"
					if ( e.targetState == "dead" and not fx.killed[t] ) then
						-- a kill: each kill effect your hero has, if the enemy died the way it needs
						-- (with your DoT on it, by the right spells)
						fx.killed[t] = now;
						local killer = evs[lastOf[t] or i];
						-- the body, who it was and what killed it (for the bursts that go off from one)
						table.insert(fx.bodies, { x = x, y = y, z = z, at = now, t = t, ev = killer });
						if ( table.getn(fx.bodies) > 24 ) then
							table.remove(fx.bodies, 1);
						end
						for j = 1, table.getn(active) do
							local a = active[j];
							if ( a.def.trigger == "kill" ) then
								local need = a.def.needs and a.def.needs[a.has];
								if ( ( not need or Afflicted(need, t, now, window) )
									and ( not a.def.by or KilledBy(killer, a.def.by) ) ) then
									Fire(a.def, x, y, now, owned.caps[a.has] or a.def.cap, z);
								end
							end
						end
					end
					for j = 1, table.getn(active) do
						local a = active[j];
						local need = a.def.needs and a.def.needs[a.has];
						-- a hit effect, on a target with your DoT on it if it needs one (Conflagrate: Immolate)
						if ( a.def.trigger == "hit" and ev.effect ~= a.def.id and Hits(ev, a.def.on)
							and ( not need or Afflicted(need, t, now, window) ) ) then
							Fire(a.def, x, y, now, owned.caps[a.has] or a.def.cap, z);
						elseif ( a.def.shape == "ground" and KilledBy(ev, a.def.on) ) then
							SpotHit(a.def, x, y, now, a.size, a.dur, ev, a.freed, z);
						elseif ( a.def.trigger == "burst" and KilledBy(ev, a.def.on) ) then
							local b = fx.bursts[a.def.id] or { xs = {}, ys = {}, zs = {} };
							fx.bursts[a.def.id] = b;
							table.insert(b.xs, x);
							table.insert(b.ys, y);
							table.insert(b.zs, z);
						end
					end
					if ( Truthy(ev.critical) and not ( ev.effect and byId[ev.effect] and byId[ev.effect].trigger == "crit" ) ) then
						-- a crit, not the splash's own
						for j = 1, table.getn(active) do
							local a = active[j];
							if ( a.def.trigger == "crit" ) then
								Fire(a.def, x, y, now, owned.caps[a.has] or a.def.cap, z);
							end
						end
					end
				end
			end
		end
	end
	feed.ctStatus = "listening";
	FlushBursts(now, p, active);
	for t, at in pairs(fx.killed) do
		if ( now - at > 3 ) then
			fx.killed[t] = nil;
		end
	end
	for _, list in pairs(fx.dots) do
		for t, at in pairs(list) do
			if ( now - at > 10 ) then
				list[t] = nil;
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Each frame

-- (Lua 5.0 lets one function reach at most 32 of the file's locals, so a frame's work is split
-- into the pieces below.)

local lastNow, effectsRun;
local preview = {};    -- by id: the time a Test press ends
local info = {};       -- by id: what the options window shows
local drawCalls, drawnQuads = 0, 0;


-- A new run: what was learned about the last one goes.
local function CheckRun()
	local run = AZS_ZONE and AZS_ZONE.run;
	if ( run ~= effectsRun ) then
		effectsRun = run;
		fx.learned, rings, fx.killed, lastFire = {}, {}, {}, {};
		fx.procHit, fx.dots, spots, fx.spotCast, sizes, fx.lags = {}, {}, {}, {}, {}, {};
		fx.blind, fx.blindSaid = {}, nil;
		for id in pairs(procs) do
			procs[id] = nil;
		end
		owned.at, owned.loadoutRead, owned.freeGoes = -100, nil, {};
		meter.at, meter.asks, meter.list, meter.status = -100, 0, {}, "not read yet";
		meter.talents, meter.sources = nil, nil;
	end
end

-- The class of the hero this run, which can change from one run to the next: the run's line
-- says (its class key, or the class's name when the key is a number), else the client.
local CLASS_IDS = { [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue", [5] = "priest",
	[7] = "shaman", [8] = "mage", [9] = "warlock", [11] = "druid" };

local runClass;          -- the class the last run's line gave, kept between runs

local function ClassNow()
	local c = type(AZS_ZONE) == "table" and AZS_ZONE.class;
	if ( type(c) == "number" ) then
		c = CLASS_IDS[c] or AZS_ZONE.cname;
	end
	if ( type(c) == "string" and c ~= "" ) then
		runClass = string.lower(c);
	end
	if ( runClass ) then
		return runClass;
	end
	local _, t = nil, nil;
	if ( UnitClass ) then
		_, t = UnitClass("player");
	end
	return type(t) == "string" and t ~= "" and string.lower(t) or nil;
end

-- Your class's telegraphs and the common ones, with the gear, DoTs, auras and talents they go by.
-- False while the client can't tell your class yet.
local function SetupClass()
	local token = ClassNow();
	if ( not token ) then
		return false;
	end
	local changed = myClass ~= nil and myClass ~= token;
	myClass = token;
	DEFS, byId, GEAR, DOTS, AURAS, TALENT_KEYS, skipped = {}, {}, {}, {}, {}, {}, {};
	local others = IsAddOnLoaded and IsAddOnLoaded("PriestTelegraphs");
	local groups = { myClass, "common", "lab" };
	for g = 1, table.getn(groups) do
		local r = REGISTRY[groups[g]];
		if ( r ) then
			for i = 1, table.getn(r.defs) do
				local def = r.defs[i];
				def.group = groups[g];
				if ( others and PRIEST_TELEGRAPHS[def.id] ) then
					table.insert(skipped, def.name);
				else
					table.insert(DEFS, def);
					byId[def.id] = def;
					for k = 1, table.getn(def.talentKeys or {}) do
						TALENT_KEYS[def.talentKeys[k]] = true;
					end
					if ( db ) then
						Settings(def);
					end
				end
			end
			for i = 1, table.getn(r.gear) do
				table.insert(GEAR, r.gear[i]);
			end
			for key, dot in pairs(r.dots) do
				DOTS[key] = dot;
			end
			for i = 1, table.getn(r.auras) do
				table.insert(AURAS, r.auras[i]);
			end
		end
	end
	owned.at = -100;
	if ( changed ) then
		-- a hero of another class: the last one's effects go, and the options follow
		rings, spots = {}, {};
		for id in pairs(procs) do
			procs[id] = nil;
		end
		AST.ClassChanged(myClass);
	end
	return true;
end

-- Downed teammates with a position on your map, and how far your own revive of one has got.
local function DownedList()
	local list = type(AZS_GetDownedPartyMembers) == "function" and AZS_GetDownedPartyMembers();
	if ( type(list) ~= "table" ) then
		return {};
	end
	local rev = (type(AZS_GetRevive) == "function" and AZS_GetRevive()) or {};
	local out = {};
	for i = 1, table.getn(list) do
		local d = list[i];
		if ( type(d) == "table" and d.positionAvailable and type(d.x) == "number" and type(d.y) == "number" ) then
			local mine = rev.reviving ~= nil and rev.reviving ~= ""
				and ( tostring(rev.reviving) == tostring(d.id) or rev.reviving == d.name );
			table.insert(out, { x = d.x, y = d.y, z = type(d.z) == "number" and d.z or nil,
				progress = mine and tonumber(rev.rshare) or nil });
		end
	end
	return out;
end

-- Rings around downed teammates (rel: yards from you, for a Test press).
local function DrawDowned(j, p)
	for i = 1, table.getn(j.downed) do
		local d = j.downed[i];
		local cu, cv = d.x, d.y;
		if ( not d.rel ) then
			cu, cv = d.x - p.x, d.y - p.y;
			-- at the height they lie at
			H.dz = d.z and d.z - p.z or 0;
		end
		DrawCircleAt(cu, cv, j.size, j.st, j.alpha, d.progress, nil);
		H.dz = 0;
	end
end

-- A shield burst's own damage came through: the shield broke now.
local function OnShieldBurst(now)
	if ( not shield.brokeAt or now - shield.brokeAt > 0.5 ) then
		shield.brokeAt = now;
	end
	shield.up = false;
end

-- An enemy effect's rings where it went off, growing to their size as they fade; a Test press
-- shows three near the hero, one after another.
local function DrawRings(j, p, now)
	local st = j.st;
	if ( j.test ) then
		for k = 0, 2 do
			local age = j.test - k * 0.8;
			if ( age >= 0 and age < st.flash ) then
				local a = k * 2.1;
				DrawCircleAt(8 * math.cos(a), 8 * math.sin(a), j.size * (0.6 + 0.4 * age / st.flash), st,
					j.alpha * (1 - age / st.flash), nil, nil, 0, 1);
			end
		end
	end
	-- the newest first; with a cap set (st.most > 0), only that many
	local drawn = 0;
	for k = table.getn(rings), 1, -1 do
		local r = rings[k];
		local age = now - r.at;
		if ( age > 2 ) then
			table.remove(rings, k);
		elseif ( r.kind == j.def.id and age < st.flash and ( st.most <= 0 or drawn < st.most ) ) then
			drawn = drawn + 1;
			-- at the height it went off at, not yours
			H.dz = r.z and r.z - p.z or 0;
			DrawCircleAt(r.x - p.x, r.y - p.y, j.size * (0.6 + 0.4 * age / st.flash), st,
				1 - age / st.flash, nil, nil, 0, 1);
			H.dz = 0;
		end
	end
end

-- A spell's spots on the ground, each filling as its time runs; a cast puts one where the spell
-- lands. A Test press shows one near the hero.
local function DrawSpots(j, p, now)
	local def, st = j.def, j.st;
	-- with its duration fill turned off, each spot is drawn whole for as long as it lasts
	if ( j.test ) then
		DrawSpot(6, 3, j.size, st, j.alpha, st.durFill and math.min(1, j.test / 3) or 1);
		return;
	end
	local c = SpellOf(def);
	local range, every, first = def.range or 30, def.every or 1, def.firstTick or FIRST_TICK;
	local T = AST.trail;
	if ( T and def.spellKey ) then
		T.keys[Norm(def.spellKey)] = true;
		if ( not T.state[def.id] or now - T.state[def.id] >= 2 or now < T.state[def.id] ) then
			T.state[def.id] = now;
			local alive = 0;
			for k = 1, table.getn(spots) do
				if ( spots[k].id == def.id and ( spots[k].cands or spots[k].shown ) ) then
					alive = alive + 1;
				end
			end
			AST.Trail(now, string.format("state %s: %d spots, size %.1f, lasts %.1f, %s, enemies kept %d (%s)", def.id, alive, j.size or -1,
				j.dur or -1, c and string.format("cooldown %.2f of %.2f, sure %.1f ago%s", c.left or -1, c.max or -1,
				c.sureAt and (now - c.sureAt) or -1, c.waits and ", waits" or "") or "not in the spell list",
				table.getn(fx.past), fx.past[table.getn(fx.past)] and string.format("%d near, %.1f ago",
				fx.past[table.getn(fx.past)].n or -1, now - fx.past[table.getn(fx.past)].at) or "none") .. "; " .. fx.ReadText());
		end
	end
	-- a set that makes the spell move with you (Consecration with the Uncommon paladin set, Volley
	-- with the Epic hunter set, Blizzard with the Epic mage set): its spots stay on you, so one cast
	-- on a group comes to you at once
	local follows = def.follows and owned.keys[def.follows];
	local newest;
	if ( def.freeFall or def.atFeet ) then
		-- one that falls on its own (Rain of Chaos): its first tick places it afterwards, from where
		-- the enemies stood a moment before, so those are kept all along; one set at your feet: where
		-- you stood, every frame, for the moment it went down
		Remember(p, now, range + j.size, def.atFeet);
	end
	if ( c ) then
		-- every frame from just before its cooldown is up until a while after (it may wait), and
		-- around each tick of its spots; every 0.1 sec in the last second of its cooldown. Up is
		-- when the line's countdown says (a cast can come sooner than a whole cooldown after the
		-- last: haste, a reset), or a whole cooldown after the last cast, whichever is sooner.
		local left = math.min(c.left or 0, c.sureAt and (c.max or 0) - (now - c.sureAt) or 1e9);
		local close = left < 0.3 and left > -1.5;
		for k = 1, table.getn(spots) do
			local t = spots[k];
			if ( t.id == def.id and t.cands and math.abs(now - t.tickAt) < 0.06 ) then
				close = true;
			end
		end
		if ( close or left < 1 ) then
			Remember(p, now, range + j.size, close);
		end
	end
	-- a cast the spell list shows (not one the local clock only guessed: the spell may be waiting)
	if ( c and c.sureAt and c.sureAt ~= fx.spotCast[def.id] and now - c.sureAt < 2 ) then
		fx.spotCast[def.id] = c.sureAt;
		-- when it went off: as long before the list came as its first ticks have said, once that has
		-- held steady over three casts; until then when it came (a line whose cooldown has clearly
		-- run already: that long before)
		local base = c.cameAt or c.sureAt;
		local at, L = ( (c.ran or 0) < 0.15 and base ) or c.sureAt, fx.lags[def.id];
		if ( L and table.getn(L) >= 3 ) then
			local sorted = {};
			for i = 1, table.getn(L) do
				sorted[i] = L[i];
			end
			table.sort(sorted);
			if ( sorted[table.getn(sorted)] - sorted[1] <= 0.05 ) then
				at = base - math.max(0, math.min(0.3, sorted[math.floor((table.getn(sorted) + 1) / 2)]));
			end
		end
		-- where the enemies stood then, or (that long ago not kept) where they are now
		Remember(p, now, range + j.size, true);
		local q = Blend(at) or fx.past[table.getn(fx.past)];
		local x, y, cands, most, best, z;
		if ( def.atFeet or follows ) then
			-- set where you stood (a trap, or one that moves with you), or `offset` yd ahead of where you
			-- face (a totem): the one spot it can be, so it stays there as it is, its size the
			-- tooltip's; at the height you stood at
			x, y, z, most = q.px, q.py, q.pz, 0;
			if ( def.offset ) then
				local f = (db.mirror and -(p.facing or 0) or (p.facing or 0)) + (db.rotate or 0) * PI / 180;
				x, y = x + def.offset * math.cos(f), y + def.offset * math.sin(f);
			end
			cands = { { x = x, y = y, n = 0 } };
		else
			-- on an enemy: at its height
			x, y, cands, most, best = LandingSpot(q, range, j.size);
			z = best and best.z;
		end
		if ( T ) then
			AST.Trail(now, string.format("spot %s: %s, %d candidates, %s near it, %.1f yd, from enemies %.2f sec off; %s", def.id,
				x and XY(x - q.px, y - q.py) or "none", table.getn(cands or {}), tostring(most), j.size or -1, q.at - at, fx.ReadText()));
		end
		-- none to land on read near you: the cast's first hits place its spot (SpotHit)
		fx.blind[def.id] = not x and at or nil;
		if ( not x and not fx.blindSaid and fx.SaveDump ) then
			-- the first time a run: a snapshot of what led to it, and a line saying so
			fx.blindSaid = true;
			fx.SaveDump(now, def);
		end
		SpotLog({ ev = "cast", id = def.id, hero = XY(q.px, q.py), spot = x and XY(x, y) or "none",
			candidates = table.getn(cands), most = most, late = math.floor((now - at) * 100) / 100,
			lag = math.floor((base - at) * 1000) / 1000, seen = math.floor((q.at - at) * 100) / 100,
			r = math.floor(j.size * 100) / 100, tip = j.tip });
		if ( x ) then
			-- a spot its hits started before the list showed the cast is this one
			local s;
			for k = table.getn(spots), 1, -1 do
				local t = spots[k];
				if ( t.id == def.id and not t.cands and not t.shown and t.at > at - 0.3 and not def.atFeet ) then
					if ( s ) then
						for i = 1, table.getn(t.xs) do
							table.insert(s.xs, t.xs[i]);
							table.insert(s.ys, t.ys[i]);
						end
						table.remove(spots, k);
					else
						s = t;
					end
				end
			end
			if ( not s ) then
				s = { id = def.id, dur = j.dur, xs = {}, ys = {} };
				table.insert(spots, s);
			end
			s.x, s.y, s.z, s.at, s.cands, s.tip, s.r = x, y, z, at, cands, j.tip, j.size;
			s.every, s.tickAt, s.tickN, s.ids, s.lag = every, at + first, 0, {}, base - at;
			if ( j.tip and not ( def.atFeet or follows ) ) then
				-- with which of the radii its tooltip allows each enemy would have been the spot
				PickRanges(q, cands, TipRange(j.tip));
			end
		end
	end
	for k = table.getn(spots), 1, -1 do
		local s = spots[k];
		local age = now - s.at;
		if ( s.id == def.id and s.cands and not s.tickq and now > s.tickAt ) then
			-- where the enemies stood as its tick went off, before the frames either side of it go
			s.tickq = Blend(s.tickAt);
		end
		if ( s.id == def.id and s.cands and s.tickAt < s.at + s.dur and now >= s.tickAt + s.every / 2 ) then
			-- the hits of its first tick are in (the one whose time is sure: `first` after the cast):
			-- they tell the spell's size, unless another of its spots ticked about then too
			local mixed = false;
			for i = 1, table.getn(spots) do
				local t = spots[i];
				if ( t ~= s and t.id == def.id and t.cands ) then
					local a = s.tickAt - t.at - first;
					local off = a - math.floor(a / t.every) * t.every;
					if ( a > -0.25 and a < t.dur and ( off < 0.25 or off > t.every - 0.25 ) ) then
						mixed = true;
					end
				end
			end
			if ( not mixed and s.tip and not ( def.atFeet or follows ) ) then
				Learn(s, def, s.tickq, s.ids);
			end
			if ( s.firstAt and not mixed ) then
				-- its first tick went off `first` after the cast: how late the list showed it
				local L = fx.lags[def.id] or {};
				fx.lags[def.id] = L;
				table.insert(L, s.lag + (s.tickAt - s.firstAt));
				if ( table.getn(L) > 8 ) then
					table.remove(L, 1);
				end
				SpotLog({ ev = "lag", id = def.id, lag = math.floor(L[table.getn(L)] * 1000) / 1000 });
			end
			-- the later ticks' times are less sure: done with it
			s.tickAt, s.tickN, s.ids, s.tickq = 1e9, 1, {}, nil;
		end
		if ( s.id == def.id and not s.cands and not s.shown and age >= 1 ) then
			-- a spot of hits alone: no cast has taken it over, so it shows, and stays
			s.shown = true;
		end
		if ( age > s.dur + 0.4 ) then
			table.remove(spots, k);
		elseif ( s.id == def.id and ( s.cands or s.shown ) ) then
			-- gone in 0.4 sec once its time is up
			local fade = 1;
			if ( age > s.dur ) then
				fade = 1 - (age - s.dur) / 0.4;
			end
			if ( follows ) then
				-- one that moves with you is on you: the newest is drawn below, as a ring around you
				s.x, s.y, s.fade = p.x, p.y, fade;
				if ( not newest or s.at > newest.at ) then
					newest = s;
				end
			else
				-- at its own height, not yours: it stays on the ground where it is
				H.dz = s.z and s.z - p.z or 0;
				DrawSpot(s.x - p.x, s.y - p.y, s.r or j.size, st, j.alpha * fade, st.durFill and math.min(1, age / s.dur) or 1);
				H.dz = 0;
			end
		end
	end
	if ( newest ) then
		-- running: each lasts as long as the spell's cooldown or longer, so the next comes before it
		-- ends; unless the spell waits (Consecration, for enemies to come near): half a second past
		-- due, its time shows running out
		local age, cd = now - newest.at, c and c.max;
		local running = st.uptime and cd and cd > 0 and newest.dur >= cd and age < cd + 0.5;
		fx.Aura(newest.r or j.size, st, j.alpha * newest.fade, st.durFill and math.min(1, age / newest.dur) or nil,
			age, running, now);
	end
end

-- What to draw this frame: the jobs, the enemy effects your hero has, and whether the combat
-- text needs reading.
local function CollectJobs(now, inRun)
	local jobs, active, watch = {}, {}, false;
	-- a Test press runs on GetTime()'s clock: it plays out with the game standing still too
	local real = now + clockGap;
	-- your gear and talents (every 2 sec): effects need them, and so do the size formulas
	RefreshOwned(now);
	for i = 1, table.getn(DEFS) do
		local def = DEFS[i];
		local st = Settings(def);
		-- the showcase (Showcase.lua) lays its fuller look over the settings while it plays one
		if ( AST.showcase and AST.showcase.on ) then
			st = AST.showcase.Look(def, st);
		end
		local test = preview[def.id] and real < preview[def.id];
		local inf = info[def.id];
		if ( not inf ) then
			inf = {};
			info[def.id] = inf;
		end
		-- a free one (Free Consecration) goes with its spell's own telegraph: only while that is on,
		-- as its casts are what it is told apart from
		local main = def.freeFall and byId[def.freeFall];
		if ( ( st.enabled and not ( main and not Settings(main).enabled ) ) or test ) then
			local job = { def = def, st = st, alpha = 1 };
			local has, how;
			if ( def.match ) then
				-- an effect: the feed tells whether your hero has it, so it is read either way
				watch = true;
				has, how = Has(def, now);
				inf.has, inf.how = has, how;
			end
			-- the tooltip that sizes it: its own, or Holy Nova's for Chastise's novas. A spell the
			-- spell bar doesn't list (another race's racial) isn't on it to read.
			local sized = (def.sizeOf and byId[def.sizeOf]) or def;
			if ( sized.sizePattern and now - (tips.readAt[sized.id] or 0) > 1
				and not ( sized.kind == "Racial" and not SpellOf(sized) ) ) then
				ReadSize(sized, now);
				tips.readAt[sized.id] = now;
			end
			job.size, inf.source = SizeOf(def, st, now, has, has and owned.radii[has]);
			inf.size = job.size;
			local c = SpellOf(def);
			inf.known = c ~= nil;
			inf.left, inf.max = c and c.left, c and c.max;
			-- a skill the spell list may not show (unlisted): its being there tells your hero has it too
			if ( def.unlisted and c and not has ) then
				has, how = "listed", "the spell list";
				inf.has, inf.how = has, how;
			end
			if ( c and c.castAt ) then
				job.since = now - c.castAt;
			end
			-- a talent's own timer stands in for a cooldown (and is watched for its goes either way)
			inf.clockLeft = nil;
			if ( def.clock and has ) then
				local left, max = ClockOf(def, now);
				c = max and { left = left, max = max };
				inf.clockLeft = left;
				job.since = procs[def.id] and now - procs[def.id];
			end
			if ( test ) then
				-- a Test press: three seconds, as the chosen mode would look
				local t = 3 - (preview[def.id] - real);
				job.show = true;
				job.alpha = math.min(1, (preview[def.id] - real) / 0.5);
				if ( def.shape == "lab" ) then
					-- a Lab experiment: its own demo
					job.test = t;
				elseif ( def.shape == "world" ) then
					-- its own places near you (Guardians.lua)
					job.points = def.demo and def.demo(t) or {};
				elseif ( def.shape == "pins" ) then
					-- shown on the minimap, not here
					inf.test = t;
					job.show = false;
				elseif ( st.mode == "cooldown" ) then
					-- two cooldowns of 1.5 seconds (with its fill turned off, two casts)
					local cycle = t - math.floor(t / 1.5) * 1.5;
					job.progress = st.cdFill and cycle / 1.5 or nil;
					job.since = cycle;
				elseif ( def.shape == "enemy" or def.shape == "ground" ) then
					job.test = t;
				elseif ( def.shape == "downed" ) then
					-- a teammate down 7 yd away, being brought back
					job.downed = { { rel = true, x = 6, y = 3, progress = math.min(1, t / 2.5) } };
				else
					job.since = t;
				end
			elseif ( def.shape == "lab" ) then
				-- a Lab experiment: drawn through the telegraphs it fits (Lab.lua)
			elseif ( def.shape == "pins" ) then
				-- on the minimap (Guardians.lua draws them)
				inf.test = nil;
			elseif ( def.shape == "world" ) then
				-- places in the world it finds itself (a guardian's lair...), each drawn there
				job.points = def.points(now) or {};
				inf.count = table.getn(job.points);
				job.show = inRun and inf.count > 0;
			elseif ( def.match and not has and not def.showsItself ) then
				-- an effect your hero doesn't have: nothing to draw
			elseif ( def.shape == "downed" ) then
				job.downed = DownedList();
				inf.count = table.getn(job.downed);
				job.show = inRun and inf.count > 0;
			elseif ( def.shape == "ground" ) then
				-- a spell's spots on the ground: its casts and its hits place them
				watch = true;
				job.dur = DurationOf(def);
				if ( inf.source == "tooltip" ) then
					local closer;
					job.tip = job.size;
					job.size, closer = GroundSize(def, job.size);
					if ( closer ) then
						inf.size, inf.source = job.size, "tooltip, made closer by its hits";
					end
				end
				table.insert(active, { def = def, has = has, size = job.size, dur = job.dur });
				job.show = inRun;
			elseif ( st.mode == "proc" ) then
				-- it went off on its own: flash and send out a shockwave
				local at = procs[def.id];
				if ( at and now - at < st.flash ) then
					job.since = now - at;
					job.alpha = 1 - job.since / st.flash;
					job.show = inRun;
				end
			elseif ( st.mode == "cast" ) then
				if ( job.since and job.since < st.flash ) then
					job.alpha = 1 - job.since / st.flash;
					job.show = inRun;
				end
			elseif ( st.mode == "cooldown" ) then
				if ( c and c.max ) then
					-- with its fill turned off, a plain ring (a cast still sends out its shockwave)
					if ( st.cdFill ) then
						job.progress = 1 - c.left / c.max;
						if ( job.since and job.since < 0.25 ) then
							job.progress = 0;
						end
					end
					job.show = inRun;
				elseif ( def.unlisted and has ) then
					-- not in the spell list, but the meter's ability list has it: a plain ring
					job.show = inRun;
				end
			elseif ( st.mode == "shield" ) then
				UpdateShield(now, def);
				inf.shieldUp = shield.up;
				-- only when it bursts: as the shield breaks (not while it holds, nor when it runs out)
				if ( not has ) then
					-- no burst comes of your shield without Divine Aegis or the amulet
				elseif ( shield.brokeAt and now - shield.brokeAt < st.flash ) then
					job.show = inRun;
					job.since = now - shield.brokeAt;
					job.alpha = 1 - job.since / st.flash;
				end
			elseif ( st.mode == "event" ) then
				-- an item's or a talent's while your hero has it; a spell's own (Polymorph's) always
				if ( has or not def.match or def.showsItself ) then
					-- where it goes off comes from the combat text, so that is read
					watch = true;
					table.insert(active, { def = def, has = has, size = job.size });
					job.show = inRun;
				end
			else
				job.show = true;
			end
			if ( job.show ) then
				table.insert(jobs, job);
			end
		end
	end
	-- a spell whose free one is out: its hits with no cast start no spot of its own, as the free
	-- one places those (Rain of Fire's, with Rain of Chaos)
	for i = 1, table.getn(active) do
		local main = active[i].def.freeFall;
		for k = 1, ( main and table.getn(active) or 0 ) do
			if ( active[k].def.id == main ) then
				active[k].freed = true;
			end
		end
	end
	return jobs, active, watch;
end

local function RenderJobs(now, jobs, active, watch, inRun)
	local p, err = AZS_GetPlayerPosition();
	if ( not p ) then
		lastError = "player position: " .. ErrText(err);
		return;
	end
	if ( not BuildMap(p) ) then
		return;
	end
	if ( watch and inRun ) then
		PollEvents(now, p, active, OnShieldBurst);
	end
	local facing = p.facing or 0;
	if ( db.mirror ) then
		facing = -facing;
	end
	facing = facing + (db.rotate or 0) * PI / 180;
	-- the Lab (Lab.lua): its experiments that are on draw under, instead of or over the telegraphs
	local lab = AST.lab;
	if ( lab ) then
		lab.Frame(now);
	end
	for i = 1, table.getn(jobs) do
		local j = jobs[i];
		j.facing = facing;
		if ( lab ) then
			lab.Pre(j, p, now);
		end
		if ( lab and lab.Draw(j, p, now) ) then
			-- an experiment drew it
		elseif ( j.def.shape == "cone" ) then
			DrawCone(j);
		elseif ( j.def.shape == "circle" ) then
			DrawCircleAt(0, 0, j.size, j.st, j.alpha, j.progress, j.since);
		elseif ( j.def.shape == "downed" ) then
			DrawDowned(j, p);
		elseif ( j.def.shape == "world" ) then
			j.def.draw(j, p, now);
		elseif ( j.def.shape == "ground" ) then
			DrawSpots(j, p, now);
		else
			DrawRings(j, p, now);
		end
		if ( j.def.shape == "cone" or j.def.shape == "circle" ) then
			fx.Depth(j, p, now);
		end
		if ( lab ) then
			lab.Post(j, p, now);
		end
	end
	if ( lab ) then
		lab.After(p, now);
	end
end

local function Draw()
	drawCalls = drawCalls + 1;
	-- the Lab's FPS counter times each frame's telegraphs
	if ( AST.lab ) then
		AST.lab.Start();
	end
	local real = GetTime();
	local dt = real - (lastNow or real);
	lastNow = real;
	-- the telegraphs' clock runs while the game does (and out of a run): not while you choose an
	-- upgrade or a chest's prize, nor on the pause screen
	local phase = AZS_GetPhase and AZS_GetPhase();
	if ( phase ~= nil and phase ~= "playing" ) then
		clockGap = clockGap + dt;
	end
	local now = real - clockGap;
	if ( dt > 0.5 ) then
		dt = 0.5;
	end
	if ( not db ) then
		return;
	end
	-- your class decides the telegraphs, and a new run can bring a hero of another; all of them
	-- off from the minimap button's right-click
	if ( ClassNow() ~= myClass ) then
		SetupClass();
	end
	-- Hide all: nothing, unless the showcase is playing (it leaves Hide all as it is)
	if ( not myClass or ( db.hidden and not ( AST.showcase and AST.showcase.on ) ) ) then
		-- every piece goes: Core's, the textures and the texts (they'd stay on the screen as they were)
		FinishQuads();
		if ( AST.lab ) then
			AST.lab.Finish();
		end
		fx.TextsDone();
		return;
	end
	local inRun = phase ~= nil and phase ~= "dead" and phase ~= "victory";
	UpdateCooldowns(now, dt, phase == "playing");
	CheckRun();
	screenW, screenH = WorldFrame:GetWidth() or screenW, WorldFrame:GetHeight() or screenH;
	local jobs, active, watch = CollectJobs(now, inRun);
	if ( table.getn(jobs) > 0 or ( watch and inRun ) ) then
		RenderJobs(now, jobs, active, watch, inRun);
	end
	drawnQuads = used;
	-- level of detail for true circles: past 2500 pieces, the next frames' outlines spread their
	-- dots a little (eased, so it doesn't flicker); every shape is still drawn
	H.lod = math.max(1, math.min(1.25, H.lod * 0.9 + 0.1 * H.lod * used / 2500));
	FinishQuads();
	if ( AST.lab ) then
		AST.lab.Finish();
	end
	fx.TextsDone();
end

local function Start()
	if ( type(AZS_RegisterWorldAnchorFrameHandler) == "function" ) then
		-- runs after this frame's camera, so the telegraphs don't trail the hero by a frame
		AZS_RegisterWorldAnchorFrameHandler(Draw);
	elseif ( type(AZS_ProjectWorldAnchors) == "function" ) then
		canvas:SetScript("OnUpdate", Draw);
	else
		Print("this client has no world-anchor API, so nothing can be drawn.");
	end
end

---------------------------------------------------------------------------------------------
-- What the options window (Options.lua) reads and calls. The tables stay the same ones for
-- good; what is replaced as it changes comes through State() and Stats().

AST = {
	registry = REGISTRY, modes = MODES, solid = SOLID, round = ROUND, common = COMMON, SetPiece = SetPiece,
	Settings = Settings, ResetSettings = ResetSettings, SetupClass = SetupClass,
	info = info, preview = preview, fired = fired, shield = shield, meter = meter,
};

function AST.State()
	return db, DEFS, myClass, skipped, byId;
end

-- What the Lab (Lab.lua) draws with: Core's own pieces, and what it knows.
AST.draw = {
	Map = Map, Unmap = Unmap, H = H, PI = PI, canvas = canvas, SOLID = SOLID, ROUND = ROUND,
	Begin = function() PN = 0; end, Add = Add, AddArc = AddArc, FillPoly = FillPoly, Stroke = Stroke,
	Outline = Outline, Bright = Bright, Quad = Quad, Dot = Dot, DotArc = DotArc, DotFill = DotFill,
	Circle = DrawCircleAt, Cone = DrawCone, Spot = DrawSpot, Aura = fx.Aura, SpellOf = SpellOf,
	Scale = function() return scale; end, Spots = function() return spots; end,
	Rings = function() return rings; end, procs = procs, owned = owned, FIRST_TICK = FIRST_TICK,
	Text = fx.Text, Entries = Entries, Depth = fx.Depth,
};

function AST.Stats()
	return drawCalls, drawnQuads, lastError, spellKeys;
end

-- Always on: the ground spells' last 300 events (their spell lines, the casts seen, each spot placed or
-- not, their state every 2 sec), which /ast debug saves (db.debugDump; /reload writes it) for when a
-- spot telegraph stops showing.
AST.trail = { n = 0, list = {}, keys = {}, seen = {}, state = {} };
function AST.Trail(now, text)
	local T = AST.trail;
	T.list[T.n - math.floor(T.n / 300) * 300 + 1] = string.format("%.2f ", now) .. text;
	T.n = T.n + 1;
end
function AST.TrailList()
	local T, out = AST.trail, {};
	local first = math.max(0, T.n - 300);
	for i = first, T.n - 1 do
		table.insert(out, T.list[i - math.floor(i / 300) * 300 + 1]);
	end
	return out;
end

-- Until Options.lua has loaded.
function AST.ToggleOptions() end
function AST.RefreshOptions() end
function AST.ClassChanged() end

---------------------------------------------------------------------------------------------
-- The minimap button: left-click the options, right-click every telegraph off and on again,
-- drag it round the minimap's edge.

local minimapButton;

local function PlaceMinimapButton()
	local a = (db.minimapAngle or 225) * PI / 180;
	minimapButton:ClearAllPoints();
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a));
end

-- A spot on the minimap's edge, in degrees, clear of the buttons already there (the Damage
-- Meter's sits at the left) and on the screen: the free one nearest the bottom left.
local function FreeMinimapAngle()
	local cx, cy = Minimap:GetCenter();
	local ms = Minimap:GetEffectiveScale() or 1;
	local taken = {};
	local parents = { Minimap, MinimapCluster };
	for p = 1, 2 do
		local kids = parents[p] and parents[p].GetChildren and { parents[p]:GetChildren() } or {};
		for i = 1, table.getn(kids) do
			local k = kids[i];
			local x, y;
			if ( k ~= minimapButton and k.IsShown and k:IsShown() and k.GetCenter ) then
				x, y = k:GetCenter();
			end
			if ( x and y and cx and cy ) then
				-- each frame's center is in its own scale
				local s = (k:GetEffectiveScale() or 1) / ms;
				local dx, dy = x * s - cx, y * s - cy;
				local d = math.sqrt(dx * dx + dy * dy);
				if ( d > 50 and d < 115 ) then
					table.insert(taken, math.atan2(dy, dx) * 180 / PI);
				end
			end
		end
	end
	local w, h = UIParent:GetWidth(), UIParent:GetHeight();
	local us = UIParent:GetEffectiveScale() or 1;
	local best, bestGap;
	for n = 0, 24 do
		-- 225, 240, 210, 255, 195...: outward from the bottom left
		local a = 225 + 15 * math.floor((n + 1) / 2) * ((math.floor(n / 2) * 2 == n) and -1 or 1);
		a = a - 360 * math.floor(a / 360);
		local gap = 180;
		for i = 1, table.getn(taken) do
			local d = math.abs(a - taken[i]);
			d = d - 360 * math.floor(d / 360);
			if ( d > 180 ) then
				d = 360 - d;
			end
			gap = math.min(gap, d);
		end
		local onScreen = true;
		if ( w and h and cx and cy ) then
			local px = (cx + 80 * math.cos(a * PI / 180)) * ms / us;
			local py = (cy + 80 * math.sin(a * PI / 180)) * ms / us;
			onScreen = px > 16 and px < w - 16 and py > 16 and py < h - 16;
		end
		if ( onScreen and gap >= 30 ) then
			return a;
		end
		if ( onScreen and ( not bestGap or gap > bestGap ) ) then
			best, bestGap = a, gap;
		end
	end
	return best or 225;
end

local function MakeMinimapButton()
	if ( not Minimap or minimapButton ) then
		return;
	end
	local b = CreateFrame("Button", "ASTMinimapButton", Minimap);
	minimapButton = b;
	b:SetWidth(31);
	b:SetHeight(31);
	b:SetFrameStrata("MEDIUM");
	b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 10);
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
	local icon = b:CreateTexture(nil, "BACKGROUND");
	icon:SetTexture("Interface\\Icons\\Spell_Holy_HolyNova");
	icon:SetWidth(20);
	icon:SetHeight(20);
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5);
	local border = b:CreateTexture(nil, "OVERLAY");
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
	border:SetWidth(53);
	border:SetHeight(53);
	border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b:RegisterForDrag("LeftButton");
	b:SetScript("OnClick", function()
		if ( arg1 == "RightButton" ) then
			db.hidden = not db.hidden;
			Print(db.hidden and "every telegraph hidden: right-click the minimap button again to show them." or "telegraphs shown.");
			AST.RefreshOptions();
		else
			AST.ToggleOptions();
		end
	end);
	b:SetScript("OnDragStart", function()
		b:SetScript("OnUpdate", function()
			local x, y = GetCursorPosition();
			local s = Minimap:GetEffectiveScale();
			local cx, cy = Minimap:GetCenter();
			db.minimapAngle = math.atan2(y / s - cy, x / s - cx) * 180 / PI;
			PlaceMinimapButton();
		end);
	end);
	b:SetScript("OnDragStop", function()
		b:SetScript("OnUpdate", nil);
	end);
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(b, "ANCHOR_LEFT");
		GameTooltip:SetText("Azeroth Survivors Telegraphs");
		GameTooltip:AddLine(AST_L("Left-click: options"), 1, 1, 1);
		GameTooltip:AddLine(AST_L("Right-click: hide or show every telegraph"), 1, 1, 1);
		GameTooltip:AddLine(AST_L("Drag: move this button"), 1, 1, 1);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	PlaceMinimapButton();
	if ( not db.minimapAngle ) then
		-- its first spot, once the game and the other addons have put their buttons up; a drag
		-- before then wins
		local wait = 2;
		b:SetScript("OnUpdate", function()
			wait = wait - (arg1 or 0);
			if ( wait <= 0 ) then
				b:SetScript("OnUpdate", nil);
				db.minimapAngle = db.minimapAngle or FreeMinimapAngle();
				PlaceMinimapButton();
			end
		end);
	end
	if ( db.minimapHidden ) then
		b:Hide();
	end
end

-- /ast minimap and the options' General page.
local function ShowMinimapButton(show)
	db.minimapHidden = (not show) or nil;
	if ( minimapButton and show ) then
		minimapButton:Show();
	elseif ( minimapButton ) then
		minimapButton:Hide();
	end
end
AST.ShowMinimapButton = ShowMinimapButton;

---------------------------------------------------------------------------------------------
-- Slash commands, saved settings

local function Dump(t)
	if ( type(t) ~= "table" ) then
		return tostring(t);
	end
	local out = {};
	for k, v in pairs(t) do
		table.insert(out, tostring(k) .. "=" .. tostring(v));
	end
	return table.concat(out, ", ");
end

-- What the addon reads, for working out why a telegraph doesn't show.
-- A snapshot for the developer (/ast debug, or the first ground cast a run that finds no enemies
-- in the game's list: `def`): the ground spells' trail and state, the enemy list as it is now.
fx.SaveDump = function(now, def)
	db.debugDump = { at = now, clockGap = clockGap, phase = tostring(AZS_GetPhase and AZS_GetPhase()),
		run = tostring(AZS_ZONE and AZS_ZONE.run), spells = spellKeys, lastError = tostring(lastError),
		spots = table.getn(spots), frames = table.getn(fx.past), trail = AST.TrailList(), list = fx.ReadText(),
		why = def and ( def.name .. " found no enemies in the game's enemy list at its cast" ) or "/ast debug" };
	if ( def ) then
		Print(def.name .. "'s ring came from its hits this time: the game's enemy list had none near you at its cast ("
			.. fx.ReadText() .. "). A snapshot is saved; /reload writes it to the settings file.");
	end
end

local function PrintDebug()
	local now = GetTime() - clockGap;
	-- a snapshot for the developer: the ground spells' trail and state, the Lab's errors
	local errs = {};
	for id, e in pairs(AST.lab and AST.lab.errors or {}) do
		table.insert(errs, id .. ": " .. tostring(e));
	end
	db.debugDump = { at = now, clockGap = clockGap, phase = tostring(AZS_GetPhase and AZS_GetPhase()),
		run = tostring(AZS_ZONE and AZS_ZONE.run), spells = spellKeys, lastError = tostring(lastError),
		spots = table.getn(spots), frames = table.getn(fx.past), labErrors = errs, trail = AST.TrailList() };
	Print(string.format("saved a snapshot of the ground spells (%d events): /reload writes it to the settings file.",
		table.getn(db.debugDump.trail)));
	Print("class " .. tostring(myClass) .. ", " .. table.getn(DEFS) .. " telegraphs"
		.. (table.getn(skipped) > 0 and (", left to Priest Telegraphs: " .. table.concat(skipped, ", ")) or ""));
	Print("anchor: " .. (anchor and (tostring(anchor.kind) .. " " .. tostring(anchor.anchorId)) or "none")
		.. string.format(", %.1f screen units per yard", scale)
		.. ", heights " .. ( ( H[9] ~= 0 or H[10] ~= 0 or H[11] ~= 0 ) and "on" or "off (drawn at yours)" )
		.. ", last problem: " .. tostring(lastError or "none"));
	Print("phase " .. tostring(AZS_GetPhase and AZS_GetPhase()) .. ", run " .. tostring(AZS_ZONE and AZS_ZONE.run)
		.. ", area " .. tostring(AZS_STATS and AZS_STATS.area) .. ", spells line: " .. spellKeys);
	-- the game's enemy list right now: what the ground spells land by (read afresh)
	local p = AZS_GetPlayerPosition and AZS_GetPlayerPosition();
	if ( p and AZS_GetWorldAnchors ) then
		local t = { xs = {}, ys = {}, zs = {}, ids = {} };
		ReadFoes(p, 30, t);
		local line = string.format("enemy list now: %d within 30 yd of you; ", t.n) .. fx.ReadText();
		Print(line);
		db.debugDump.list = line;
	end
	for i = 1, table.getn(DEFS) do
		local def = DEFS[i];
		local c = SpellOf(def);
		local t = tips.tipSize[def.id];
		local inf = info[def.id];
		Print(def.name .. ": " .. (Settings(def).enabled and "on" or "off")
			.. (inf and inf.size and string.format(", size %.1f yd (%s)", inf.size, tostring(inf.source)) or "")
			.. (t and t.slot and (", tooltip in action slot " .. t.slot) or "")
			.. (c and string.format(", cooldown %.2f of %.2f sec, last cast %.1f sec ago", c.left or -1, c.max or -1,
				c.castAt and (now - c.castAt) or -1) or "")
			.. (c and c.up > c.down + 3 and string.format(" (its line read as time gone: %d up, %d down)", c.up, c.down) or ""));
	end
end

-- What the combat text feed gave last, and what the effects know.
local function PrintEvents()
	Print("last hit: " .. Dump(feed.lastEvent));
	Print("its source: " .. Dump(SourceOf(feed.lastEvent)));
	Print("its projection: " .. Dump(feed.lastProjection));
	local keys = {};
	for k in pairs(owned.keys) do
		table.insert(keys, k);
	end
	Print("detected (gear, talents, auras): " .. table.concat(keys, ", "));
	keys = {};
	for k in pairs(fx.learned) do
		table.insert(keys, k);
	end
	Print("seen going off: " .. table.concat(keys, ", ") .. "; feed " .. feed.ctStatus);
end

-- Your talents as the meter lists them.
local function PrintMeter()
	Print("meter: " .. meter.status .. (db.meterOff and "; asking it is off (/ast meter on)" or "")
		.. (table.getn(meter.list) > 0 and (": " .. table.concat(meter.list, ", ")) or ""));
end

SLASH_ASTELEGRAPHS1 = "/ast";
SLASH_ASTELEGRAPHS2 = "/astelegraphs";
SlashCmdList["ASTELEGRAPHS"] = function(msg)
	local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$");
	cmd = string.lower(cmd or "");
	if ( not myClass ) then
		SetupClass();
	end
	-- If a cone points the wrong way in game: mirror flips it, rotate turns it by degrees.
	if ( cmd == "mirror" ) then
		db.mirror = not db.mirror;
		Print(db.mirror and "cone facing mirrored." or "cone facing normal.");
	elseif ( cmd == "rotate" ) then
		db.rotate = tonumber(rest) or 0;
		Print(string.format(AST_L("cone facing turned by %g degrees."), db.rotate));
	elseif ( cmd == "spotlog" ) then
		-- /ast spotlog: start or stop recording what spots on the ground go by; /reload saves it
		if ( type(db.spotLog) == "table" ) then
			db.spotLogLast, db.spotLog = db.spotLog, nil;
			Print(string.format(AST_L("spot log stopped: %d entries kept. /reload to save them to the settings file."), table.getn(db.spotLogLast)));
		else
			db.spotLog = {};
			Print("recording the ground spells' casts, landings and hits. /ast spotlog again to stop.");
		end
	elseif ( cmd == "meter" ) then
		-- /ast meter: your talents as the meter lists them; /ast meter off|on: stop or start asking it
		if ( rest == "off" or rest == "on" ) then
			db.meterOff = (rest == "off") or nil;
		end
		PrintMeter();
	elseif ( cmd == "showcase" and AST.showcase ) then
		-- /ast showcase: all your telegraphs at once round you, turning, until it's run again
		AST.showcase.Toggle();
	elseif ( cmd == "ring" and not byId.ring ) then
		Print(table.getn(skipped) > 0 and "the custom ring is left to Priest Telegraphs: /ring there."
			or "no custom ring yet: your class isn't known yet, try again in a moment.");
	elseif ( cmd == "ring" ) then
		-- the custom ring: /ast ring 10 sets it to 10 yd, /ast ring alone turns it on or off
		local st = Settings(byId.ring);
		local v = tonumber(rest);
		if ( v and v > 0 ) then
			st.radius = v;
			st.enabled = true;
		else
			st.enabled = not st.enabled;
		end
		Print(string.format(AST_L(st.enabled and "ring on, %g yd." or "ring off, %g yd."), st.radius));
	elseif ( cmd == "lab" and AST.lab ) then
		AST.lab.Command(rest);
	elseif ( cmd == "minimap" ) then
		ShowMinimapButton(db.minimapHidden);
		Print(db.minimapHidden and "minimap button hidden (/ast minimap brings it back)." or "minimap button shown.");
	elseif ( cmd == "events" ) then
		PrintEvents();
	elseif ( cmd == "share" or cmd == "import" or cmd == "export" ) then
		-- /ast share: telegraph setups out and in, as a line of text
		AST.OpenShare();
	elseif ( cmd == "debug" ) then
		PrintDebug();
		PrintMeter();
	else
		AST.ToggleOptions();
	end
	AST.RefreshOptions();
end

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:RegisterEvent("VARIABLES_LOADED");
loader:RegisterEvent("UNIT_INVENTORY_CHANGED");
loader:SetScript("OnEvent", function()
	if ( event == "UNIT_INVENTORY_CHANGED" ) then
		-- an amulet swapped: read the gear again on the next frame
		owned.at = -100;
		return;
	end
	if ( db or ( event == "ADDON_LOADED" and arg1 ~= "AzerothSurvivorsTelegraphs" ) ) then
		return;
	end
	if ( type(ASTelegraphsDB) ~= "table" ) then
		ASTelegraphsDB = {};
	end
	db = ASTelegraphsDB;
	db.t = db.t or {};
	-- your own rings (Rings.lua) into their pages, before the telegraphs are set up
	if ( AST.LoadRings ) then
		AST.LoadRings();
	end
	-- The telegraphs are set up on the first frame (or the first /ast), once your class is known
	-- and every addon has loaded: Priest Telegraphs loads after this one.
	Start();
	MakeMinimapButton();
	Print("loaded. /ast or the minimap button for the options.");
end);
