-- Azeroth Survivors Telegraphs: Lab experiments (LabSignature). See Lab.lua.
-- Six of them, each changing the telegraphs it fits while it's on: ripples on a ground spell's
-- ticks, a turning rune circle in its spots, bursts with flung sparks where enemy effects go off,
-- a polished cone, each spell's school on its ring, and one halo at your feet for the cooldowns.
-- They draw with Core's pieces (AST.draw). With True circles on, a stroke is round pieces close
-- together, as many as its length over about half its width: so soft bands here are wide strokes,
-- small things are dots, and a whole disc (begun with AddArc) is a single piece.

local LAB = AST.lab;
-- what the tests reach: the drawing steps (called through it) and what they last drew
local SIG = { last = {} };
LAB.signature = SIG;

local PI = 3.14159265;
local TAU = 2 * PI;
local WHITE = { 1, 1, 1, 1 };
local INK = { 0.03, 0.03, 0.05, 1 };
local WARM = { 1, 0.93, 0.62, 1 };
local EMBER = { 0.95, 0.25, 0.05, 1 };
local GREEN = { 0.35, 0.9, 0.3, 1 };
-- colours worked out as they are drawn: reused, so a frame makes no new tables
local CA, CB, CC, CD, CE = { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, { 1, 1, 1, 1 };

-- `c` mixed toward `to` by k, into t; its alpha `a` (or c's)
local function Mix(t, c, to, k, a)
	t[1] = c[1] + (to[1] - c[1]) * k;
	t[2] = c[2] + (to[2] - c[2]) * k;
	t[3] = c[3] + (to[3] - c[3]) * k;
	t[4] = a or c[4] or 1;
	return t;
end

local function Frac(x)
	return x - math.floor(x);
end

-- A number from 0 to 1 that looks random but is always the same for the same n.
local function Hash(n)
	return Frac(math.sin(n * 12.9898 + 78.233) * 43758.5453);
end

local function Clamp(x, lo, hi)
	if ( x < lo ) then
		return lo;
	elseif ( x > hi ) then
		return hi;
	end
	return x;
end

---------------------------------------------------------------------------------------------
-- Pieces

-- A ring `r` yd round (cu, cv), stroked `w` units wide.
local function Ring(cu, cv, r, c, alpha, w)
	local D = AST.draw;
	if ( r <= 0 or alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	if ( D.AddArc(cu, cv, r, 0, TAU) ) then
		D.Stroke(true, c, alpha, w);
	end
end

-- An arc of it, a0 to a1.
local function Arc(cu, cv, r, a0, a1, c, alpha, w)
	local D = AST.draw;
	if ( r <= 0 or alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	if ( D.AddArc(cu, cv, r, a0, a1) ) then
		D.Stroke(false, c, alpha, w);
	end
end

-- A straight stroke on the ground.
local function Line(u0, v0, u1, v1, c, alpha, w)
	local D = AST.draw;
	if ( alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	if ( D.Add(u0, v0) and D.Add(u1, v1) ) then
		D.Stroke(false, c, alpha, w);
	end
end

-- Filled: a disc (r0 0: with True circles one piece), or a band from r0 out to r1; a sector of
-- either from a0 to a1.
local function Fill(cu, cv, r0, r1, c, alpha, strip, a0, a1)
	local D = AST.draw;
	if ( r1 <= r0 or alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	local ok;
	if ( not a0 ) then
		ok = D.AddArc(cu, cv, r1, 0, TAU) and ( r0 <= 0 or D.AddArc(cu, cv, r0, TAU, 0) );
	elseif ( r0 > 0 ) then
		ok = D.AddArc(cu, cv, r1, a0, a1) and D.AddArc(cu, cv, r0, a1, a0);
	else
		ok = D.Add(cu, cv) and D.AddArc(cu, cv, r1, a0, a1);
	end
	if ( ok ) then
		D.FillPoly(c, alpha, strip or 3);
	end
end

-- Screen units per yard on the ground at (cu, cv) (a spot far off is smaller).
local function LocalScale(cu, cv)
	local D = AST.draw;
	local x0, y0 = D.Map(cu, cv);
	local x1, y1 = D.Map(cu + 1, cv);
	local x2, y2 = D.Map(cu, cv + 1);
	if ( not ( x0 and x1 and x2 ) ) then
		return D.Scale();
	end
	return (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
		+ math.sqrt((x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0))) / 2;
end

-- A faint band from r0 out to r1 (an arc of it, a0 to a1), behind a wave or under a line: up to
-- 10 units across one stroke, wider filled strips (`strip` tall, 4 to start with: it is faint). A
-- wide see-through stroke would show its round pieces where they overlap.
local function Soft(cu, cv, r0, r1, c, alpha, a0, a1, strip)
	if ( r1 <= r0 or alpha <= 0.003 ) then
		return;
	end
	local k = LocalScale(cu, cv);
	local w = (r1 - r0) * k;
	if ( w > 10 ) then
		Fill(cu, cv, r0, r1, c, alpha, strip or 4, a0, a1);
		return;
	end
	local rm = (r0 + r1) / 2;
	w = math.max(1.5, w);
	if ( a0 ) then
		Arc(cu, cv, rm, a0, a1, c, alpha, w);
	else
		Ring(cu, cv, rm, c, alpha, w);
	end
end

-- A dot on the ground (yd from the hero, at the height H.dz).
local function DotAt(u, v, c, alpha, size)
	local D = AST.draw;
	if ( alpha <= 0.003 ) then
		return;
	end
	local x, y = D.Map(u, v);
	if ( x ) then
		D.Dot(x, y, c, alpha, size);
	end
end

-- How much of an element at `f` (0 to 1 along an arc `span` wide) shows: on a ring all of it,
-- along a cone's arc it fades out near the cone's sides.
local function EdgeFade(f, span, ring)
	if ( ring ) then
		return 1;
	end
	return Clamp(math.min(f * span, (1 - f) * span) / 0.14, 0, 1);
end

-- A Lab entry's settings with the colours of a demo (into t): its look (style, width...) the entry's.
local function DemoSt(t, src, line, fill, smooth)
	t.line, t.fill = line, fill;
	t.width, t.glow, t.strip = src.width or 3, src.glow ~= false, src.strip or 3;
	t.style = ( smooth and "smooth" ) or src.style or "smooth";
	t.size, t.spacing, t.fillSpacing, t.fillStyle = src.size or 5, src.spacing or 9, src.fillSpacing or 12, src.fillStyle or "solid";
	t.flash, t.most, t.mode = 0.6, 0, "cooldown";
	t.cdFill, t.durFill, t.uptime = true, true, true;
	return t;
end

-- The demos (a Test press of an experiment): their colours (gold, violet, frost, fire, nature,
-- arcane; an ember's), the schools they show, and their settings, stand-in jobs and defs (reused).
local DEMO = {
	lines = { { 1, 0.88, 0.45, 1 }, { 0.75, 0.45, 1, 1 }, { 0.55, 0.85, 1, 1 }, { 1, 0.55, 0.2, 1 },
		{ 0.55, 0.95, 0.5, 1 }, { 0.88, 0.6, 1, 1 }, { 1, 0.5, 0.2, 1 } },
	fills = { { 1, 0.82, 0.35, 0.25 }, { 0.55, 0.25, 0.95, 0.3 }, { 0.45, 0.75, 1, 0.28 }, { 1, 0.4, 0.1, 0.28 },
		{ 0.4, 0.85, 0.4, 0.25 }, { 0.75, 0.45, 1, 0.28 }, { 1, 0.38, 0.1, 0.25 } },
	schools = { "holy", "shadow", "frost", "fire", "nature", "arcane" },
	st = { {}, {}, {}, {}, {}, {}, {} }, jobs = { {}, {}, {} },
	ground = { id = "lab_demo_ground", every = 1, firstTick = 0.25 },
	cone = { id = "lab_demo_cone", halfAngle = 50 },
	circles = { { id = "lab_demo_a", shape = "circle" }, { id = "lab_demo_b", shape = "circle" }, { id = "lab_demo_c", shape = "circle" } },
	cds = { 1.3, 2.1, 2.8 }, offs = { 0.9, 0.4, 2.2 },
};

---------------------------------------------------------------------------------------------
-- Ground spells: each spot shown this frame

-- f(j, cu, cv, R, alpha, age, dur, now) for each spot of ground job `j` Core shows (at its own
-- height; one that moves with you: the newest, on you), or the one a Test press shows.
local function EachSpot(j, p, now, f)
	local D = AST.draw;
	local def = j.def;
	if ( j.test ) then
		f(j, 6, 3, j.size, j.alpha, j.test, 3, now);
		return;
	end
	local follows = def.follows and D.owned.keys[def.follows];
	local spots = D.Spots();
	local newest;
	for k = 1, table.getn(spots) do
		local s = spots[k];
		local age = now - s.at;
		if ( s.id == def.id and ( s.cands or s.shown ) and not s.over and age >= 0 and age <= s.dur + 0.4 ) then
			if ( follows ) then
				if ( not newest or s.at > newest.at ) then
					newest = s;
				end
			else
				local fade = 1;
				if ( age > s.dur ) then
					fade = 1 - (age - s.dur) / 0.4;
				end
				D.H.dz = s.z and s.z - p.z or 0;
				f(j, s.x - p.x, s.y - p.y, s.r or j.size, j.alpha * fade, age, s.dur, now);
				D.H.dz = 0;
			end
		end
	end
	if ( newest ) then
		local age = now - newest.at;
		local fade = 1;
		if ( age > newest.dur ) then
			fade = 1 - (age - newest.dur) / 0.4;
		end
		f(j, 0, 0, newest.r or j.size, j.alpha * fade, age, newest.dur, now);
	end
end

---------------------------------------------------------------------------------------------
-- 1. Tick ripples

-- One ripple, `s` (0 to 1) of the way out: a bright thin front on a glow, a faint wash inside it,
-- easing out as it goes, fading in at once and out slowly. (A see-through stroke's round pieces
-- show where they overlap unless a solid line runs down its middle: so glows go under lines.)
function SIG.Ripple(cu, cv, R, s, st, alpha, tick)
	local D = AST.draw;
	SIG.last.ripple, SIG.last.rippleTick = s, tick;
	local r = R * (0.06 + 0.94 * LAB.EaseOut(s, 3));
	local fade = math.pow(1 - s, 1.4);
	if ( s < 0.08 ) then
		fade = fade * s / 0.08;
	end
	alpha = alpha * fade;
	if ( alpha <= 0.06 ) then
		-- (all but gone: not worth its pieces)
		return;
	end
	local front = Mix(CA, st.line, WHITE, 0.55);
	if ( st.style == "dots" ) then
		D.DotArc(cu, cv, r, 0, TAU, front, alpha, st.size * 0.8, st.spacing * 1.1);
		return;
	end
	Fill(cu, cv, 0, r, st.fill, alpha * 0.45, 4);
	if ( st.glow and s < 0.45 ) then
		-- its glow while it is young and bright (and small: few pieces)
		Ring(cu, cv, r, st.line, alpha * 0.3 * (1 - s / 0.45), math.max(6, st.width * 3));
	end
	Ring(cu, cv, r, front, alpha * 0.95, math.max(2.5, st.width));
end

-- A spot's ripple: one runs out on each of its ticks (the first `firstTick` after it lands, then
-- every `every` sec while it lasts).
local function TickAt(j, cu, cv, R, alpha, age, dur, now)
	local def = j.def;
	local first, every = def.firstTick or AST.draw.FIRST_TICK, def.every or 1;
	if ( every <= 0 or age < first ) then
		return;
	end
	local k = math.floor((age - first) / every);
	local at = first + k * every;
	local life = math.min(0.8, every * 0.75);
	if ( at <= dur and age - at < life ) then
		SIG.Ripple(cu, cv, R, (age - at) / life, j.st, alpha, k);
	end
end

---------------------------------------------------------------------------------------------
-- 2. Rune circle

-- Inside a spot: a ring of fine beads at 86% of its size with a mark every 15 degrees (every 90 a
-- longer one ending in a small diamond), and four short arcs of bigger beads further in; the ring
-- turns once every 20 sec, the arcs the other way. It opens out as the spot lands and goes as the
-- spot does.
local function RuneAt(j, cu, cv, R, alpha, age, dur, now)
	local D = AST.draw;
	local st = j.st;
	local w = st.width;
	local open = LAB.EaseOut(age / 0.6, 3);
	alpha = alpha * open;
	if ( alpha <= 0.01 ) then
		return;
	end
	local rot = now * TAU / 20;
	SIG.last.runeRot = rot;
	local ri = R * (0.86 - 0.12 * (1 - open));
	local lc = Mix(CA, st.line, WHITE, 0.3);
	local dots = st.style == "dots";
	D.DotArc(cu, cv, ri, 0, TAU, lc, alpha * 0.85, dots and st.size * 0.55 or math.max(2.4, w * 0.8),
		dots and st.spacing or math.max(7.5, w * 2.5));
	for i = 0, 23 do
		local a = rot + i * TAU / 24;
		local ca, sa = math.cos(a), math.sin(a);
		if ( i - math.floor(i / 6) * 6 == 0 ) then
			-- a long mark: two beads inward, then a small diamond
			for b = 1, 2 do
				local rb = ri - R * 0.035 * b;
				DotAt(cu + rb * ca, cv + rb * sa, lc, alpha * (0.6 + 0.15 * b),
					dots and st.size * (0.5 + 0.2 * b) or math.max(2.5, w * (0.6 + 0.3 * b)));
			end
			local rd, hl, hw = ri - R * 0.115, R * 0.035, 0.035;
			D.Begin();
			if ( D.Add(cu + (rd - hl) * ca, cv + (rd - hl) * sa) and D.Add(cu + rd * math.cos(a + hw), cv + rd * math.sin(a + hw))
				and D.Add(cu + (rd + hl) * ca, cv + (rd + hl) * sa) and D.Add(cu + rd * math.cos(a - hw), cv + rd * math.sin(a - hw)) ) then
				D.FillPoly(lc, alpha, 2);
			end
		else
			DotAt(cu + (ri - 0.035 * R) * ca, cv + (ri - 0.035 * R) * sa, lc, alpha * 0.75,
				dots and st.size * 0.6 or math.max(2.5, w * 0.85));
		end
	end
	local ra = R * 0.72;
	for i = 0, 3 do
		local a = -rot * 0.66 + PI / 4 + i * PI / 2;
		D.DotArc(cu, cv, ra, a - 0.26, a + 0.26, lc, alpha, dots and st.size * 0.8 or math.max(2.8, w * 0.95),
			dots and st.spacing * 0.7 or math.max(4.5, w * 1.5));
	end
end

---------------------------------------------------------------------------------------------
-- 3. Burst

-- A ring's sparks look random but are its own: the same ones every frame it shows.
local function Seed(r)
	local a = r.at - math.floor(r.at / 61) * 61;
	return a * 7.13 + (r.x or 0) * 0.37 + (r.y or 0) * 0.53;
end

-- One burst `age` sec in, shown for T: a ring flies out (ease-out) with a bright edge on a glow,
-- its inside flashing white-hot and fading, and nine sparks flung out, up and down again, fading.
-- `rich`: the flash and glow too (the newest few, in a busy fight).
function SIG.Burst(cu, cv, R, age, T, st, alpha, seed, rich)
	local D = AST.draw;
	local w = st.width;
	local grow = math.min(0.35, T * 0.7);
	local r = R * (0.12 + 0.88 * LAB.EaseOut(age / grow, 4));
	local ringA = 1;
	if ( age > grow ) then
		ringA = math.max(0, 1 - (age - grow) / (T - grow));
	end
	local edge = Mix(CA, st.line, WHITE, 0.55);
	if ( st.style == "dots" ) then
		D.DotArc(cu, cv, r, 0, TAU, edge, alpha * ringA, st.size, st.spacing);
		if ( age < T * 0.5 ) then
			D.DotArc(cu, cv, r * 0.55, 0, TAU, edge, alpha * 0.7 * (1 - age / (T * 0.5)), st.size * 0.8, st.spacing);
		end
	elseif ( ringA > 0 ) then
		-- the wash: white-hot at first, then the effect's fill, fading
		local fl = math.max(0, 1 - age / (T * 0.5));
		if ( rich ) then
			Fill(cu, cv, 0, r, Mix(CB, st.fill, WHITE, 0.6 * fl), alpha * (0.9 + 1.2 * fl * fl) * ringA, st.strip);
			if ( st.glow ) then
				Ring(cu, cv, r, st.line, alpha * 0.3 * ringA, w * 3.2);
			end
		end
		Ring(cu, cv, r, edge, alpha * ringA, w * 1.1);
	end
	-- the sparks: one bright piece each, on a low arc through the air, shrinking as it fades
	local s = age / T;
	if ( s >= 1 ) then
		return;
	end
	local al = alpha * math.pow(1 - s, 1.2);
	local base = D.H.dz;
	local head = Mix(CC, st.line, WHITE, 0.85 - 0.4 * s);
	local size = (( st.style == "dots" ) and st.size or math.max(5.5, w * 1.8)) * (1 - 0.45 * s);
	local d0 = LAB.EaseOut(s, 2);
	for k = 0, 8 do
		local ang = (k + Hash(seed * 17 + k) * 0.8) / 9 * TAU;
		local d = R * (0.75 + 0.55 * Hash(seed * 31 + k * 7)) * d0;
		D.H.dz = base + R * (0.1 + 0.22 * Hash(seed * 13 + k * 3)) * 4 * s * (1 - s);
		DotAt(cu + d * math.cos(ang), cv + d * math.sin(ang), head, al, size);
	end
	D.H.dz = base;
end

-- The rings of enemy job `j` as bursts, instead of Core's: the newest first, at most st.most (when
-- set), each for st.flash sec; those over 2 sec old leave the list, as Core's drawing would see to.
local function DrawBursts(j, p, now)
	local D = AST.draw;
	local st = j.st;
	local T = math.max(0.25, st.flash or 0.5);
	if ( j.test ) then
		for k = 0, 2 do
			local age = j.test - k * 0.8;
			if ( age >= 0 and age < T ) then
				local a = k * 2.1;
				SIG.Burst(8 * math.cos(a), 8 * math.sin(a), j.size, age, T, st, j.alpha, k + 1, true);
			end
		end
	end
	local rings = D.Rings();
	local drawn = 0;
	for k = table.getn(rings), 1, -1 do
		local r = rings[k];
		local age = now - r.at;
		if ( age > 2 ) then
			table.remove(rings, k);
		elseif ( r.kind == j.def.id and age >= 0 and age < T and ( st.most <= 0 or drawn < st.most ) ) then
			drawn = drawn + 1;
			D.H.dz = r.z and r.z - p.z or 0;
			SIG.Burst(r.x - p.x, r.y - p.y, j.size, age, T, st, 1, Seed(r), drawn <= 6);
			D.H.dz = 0;
		end
	end
	SIG.last.bursts = drawn;
	return true;
end

---------------------------------------------------------------------------------------------
-- 4. Cone polish

-- The cone's shading, from r0 out to r1, as bands brightest toward `Lg` (the far arc, or the
-- fill's front): SHADE's edges (of Lg) and alphas; nothing in the first quarter.
local SHADE = { 0.25, 0.12, 0.5, 0.3, 0.72, 0.6, 0.88, 0.95, 1, 1.25 };
local function Shade(Lg, r0, r1, a0, a1, c, alpha, strip)
	for i = 1, table.getn(SHADE) - 2, 2 do
		local ra, rb = math.max(r0, Lg * SHADE[i]), math.min(r1, Lg * SHADE[i + 2]);
		if ( rb > ra + 0.01 ) then
			Fill(0, 0, ra, rb, c, alpha * SHADE[i + 1], strip, a0, a1);
		end
	end
end

-- A cone: shaded brightest toward its far arc and faded toward you, its sides fine lines that stop
-- short of you, its arc a bright line on a glow; what has filled of its cooldown brightest at its front, which is a bright
-- arc; a cast sends a wave out along it (0.5 sec, easing out).
function SIG.Cone(j)
	local st, alpha, L = j.st, j.alpha, j.size;
	local h = (j.def.halfAngle or 45) * PI / 180;
	local a0, a1 = j.facing - h, j.facing + h;
	local pg, since = j.progress, j.since;
	local w = st.width;
	local pulse = 0;
	if ( since and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	if ( pg ) then
		if ( pg < 1 ) then
			Shade(L, L * pg, L, a0, a1, st.fill, alpha * 0.45, st.strip);
		end
		if ( pg > 0 ) then
			Shade(L * pg, 0, L * pg, a0, a1, st.fill, alpha * (1 + pulse), st.strip);
		end
	else
		Shade(L, 0, L, a0, a1, st.fill, alpha * (1 + pulse), st.strip);
	end
	-- the sides: fine lines from a third of the way out to the arc (the shading fades into them)
	for k = 0, 1 do
		local a = ( k == 0 ) and a0 or a1;
		local ca, sa = math.cos(a), math.sin(a);
		Line(L * 0.35 * ca, L * 0.35 * sa, L * ca, L * sa, st.line, alpha * 0.55, math.max(1.5, w * 0.55));
	end
	local ww = w * (1 + pulse * 0.6);
	if ( st.glow ) then
		Arc(0, 0, L, a0, a1, st.line, alpha * 0.22 * (1 + pulse), ww * 3);
	end
	Arc(0, 0, L, a0, a1, Mix(CB, st.line, WHITE, 0.3), alpha, ww * 0.9);
	SIG.last.coneFront, SIG.last.coneSweep = nil, nil;
	if ( pg and pg > 0 and pg < 1 ) then
		Arc(0, 0, L * pg, a0 + 0.05, a1 - 0.05, Mix(CC, st.fill, WHITE, 0.6, 1), alpha * 0.85, math.max(2, w * 0.7));
		SIG.last.coneFront = L * pg;
	end
	if ( since and since < 0.5 ) then
		local s = since / 0.5;
		local r = L * (0.1 + 0.9 * LAB.EaseOut(s, 3));
		local fade = math.pow(1 - s, 1.5);
		Arc(0, 0, r, a0 + 0.06, a1 - 0.06, st.line, alpha * 0.35 * fade, w * 3.2);
		Arc(0, 0, r, a0 + 0.06, a1 - 0.06, Mix(CE, st.line, WHITE, 0.6, 1), alpha * fade, w * 1.1);
		SIG.last.coneSweep = r;
	end
	return true;
end

---------------------------------------------------------------------------------------------
-- 5. School themes

-- Each telegraph's school (false: left as it is: reaches and ranges). One not listed goes by its
-- class.
local SCHOOL = {
	-- Any class
	war_stomp = "physical", escape_artist = "arcane", ring = false,
	-- warrior
	whirlwind = "physical", thunder_clap = "physical", demo_shout = "physical", cleave = "physical",
	rage_eruption = "fire", rampage = "physical", bladestorm = "physical", warrior_range = false, warrior_melee = false,
	-- paladin
	holy_wrath = "holy", lights_grace = "holy", daybreak = "holy", paladin_range = false, paladin_melee = false,
	-- hunter
	hunter_range = false,
	-- rogue
	blade_flurry = "physical", preparation = "shadow", rogue_range = false, rogue_melee = false,
	-- priest
	mind_flay = "shadow", holy_nova = "holy", chastise = "holy", radiance = "holy", psychic_scream = "shadow",
	shield = "holy", range = false,
	-- shaman
	fire_nova = "fire", flametongue = "fire", shaman_range = false,
	-- mage
	frost_nova = "frost", arcane_explosion = "arcane", blast_wave = "fire", cone_of_cold = "frost",
	arcane_concentration = "arcane", water_nova = "frost", ice_barrier_burst = "frost", mage_range = false,
	-- warlock
	hellfire = "fire", warlock_range = false,
	-- druid
	swipe = "nature", tranquility = "nature", dire_bear = "nature", enrage = "nature", druid_range = false,
};
local CLASS_SCHOOL = { warrior = "physical", paladin = "holy", hunter = "nature", rogue = "physical", priest = "holy",
	shaman = "nature", mage = "arcane", warlock = "shadow", druid = "nature", common = "physical" };
SIG.SCHOOL, SIG.CLASS_SCHOOL = SCHOOL, CLASS_SCHOOL;
-- the skills' own rings (Skills.lua) say theirs (a reach or a trigger: false)
for _, r in pairs(AST.registry or {}) do
	for i = 1, table.getn(r.defs) do
		local d = r.defs[i];
		if ( d.school ~= nil and SCHOOL[d.id] == nil ) then
			SCHOOL[d.id] = d.school;
		end
	end
end

function SIG.SchoolOf(def)
	local s = SCHOOL[def.id];
	if ( s ~= nil ) then
		return s or nil;
	end
	if ( def.custom or string.find(def.id, "range$") or string.find(def.id, "melee$") ) then
		return nil;
	end
	return CLASS_SCHOOL[def.group];
end

-- A wavering edge round (cu, cv): points along it from a0 over `span`, smoke layer `L` (0 the line).
local function Smoke(cu, cv, R, a0, span, L, t)
	local D = AST.draw;
	local n = math.max(12, math.floor(64 * span / TAU));
	D.Begin();
	for i = 0, n do
		local a = a0 + span * i / n;
		local z = 0.045 * math.sin(4 * a + t * 0.55 + L * 1.7) + 0.03 * math.sin(7 * a - t * 0.85 + L * 0.9)
			+ 0.016 * math.sin(13 * a + t * 1.5 + L * 2.3);
		local r = R * (1 + z * (0.5 + L * 0.35) + L * 0.022);
		if ( not D.Add(cu + r * math.cos(a), cv + r * math.sin(a)) ) then
			return false;
		end
	end
	return true;
end

-- A gently swaying edge.
local function Wave(cu, cv, R, a0, span, t)
	local D = AST.draw;
	local n = math.max(12, math.floor(64 * span / TAU));
	D.Begin();
	for i = 0, n do
		local a = a0 + span * i / n;
		local r = R * (1 + 0.016 * math.sin(9 * a + t * 0.8) + 0.007 * math.sin(17 * a - t * 1.3));
		if ( not D.Add(cu + r * math.cos(a), cv + r * math.sin(a)) ) then
			return false;
		end
	end
	return true;
end

-- A leaf at (u, v) pointing `dir`, L yd long and W wide.
local LEAF = { -0.5, 0, -0.22, 0.85, 0.18, 0.75, 0.5, 0, 0.18, -0.75, -0.22, -0.85 };
local function Leaf(u, v, dir, L, W, c, alpha)
	local D = AST.draw;
	if ( alpha <= 0.003 ) then
		return;
	end
	local dx, dy = math.cos(dir), math.sin(dir);
	D.Begin();
	for i = 1, 11, 2 do
		local t, s = LEAF[i] * L, LEAF[i + 1] * W;
		if ( not D.Add(u + dx * t - dy * s, v + dy * t + dx * s) ) then
			return;
		end
	end
	D.FillPoly(c, alpha, 2);
end

-- A sparkle: a bright bead, a soft halo, and a thin cross of light, at screen point (x, y).
local function Glint(x, y, c, alpha, size)
	local D = AST.draw;
	if ( not x or alpha <= 0.01 ) then
		return;
	end
	D.Dot(x, y, c, alpha * 0.3, size * 2.6);
	D.Dot(x, y, WHITE, alpha * 0.95, size);
	local l = size * 3.2;
	D.Quad(D.SOLID, x - l / 2, y - 0.6, l, 1.2, WHITE, alpha * 0.8);
	D.Quad(D.SOLID, x - 0.6, y - l / 2, 1.2, l, WHITE, alpha * 0.8);
end

-- The schools' edges. Each: (cu, cv, R, st, alpha, now, a0, span, ring, pulse); ring: a whole ring,
-- its edge drawn here (in place of Core's outline); else the far arc of a cone (from a0, span
-- wide), where only what goes on top of Core's outline is drawn.
local EDGE = {};
SIG.EDGE = EDGE;

-- Holy: faint shafts of light from halfway out to the rim, widening, turning slowly, a warm rim, and a
-- crown of twinkling beads just outside it turning the other way.
EDGE.holy = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local w = st.width;
	local lc = Mix(CA, st.line, WHITE, 0.5);
	local n = ring and 6 or math.max(2, math.floor(6 * span / TAU + 0.5));
	local phase = now * 0.12 * n / TAU;
	local D = AST.draw;
	for i = 0, n - 1 do
		local f = Frac((i + phase) / n);
		local a = a0 + span * f;
		D.Begin();
		if ( D.Add(cu + 0.42 * R * math.cos(a - 0.01), cv + 0.42 * R * math.sin(a - 0.01))
			and D.Add(cu + 0.95 * R * math.cos(a - 0.04), cv + 0.95 * R * math.sin(a - 0.04))
			and D.Add(cu + 0.95 * R * math.cos(a + 0.04), cv + 0.95 * R * math.sin(a + 0.04))
			and D.Add(cu + 0.42 * R * math.cos(a + 0.01), cv + 0.42 * R * math.sin(a + 0.01)) ) then
			D.FillPoly(lc, alpha * 0.11 * EdgeFade(f, span, ring), 2);
		end
	end
	if ( ring ) then
		if ( st.glow ) then
			Ring(cu, cv, R, st.line, alpha * 0.24 * (1 + pulse), w * 3);
		end
		Ring(cu, cv, R, lc, alpha, w * (1 + pulse * 0.6));
	end
	local m = ring and 36 or math.max(4, math.floor(36 * span / TAU + 0.5));
	local ph2 = -now * 0.07 * m / TAU;
	local bead = Mix(CB, st.line, WHITE, 0.7);
	for i = 0, m - 1 do
		local f = Frac((i + ph2) / m);
		local a = a0 + span * f;
		local odd = i - math.floor(i / 2) * 2 == 1;
		local tw = 0.55 + 0.45 * math.sin(now * 2.3 + i * 1.7);
		DotAt(cu + R * (odd and 1.045 or 1.075) * math.cos(a), cv + R * (odd and 1.045 or 1.075) * math.sin(a), bead,
			alpha * tw * (odd and 0.5 or 0.8) * EdgeFade(f, span, ring), math.max(2, w * (odd and 0.6 or 0.85)));
	end
end

-- Shadow: a dark band inside a wavering, smoky edge that drifts, and wisps curling off it.
EDGE.shadow = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local D = AST.draw;
	local w = st.width;
	local dark = Mix(CB, st.line, INK, 0.78, 1);
	if ( ring ) then
		Ring(cu, cv, R * 0.93, dark, alpha * 0.35, w * 3.4);
		if ( st.glow and Smoke(cu, cv, R, 0, TAU, 1, now) ) then
			D.Stroke(true, Mix(CC, st.line, dark, 0.35), alpha * 0.22, w * 3.4);
		end
		if ( Smoke(cu, cv, R, 0, TAU, 0, now) ) then
			D.Stroke(true, Mix(CD, st.line, WHITE, 0.15), alpha * 0.9, w * 0.9 * (1 + pulse * 0.6));
		end
	end
	local n = ring and 7 or math.max(2, math.floor(7 * span / TAU + 0.5));
	local wisp = Mix(CE, st.line, WHITE, 0.1);
	for i = 0, n - 1 do
		local ph = Frac(now * 0.22 + i * 0.618);
		local f = Frac((i + now * 0.04 * n / TAU) / n);
		local a = a0 + span * f + 0.25 * ph;
		local half = 0.15 * (1 - 0.4 * ph);
		Arc(cu, cv, R * (1.02 + 0.15 * ph), a - half, a + half, wisp,
			alpha * 0.5 * math.sin(PI * ph) * EdgeFade(f, span, ring), math.max(1.5, w * (1.1 - 0.5 * ph)));
	end
end

-- Frost: a crisp, faceted edge (twenty sides, alternately in and out), a fine rime inside it, and
-- ice spikes at every other corner where glints come and go.
EDGE.frost = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local D = AST.draw;
	local w = st.width;
	local ice = Mix(CA, st.line, WHITE, 0.5);
	local n = ring and 20 or math.max(4, 2 * math.floor(10 * span / TAU + 0.5));
	local off = ring and 0.08 or 0;
	if ( ring ) then
		D.DotArc(cu, cv, R * 0.9, 0, TAU, st.line, alpha * 0.45, math.max(1.8, w * 0.6), math.max(14, w * 4.5));
		D.Begin();
		local ok = true;
		for i = 0, n do
			local a = off + i * TAU / n;
			-- (corners out at 1.03 and in at 0.985: its sides run along the fill's edge)
			local r = ( i - math.floor(i / 2) * 2 == 1 ) and R * 0.985 or R * 1.03;
			ok = ok and D.Add(cu + r * math.cos(a), cv + r * math.sin(a));
		end
		if ( ok ) then
			if ( st.glow ) then
				D.Stroke(true, st.line, alpha * 0.25, w * 2.6);
			end
			D.Stroke(true, ice, alpha, w * (1 + pulse * 0.6));
		end
	end
	local tip = Mix(CB, st.line, WHITE, 0.6);
	for i = 0, n - 1, 2 do
		local f = ring and i / n or (i + 0.5) / n;
		local a = a0 + off + span * f;
		local ef = EdgeFade(f, span, ring);
		local rb = ring and R * 1.03 or R;
		local r1 = rb + R * (0.06 + 0.012 * math.sin(i * 1.3));
		D.Begin();
		if ( D.Add(cu + (rb - 0.03 * R) * math.cos(a), cv + (rb - 0.03 * R) * math.sin(a))
			and D.Add(cu + (rb + 0.01 * R) * math.cos(a - 0.025), cv + (rb + 0.01 * R) * math.sin(a - 0.025))
			and D.Add(cu + r1 * math.cos(a), cv + r1 * math.sin(a))
			and D.Add(cu + (rb + 0.01 * R) * math.cos(a + 0.025), cv + (rb + 0.01 * R) * math.sin(a + 0.025)) ) then
			D.FillPoly(tip, alpha * 0.9 * ef, 2);
		end
		local gl = math.pow(math.max(0, math.sin(now * 1.7 + i * 2.1)), 12);
		if ( gl > 0.02 ) then
			local x, y = D.Map(cu + r1 * math.cos(a), cv + r1 * math.sin(a));
			Glint(x, y, st.line, alpha * gl * ef, math.max(2.5, w * 0.9));
		end
	end
end

-- Fire: a flickering line on a heat glow, a crown of flames standing up on it (each flaring on its
-- own), and embers drifting up off it.
EDGE.fire = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local D = AST.draw;
	local w = st.width;
	local hot = Mix(CA, st.line, WARM, 0.65);
	local fl = 0.82 + 0.18 * math.sin(now * 23) * math.sin(now * 7.3);
	if ( ring ) then
		if ( st.glow ) then
			Ring(cu, cv, R, st.line, alpha * (0.18 + 0.1 * fl) * (1 + pulse), w * 3.2);
		end
		Ring(cu, cv, R, hot, alpha * fl, w * 0.9 * (1 + pulse * 0.6));
	end
	-- the flames: each three round pieces stood up on the edge (red-orange, hot, white-hot), its
	-- height flickering on its own, swaying a little
	local k = LocalScale(cu, cv);
	local bs = Clamp(0.045 * R * k, 5, 15);
	local base = D.H.dz;
	local x0, y0 = D.Map(cu, cv);
	D.H.dz = base + 1;
	local x1, y1 = D.Map(cu, cv);
	D.H.dz = base;
	local up = ( x0 and x1 and y1 - y0 > 1 ) and y1 - y0 or k * 0.8;
	local n = ring and 32 or math.max(4, math.floor(32 * span / TAU + 0.5));
	local outer = Mix(CB, st.line, EMBER, 0.2);
	local white = Mix(CC, hot, WHITE, 0.55);
	for i = 0, n - 1 do
		local f = (i + 0.5) / n;
		local a = a0 + span * f;
		local x, y = D.Map(cu + R * math.cos(a), cv + R * math.sin(a));
		if ( x ) then
			local al = alpha * EdgeFade(f, span, ring);
			local fk = 0.5 + 0.5 * math.sin(now * 7.3 + i * 2.7) * math.sin(now * 3.1 + i * 1.3 + 0.5);
			local h = up * R * (0.06 + 0.1 * fk);
			local bw = bs * (0.85 + 0.3 * fk);
			x = x + bw * 0.25 * math.sin(now * 4.1 + i * 0.9);
			D.Quad(D.ROUND, x - bw / 2, y - bw * 0.3, bw, h + bw * 0.3, outer, al * 0.5);
			D.Quad(D.ROUND, x - bw * 0.3, y - bw * 0.2, bw * 0.6, h * 0.62 + bw * 0.2, hot, al * 0.65);
			D.Quad(D.ROUND, x - bw * 0.14, y - bw * 0.1, bw * 0.28, h * 0.3 + bw * 0.1, white, al * 0.6);
		end
	end
	for i = 0, ( ring and 7 or 3 ) do
		local c = now * 0.45 + i * 0.37;
		local ph = Frac(c);
		local f = Hash(i * 7.7 + math.floor(c) * 3.3);
		local a = a0 + span * f;
		D.H.dz = base + ph * 2.2;
		DotAt(cu + R * (1 + 0.04 * ph) * math.cos(a), cv + R * (1 + 0.04 * ph) * math.sin(a), hot,
			alpha * 0.85 * math.sin(PI * ph) * EdgeFade(f, span, ring), math.max(2, w * 0.9) * (1 - 0.5 * ph));
	end
	D.H.dz = base;
end

-- Nature: a gently swaying edge, and leaves drifting round it, each bobbing and turning a little.
EDGE.nature = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local D = AST.draw;
	local w = st.width;
	if ( ring and Wave(cu, cv, R, 0, TAU, now) ) then
		if ( st.glow ) then
			D.Stroke(true, st.line, alpha * 0.22, w * 3);
		end
		D.Stroke(true, Mix(CA, st.line, WHITE, 0.3), alpha, w * (1 + pulse * 0.6));
	end
	local leaf = Mix(CB, st.line, GREEN, 0.3);
	local light = Mix(CC, leaf, WHITE, 0.45);
	local n = ring and 10 or math.max(2, math.floor(10 * span / TAU + 0.5));
	local Lf = Clamp(R * 0.11, 0.45, 1.3);
	for i = 0, n - 1 do
		local f = Frac((i + now * 0.05 * n / TAU) / n);
		local a = a0 + span * f;
		local ef = EdgeFade(f, span, ring);
		local rr = R * (1.01 + 0.035 * math.sin(now * 0.9 + i * 1.9));
		local dir = a + PI / 2 + 0.5 * math.sin(now * 1.2 + i * 2.3);
		local u, v = cu + rr * math.cos(a), cv + rr * math.sin(a);
		Leaf(u, v, dir, Lf, Lf * 0.34, leaf, alpha * 0.85 * ef);
		Leaf(u + 0.06 * Lf * math.cos(dir), v + 0.06 * Lf * math.sin(dir), dir, Lf * 0.62, Lf * 0.1, light, alpha * 0.6 * ef);
	end
end

-- Arcane: a bright edge on a faint inner orbit, sparks circling on both, each with a fading trail.
EDGE.arcane = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	local D = AST.draw;
	local w = st.width;
	local lc = Mix(CA, st.line, WHITE, 0.35);
	if ( ring ) then
		if ( st.glow ) then
			Ring(cu, cv, R, st.line, alpha * 0.22 * (1 + pulse), w * 3);
		end
		Ring(cu, cv, R, lc, alpha, w * (1 + pulse * 0.6));
		D.DotArc(cu, cv, R * 0.88, 0, TAU, st.line, alpha * 0.35, math.max(1.6, w * 0.5), math.max(9, w * 3));
	end
	local head = Mix(CB, st.line, WHITE, 0.8);
	local size = math.max(3.5, w * 1.3);
	-- the trail: a bead every 5 units behind the head
	local gap = 5 / math.max(1, R * LocalScale(cu, cv));
	for orbit = 0, 1 do
		local rr = ( orbit == 0 ) and R or R * 0.88;
		local nn = ( orbit == 0 ) and 4 or 3;
		local speed = ( orbit == 0 ) and 0.7 or -0.5;
		if ( not ring ) then
			nn = 2;
		end
		local step = gap * ( speed > 0 and 1 or -1 );
		for i = 0, nn - 1 do
			local f = Frac(now * speed / ( ring and TAU or span * 2 ) + i / nn);
			for b = 0, 5 do
				local fb = f - b * step / ( ring and TAU or span );
				if ( ring or ( fb >= 0 and fb <= 1 ) ) then
					local a = a0 + ( ring and TAU or span ) * fb;
					local ef = EdgeFade(Frac(fb), span, ring);
					if ( b == 0 ) then
						DotAt(cu + rr * math.cos(a), cv + rr * math.sin(a), st.line, alpha * 0.3 * ef, size * 3);
					end
					DotAt(cu + rr * math.cos(a), cv + rr * math.sin(a), b == 0 and head or st.line,
						alpha * ( b == 0 and 1 or 0.7 * (1 - b / 6) ) * ef, ( b == 0 ) and size or size * (0.8 - b * 0.1));
				end
			end
		end
	end
end

-- Physical: a plain edge, a little heavier, with a faint dotted second ring inside it.
EDGE.physical = function(cu, cv, R, st, alpha, now, a0, span, ring, pulse)
	if ( not ring ) then
		return;
	end
	local w = st.width;
	AST.draw.DotArc(cu, cv, R * 0.93, 0, TAU, st.line, alpha * 0.4, math.max(1.8, w * 0.6), math.max(12, w * 4));
	if ( st.glow ) then
		Ring(cu, cv, R, st.line, alpha * 0.22 * (1 + pulse), w * 3);
	end
	Ring(cu, cv, R, Mix(CA, st.line, WHITE, 0.2), alpha, w * 1.1 * (1 + pulse * 0.6));
end

-- A circle round (cu, cv) in its school: Core's fill (its cooldown filling from the middle, its
-- front a bright ring), the school's edge, and a cast's shockwave (easing out).
function SIG.SchoolCircle(cu, cv, R, st, alpha, pg, since, school, now)
	local pulse = 0;
	if ( since and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	if ( pg ) then
		if ( pg < 1 ) then
			Fill(cu, cv, 0, R, st.fill, alpha * 0.35, st.strip);
		end
		if ( pg > 0 ) then
			Fill(cu, cv, 0, R * pg, st.fill, alpha * (1 + pulse), st.strip);
		end
		if ( pg > 0 and pg < 1 ) then
			Ring(cu, cv, R * pg, Mix(CE, st.fill, WHITE, 0.6, 1), alpha, st.width * 0.9);
		end
	else
		Fill(cu, cv, 0, R, st.fill, alpha * (1 + pulse), st.strip);
	end
	local edge = EDGE[school] or EDGE.physical;
	edge(cu, cv, R, st, alpha, now, 0, TAU, true, pulse);
	if ( since and since < 0.45 ) then
		local s = since / 0.45;
		Ring(cu, cv, R * (0.3 + 0.7 * LAB.EaseOut(s, 3)), Mix(CE, st.line, WHITE, 0.6, 1), alpha * math.pow(1 - s, 1.3),
			st.width * 1.4);
	end
	SIG.last.school = school;
	return true;
end

---------------------------------------------------------------------------------------------
-- 6. Cooldown halo

-- the cooldown rings this frame (their jobs, in the telegraphs' order), drawn as the halo at the end
local halo = { n = 0, jobs = {} };
local HL = {};
SIG.haloLast = HL;

-- One thin ring round your feet (40 to 60 units across the screen's way, or 2.5 yd), an arc of it
-- per cooldown ring in that spell's colour, in order clockwise from the top: each on a dark
-- underline and a dim track, filling as its cooldown recovers (a bright bead at its front), and
-- flashing and popping out when its spell is cast. A small gap between arcs.
function SIG.Halo(list, n, now)
	local D = AST.draw;
	HL.n = 0;
	if ( n < 1 ) then
		return;
	end
	local sc = D.Scale();
	local R = math.max(40 / sc, math.min(60 / sc, 2.5));
	local x0, y0 = D.Map(0, 0);
	if ( not x0 ) then
		return;
	end
	-- the way that is up on the screen, and whether turning from it to higher angles goes clockwise
	local u, v = D.Unmap(x0, y0 + 50);
	if ( not u ) then
		return;
	end
	local top = math.atan2(v, u);
	local xt = D.Map(R * math.cos(top + 0.3), R * math.sin(top + 0.3));
	local dir = ( xt and xt < x0 ) and -1 or 1;
	local seg = TAU / n;
	local gap = ( n > 1 ) and math.min(seg * 0.35, 9 / math.max(1, R * sc)) or 0;
	for i = 1, n do
		local j = list[i];
		local st = j.st;
		local w = st.width;
		local alpha = j.alpha or 1;
		local s0 = top + dir * ((i - 1) * seg + gap / 2);
		local s1 = top + dir * (i * seg - gap / 2);
		if ( n == 1 ) then
			s0, s1 = top + dir * 0.06, top + dir * (TAU - 0.06);
		end
		local pg = j.progress or 1;
		local sf = s0 + (s1 - s0) * pg;
		local since = j.since;
		local ready = pg >= 1;
		-- a cast: the arc flashes white and pops out (its colour, not its alpha, so the pieces stay solid)
		local f = 0;
		if ( since and since >= 0 and since < 0.4 ) then
			f = 1 - since / 0.4;
		end
		local lc = Mix(CA, st.line, WHITE, math.max(ready and 0.3 or 0.1, 0.85 * f));
		local e = HL[i] or {};
		HL[i], HL.n = e, i;
		e.id, e.p, e.a0, e.a1 = j.def.id, pg, s0, s1;
		if ( st.style == "dots" ) then
			D.DotArc(0, 0, R, s0, s1, st.line, alpha * 0.3, st.size * 0.6, st.spacing * 0.7);
			if ( pg > 0 ) then
				D.DotArc(0, 0, R, s0, sf, lc, alpha, st.size, st.spacing * 0.7);
			end
		else
			-- a dark underline, the dim track, what has recovered, a bright bead at its front
			Arc(0, 0, R, s0, s1, Mix(CB, st.line, INK, 0.85), alpha, w * 2.3);
			Arc(0, 0, R, s0, s1, Mix(CC, st.line, INK, 0.55), alpha, w * 1.1);
			if ( pg > 0.003 ) then
				Arc(0, 0, R, s0, sf, lc, alpha, w * (1.35 + 0.5 * f));
			end
			if ( not ready and pg > 0.003 ) then
				DotAt(R * math.cos(sf), R * math.sin(sf), Mix(CD, st.line, WHITE, 0.75), alpha, w * 1.9);
			end
		end
		if ( f > 0 ) then
			local pop = R * (1 + 0.35 * LAB.EaseOut(1 - f, 2));
			if ( st.style == "dots" ) then
				D.DotArc(0, 0, pop, s0, s1, lc, alpha * f, st.size, st.spacing * 0.7);
			else
				Arc(0, 0, pop, s0, s1, lc, alpha * f, math.max(1.5, w * 0.8));
			end
		end
	end
end

local function HaloFits(j)
	return j.def.shape == "circle" and j.st.mode == "cooldown";
end

---------------------------------------------------------------------------------------------
-- The experiments

local function IsOn(e)
	for i = 1, table.getn(LAB.on) do
		if ( LAB.on[i] == e ) then
			return true;
		end
	end
	return false;
end

AST_Lab{
	id = "lab_ticks", name = "Tick ripples", kind = "Time",
	desc = "A soft ripple runs out across a ground spell's area each time it deals damage.",
	applies = "Ground spells (Consecration, Blizzard, traps...): a ripple on each of their ticks",
	fits = function(j)
		return j.def.shape == "ground";
	end,
	post = function(j, p, now)
		EachSpot(j, p, now, TickAt);
	end,
	-- a spot 6 yd off, ticking every second
	demo = function(t, j, p, now)
		local st = DemoSt(DEMO.st[1], j.st, DEMO.lines[1], DEMO.fills[1]);
		AST.draw.Spot(6, 3, 5, st, j.alpha, math.min(1, t / 3));
		local fake = DEMO.jobs[1];
		fake.def, fake.st = DEMO.ground, st;
		TickAt(fake, 6, 3, 5, j.alpha, t, 3, now);
	end,
};

AST_Lab{
	id = "lab_rune", name = "Rune circle", kind = "Signature",
	desc = "A ring of runes turns slowly inside each ground spell's area while it lasts.",
	applies = "Ground spells (Consecration, Blizzard, traps...): a rune circle in each spot",
	fits = function(j)
		return j.def.shape == "ground";
	end,
	post = function(j, p, now)
		EachSpot(j, p, now, RuneAt);
	end,
	demo = function(t, j, p, now)
		local st = DemoSt(DEMO.st[2], j.st, DEMO.lines[1], DEMO.fills[1]);
		AST.draw.Spot(6, 3, 5, st, j.alpha, math.min(1, t / 3));
		local fake = DEMO.jobs[1];
		fake.def, fake.st = DEMO.ground, st;
		RuneAt(fake, 6, 3, 5, j.alpha, t, 3, now);
	end,
};

AST_Lab{
	id = "lab_burst", name = "Burst", kind = "Signature",
	desc = "Effects on enemies burst out fast with a bright edge, a flash and flying sparks.",
	applies = "Effects on enemies (kill explosions, splashes, bursts): drawn as bursts",
	fits = function(j)
		return j.def.shape == "enemy";
	end,
	draw = DrawBursts,
	-- three bursts around you, one after another
	demo = function(t, j, p, now)
		local st = DemoSt(DEMO.st[3], j.st, DEMO.lines[7], DEMO.fills[7]);
		for k = 0, 2 do
			local age = t - k * 0.8;
			if ( age >= 0 and age < 0.6 ) then
				local a = k * 2.1 + 0.4;
				SIG.Burst(7 * math.cos(a), 7 * math.sin(a), 5, age, 0.6, st, j.alpha, k + 1, true);
			end
		end
	end,
};

AST_Lab{
	id = "lab_cone", name = "Cone polish", kind = "Signature",
	desc = "Cones shade brighter toward their far edge, with soft sides and a sweep on each cast.",
	applies = "Cones (Mind Flay, Cone of Cold), in the Smooth style",
	fits = function(j)
		return j.def.shape == "cone" and j.st.style ~= "dots";
	end,
	draw = function(j, p, now)
		return SIG.Cone(j);
	end,
	-- a violet cone, its cooldown filling twice, a cast each time
	demo = function(t, j, p, now)
		local st = DemoSt(DEMO.st[4], j.st, DEMO.lines[2], DEMO.fills[2], true);
		local fake = DEMO.jobs[1];
		local cycle = t - math.floor(t / 1.5) * 1.5;
		fake.def, fake.st, fake.size, fake.facing, fake.alpha = DEMO.cone, st, 10, j.facing or 0, j.alpha;
		fake.progress, fake.since = ( cycle < 0.25 ) and 0 or cycle / 1.5, cycle;
		SIG.Cone(fake);
	end,
};

local HALO_E;

AST_Lab{
	id = "lab_schools", name = "School themes", kind = "Signature",
	desc = "Each ring shows its spell's school: holy rays, shadow smoke, frost, flames, leaves...",
	applies = "Rings around you, and cones' far edges, in the Smooth style",
	fits = function(j)
		local s = j.def.shape;
		if ( ( s ~= "circle" and s ~= "cone" ) or j.st.style == "dots" or not SIG.SchoolOf(j.def) ) then
			return false;
		end
		-- a cooldown ring the halo takes is the halo's
		return not ( s == "circle" and HALO_E and HaloFits(j) and IsOn(HALO_E) );
	end,
	draw = function(j, p, now)
		if ( j.def.shape ~= "circle" ) then
			return false;
		end
		return SIG.SchoolCircle(0, 0, j.size, j.st, j.alpha, j.progress, j.since, SIG.SchoolOf(j.def), now);
	end,
	post = function(j, p, now)
		if ( j.def.shape == "cone" ) then
			local h = (j.def.halfAngle or 45) * PI / 180;
			local pulse = ( j.since and j.since < 0.35 ) and 1 - j.since / 0.35 or 0;
			EDGE[SIG.SchoolOf(j.def)](0, 0, j.size, j.st, j.alpha, now, j.facing - h, 2 * h, false, pulse);
		end
	end,
	-- six rings around you, one per school, each filling and cast in turn
	demo = function(t, j, p, now)
		for i = 1, 6 do
			local st = DemoSt(DEMO.st[i], j.st, DEMO.lines[i], DEMO.fills[i], true);
			local a = (i - 1) * PI / 3 + PI / 6;
			local k = t + i * 0.45;
			local cycle = k - math.floor(k / 2.5) * 2.5;
			SIG.SchoolCircle(7.5 * math.cos(a), 7.5 * math.sin(a), 3, st, j.alpha, cycle / 2.5, cycle, DEMO.schools[i], now);
		end
	end,
};

HALO_E = {
	id = "lab_halo", name = "Cooldown halo", kind = "Signature",
	desc = "Every cooldown ring becomes one arc of a small halo at your feet, filling as it recovers.",
	applies = "Rings around you set to \"Always + cooldown fill\": one halo at your feet instead",
	fits = HaloFits,
	draw = function(j, p, now)
		halo.n = halo.n + 1;
		halo.jobs[halo.n] = j;
		return true;
	end,
	after = function(p, now)
		local n = halo.n;
		halo.n = 0;
		SIG.Halo(halo.jobs, n, now);
	end,
	-- three spells' cooldowns: 1.3, 2.1 and 2.8 sec
	demo = function(t, j, p, now)
		local cds, offs = DEMO.cds, DEMO.offs;
		for i = 1, 3 do
			local f = DEMO.jobs[i];
			local k = t + offs[i];
			local since = k - math.floor(k / cds[i]) * cds[i];
			f.def, f.st, f.alpha = DEMO.circles[i], DemoSt(DEMO.st[i], j.st, DEMO.lines[i], DEMO.fills[i]), j.alpha;
			f.progress, f.since = math.min(1, since / cds[i]), since;
		end
		SIG.Halo(DEMO.jobs, 3, now);
	end,
};
AST_Lab(HALO_E);
