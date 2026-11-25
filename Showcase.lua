-- Azeroth Survivors Telegraphs: the showcase (/ast showcase, or the Showcase button at the top of the
-- options), for a video of what the addon can do. Everything at once, as one big telegraph round
-- your hero that turns until it's stopped:
--   * at the centre, your class's main ring filling with its cooldown on a turning rune circle; on
--     every other cast a wave of light runs out from it to the edge, lighting each ring it passes;
--   * your class's cone sweeping round, with its range bands;
--   * your class's other telegraphs orbiting one way, and Any class's the other (amulets, racials, a
--     revive, the guardians' rings warming to red, a few skill ranges, your own rings), each in its
--     own colours with its whole look on: cooldowns filling, spots filling with their time, bursts on
--     enemies, flashes, glow;
--   * your spell range round it all, a ring of runes inside it and two comets circling it;
--   * the name of each one as it comes round to the front (the side toward the camera);
--   * on the minimap, the guardians', bosses' and caches' pins.
-- Its size follows the camera: the edge is the largest ring that stays on the screen, and the rest
-- in proportion. It plays as its own hidden telegraph's Test press, kept going. Your telegraphs wait while it plays
-- (Core asks Look for their settings), and your settings aren't touched.

local S = { on = false, t0 = 0, builtAt = -10, off = {}, scale = nil, fitAt = -10 };
AST.showcase = S;

local PI = 3.14159265;
-- as drawn with the edge 24 yd round you (all of it scaled to fit the screen)
local R_CENTRE, R_IN, R_OUT, R_FRAME, L_CONE = 6, 12.5, 18.5, 24, 20;
local SPIN_IN, SPIN_OUT, SPIN_CONE = 0.2, -0.14, 0.5;
local MOST_IN, MOST_OUT, SKILLS = 12, 14, 3;
local BEAT = 4.8;    -- the centre ring's cooldown is half this: the wave runs out on every other cast
local WAVE = 1.2;    -- how long the wave takes to reach the edge
local WARN = { 1, 0.22, 0.15 };

local D, X;          -- AST.draw, AST.lab.tex (nil without the Lab): set as each frame starts

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: " .. msg);
end

local function Mod(a, b)
	return a - math.floor(a / b) * b;
end

local function Ease(x)
	x = math.max(0, math.min(1, x));
	return 1 - (1 - x) * (1 - x) * (1 - x);
end

-- Seconds since it started, on GetTime's clock: it plays on while the game is paused.
function S.Clock()
	return GetTime() - S.t0;
end

-- While it plays, your telegraphs wait: Core asks for each one's settings through this.
function S.Look(def, st)
	if ( def.id == "showcase" or def.shape == "lab" ) then
		return st;
	end
	local off = S.off[st];
	if ( not off ) then
		off = setmetatable({ enabled = false }, { __index = st });
		S.off[st] = off;
	end
	return off;
end

---------------------------------------------------------------------------------------------
-- What it shows

-- A telegraph's look in it: its own colours, bright, every part on, in the Texture style; `fill` its
-- fill's opacity (nil: none).
local function Make(base, fill)
	local l = base.line or { 1, 1, 1, 1 };
	local f = base.fill or l;
	local t = setmetatable({}, { __index = base });
	t.style = "texture";
	t.lineOn, t.areaOn, t.frontOn, t.pulseOn, t.glow = true, true, true, true, true;
	t.fillOn = fill ~= nil;
	t.cdFill, t.durFill, t.uptime = true, true, true;
	t.width = 2.5;
	t.line = { l[1], l[2], l[3], 1 };
	t.fill = { f[1], f[2], f[3], fill or 0 };
	t.bands, t.bandEvery, t.bandNumbers, t.wallOn, t.marks = false, 5, false, false, false;
	return t;
end

-- How it plays: its cooldown filling it (cd), a flash on each cast or proc (flash), a spot filling
-- with its time (spot), bursts on enemies (burst), a teammate brought back (revive), a guardian's
-- ring warming as you near its edge (warm), or always there (steady).
local function KindOf(d, st)
	if ( d.shape == "ground" ) then
		return "spot";
	elseif ( d.shape == "enemy" ) then
		return "burst";
	elseif ( d.shape == "downed" ) then
		return "revive";
	elseif ( d.shape == "world" ) then
		return "warm";
	elseif ( d.of ) then
		return st.mode == "cast" and "flash" or "steady";
	elseif ( d.custom or d.id == "ring" or st.mode == "always" ) then
		return "steady";
	end
	for i = 1, table.getn(d.modes or {}) do
		if ( d.modes[i] == "cooldown" ) then
			return "cd";
		end
	end
	return st.mode == "cooldown" and "cd" or "flash";
end

local function Name(d)
	if ( d.custom ) then
		return string.format(AST_L("Custom ring %d"), d.custom);
	elseif ( d.of ) then
		return string.format(AST_L(d.ofFmt), AST_L(d.of));
	end
	return AST_L(d.name);
end

-- One of them: `base` its settings (a telegraph of another class's: its own colours).
local function Item(d, n, base)
	base = base or AST.Settings(d);
	local it = { def = d, n = n, phase = n * 0.61, name = Name(d), kind = KindOf(d, base),
		full = Make(base, 0.2), soft = Make(base, 0.07), plain = Make(base, nil), hot = Make(base, 0.08) };
	it.cone = Make(base, 0.16);
	it.cone.bands = true;
	return it;
end

local function Borrowed(d)
	local own = d.defaults or {};
	return setmetatable({ line = own.line, fill = own.fill }, { __index = AST.common });
end

-- Which goes where: your class's main ring at the centre, its cone, its spell range as the edge,
-- its other telegraphs on the inner orbit, Any class's (and a few skill ranges: the smallest, one
-- between, the largest) on the outer. A class with no cone shows another class's.
function S.Build()
	local _, DEFS = AST.State();
	local plan = { inner = {}, outer = {} };
	local centre, cone, frame, skills = nil, nil, nil, {};
	local inner, outer = {}, {};
	for i = 1, table.getn(DEFS or {}) do
		local d = DEFS[i];
		if ( not d.hidden and d.shape ~= "lab" and d.shape ~= "pins" ) then
			local any = d.group == "common";
			if ( d.shape == "cone" ) then
				cone = cone or d;
			elseif ( not any and not frame and d.shape == "circle" and string.find(d.id, "range$") ) then
				frame = d;
			elseif ( not any and not centre and d.shape == "circle" and d.spellKey and not d.of ) then
				centre = d;
			elseif ( d.of ) then
				if ( d.sizePattern and d.base ) then
					table.insert(skills, d);
				end
			elseif ( any or d.custom ) then
				table.insert(outer, d);
			else
				table.insert(inner, d);
			end
		end
	end
	table.sort(skills, function(a, b) return a.base < b.base; end);
	local ns = table.getn(skills);
	if ( ns > 0 ) then
		table.insert(outer, 1, skills[1]);
	end
	if ( ns > 2 ) then
		table.insert(outer, 2, skills[math.floor((ns + 1) / 2)]);
	end
	if ( ns > 1 ) then
		table.insert(outer, 3, skills[ns]);
	end
	if ( not centre and table.getn(inner) > 0 ) then
		centre = table.remove(inner, 1);
	end
	local n = 0;
	for i = 1, math.min(MOST_IN, table.getn(inner)) do
		n = n + 1;
		table.insert(plan.inner, Item(inner[i], n));
	end
	for i = 1, math.min(MOST_OUT, table.getn(outer)) do
		n = n + 1;
		table.insert(plan.outer, Item(outer[i], n));
	end
	plan.centre = centre and Item(centre, 0);
	if ( frame ) then
		plan.frame = Item(frame, 0);
	else
		plan.frame = Item({ id = "showcase_edge", name = "Spell range", shape = "circle" }, 0,
			Borrowed({ defaults = { line = { 0.55, 0.8, 1, 1 } } }));
	end
	if ( not cone ) then
		local reg = AST.registry;
		for _, class in ipairs({ "mage", "priest" }) do
			local r = reg[class];
			for k = 1, table.getn(r and r.defs or {}) do
				if ( not cone and r.defs[k].shape == "cone" ) then
					cone = r.defs[k];
					plan.cone = Item(cone, 0, Borrowed(cone));
				end
			end
		end
	elseif ( cone ) then
		plan.cone = Item(cone, 0);
	end
	return plan;
end

---------------------------------------------------------------------------------------------
-- Drawing

-- A ring R round (cu, cv) in look st, with its fill (p: filled so far) and a cast's pulse (since):
-- in texture, else Core's.
local function Ring(cu, cv, R, st, alpha, p, since)
	if ( R <= 0.05 or alpha <= 0.003 ) then
		return;
	end
	if ( not ( X and X.Circle(cu, cv, R, st, alpha, p, since) ) ) then
		D.Circle(cu, cv, R, st, alpha, p, since);
	end
end

-- A line round (cu, cv) from angle a0 to a1, w units wide.
local function Arc(cu, cv, R, w, c, alpha, a0, a1)
	if ( R <= 0.05 or alpha <= 0.003 ) then
		return;
	end
	if ( X and X.Arc(cu, cv, R, w, c, alpha, a0, a1) ) then
		return;
	end
	D.Begin();
	if ( D.AddArc(cu, cv, R, a0, a1) ) then
		D.Stroke(a1 - a0 > 2 * PI - 0.001, c, alpha, w);
	end
end

-- One of the game's textures laid on the ground (only with the Lab's textures; nothing where they
-- can't be laid).
local function Lay(name, cu, cv, R, rot, c, alpha, blend)
	if ( X and X.Ground and X.T and alpha > 0.003 ) then
		X.Ground(X.T[name], cu, cv, R, rot, c, alpha, blend);
	end
end

local function Light(c)
	return { 0.5 + 0.5 * c[1], 0.5 + 0.5 * c[2], 0.5 + 0.5 * c[3], 1 };
end

-- Brighter for a moment as the wave passes R.
local function Lift(R, wave)
	if ( not wave ) then
		return 1;
	end
	return 1 + 0.7 * math.max(0, 1 - math.abs(R - wave) / 3);
end

-- Each kind of telegraph playing at (cu, cv), r yd, at time t, its opacity a.
local PLAY = {};
PLAY.cd = function(it, cu, cv, r, t, a)
	local P = 2.4 + 0.4 * Mod(it.n, 3);
	local k = Mod(t + it.phase, P);
	Ring(cu, cv, r, it.full, a, k / P, k);
end
PLAY.flash = function(it, cu, cv, r, t, a)
	local k = Mod(t + it.phase, 2 + 0.3 * Mod(it.n, 4));
	Ring(cu, cv, r, it.full, a * (0.35 + 0.65 * math.max(0, 1 - k / 0.8)), nil, k);
end
PLAY.spot = function(it, cu, cv, r, t, a)
	local dur = 3.2;
	local k = Mod(t + it.phase, dur + 0.6);
	local fade = 1;
	if ( k > dur ) then
		fade = 1 - (k - dur) / 0.6;
	end
	Lay("swirl", cu, cv, r * 0.95, -t * 0.6 - it.phase, it.full.fill, a * fade * 1.5, "BLEND");
	Ring(cu, cv, r, it.full, a * fade, math.min(1, k / dur), k);
end
PLAY.burst = function(it, cu, cv, r, t, a)
	-- two enemies hit, one a moment after the other
	for b = 0, 1 do
		local k = Mod(t + it.phase - b * 0.55, 1.6);
		if ( k < 0.9 ) then
			local s = 1 - 0.4 * b;
			Ring(cu + b * r * 0.45, cv - b * r * 0.35, r * s * (0.6 + 0.4 * k / 0.9), it.full, a * (1 - k / 0.9), nil, nil);
		end
	end
	Lay("blob", cu, cv, r * 0.22, 0, it.full.line, a * 0.7, "BLEND");
end
PLAY.revive = function(it, cu, cv, r, t, a)
	local k = Mod(t + it.phase, 3.4);
	local p = math.min(1, k / 2.6);
	Ring(cu, cv, r, it.full, a, p < 1 and p or nil, k >= 2.6 and k - 2.6 or nil);
	Lay("blob", cu, cv, r * 0.3, 0, it.full.line, a * 0.8, "BLEND");
end
PLAY.warm = function(it, cu, cv, r, t, a)
	local w = 0.5 + 0.5 * math.sin(t * 0.9 + it.phase);
	w = w * w;
	local st, base = it.hot, it.soft;
	local beat = 0.5 + 0.5 * math.sin(t * 2 * PI * (0.8 + 2.2 * w));
	for c = 1, 3 do
		st.line[c] = base.line[c] + (WARN[c] - base.line[c]) * w;
		st.fill[c] = base.fill[c] + (WARN[c] - base.fill[c]) * w;
	end
	st.fill[4] = 0.06 + 0.12 * w * beat;
	st.width = 2.5 * (1 + 0.5 * w);
	Ring(cu, cv, r, st, a * (0.75 + 0.25 * w * beat), nil, nil);
end
PLAY.steady = function(it, cu, cv, r, t, a)
	Ring(cu, cv, r, it.soft, a * (0.8 + 0.2 * math.sin(t * 1.6 + it.phase)), nil, nil);
end

-- The side of a ring R round you toward the camera (lowest on the screen): its angle, and the
-- screen heights of its lowest and highest points.
local function Front(R)
	local lo, hi, at;
	for k = 0, 23 do
		local a = k * PI / 12;
		local _, y = D.Map(R * math.cos(a), R * math.sin(a));
		if ( y ) then
			if ( not lo or y < lo ) then
				lo, at = y, a;
			end
			if ( not hi or y > hi ) then
				hi = y;
			end
		end
	end
	return at or -PI / 2, lo or 0, hi or 0;
end

-- Its name under it (on the camera's side), `k` how near the front it is (0 back, 1 front).
local function Label(it, cu, cv, r, fa, a)
	if ( a <= 0.02 ) then
		return;
	end
	local x, y = D.Map(cu + (r + 1.2) * math.cos(fa), cv + (r + 1.2) * math.sin(fa));
	if ( x ) then
		D.Text(it.name, x, y - 6, Light(it.full.line), math.min(1, a));
	end
end

-- An orbit of them R yd round you, turning `spin` radians a second; each comes in a moment after
-- the one before, and shows its name as it comes round to the front.
local function Orbit(list, R, spin, t, a, grow, wave)
	local n = table.getn(list);
	if ( n == 0 ) then
		return;
	end
	local r = math.max(1.6, math.min(3, 0.36 * 2 * PI * R / n)) * grow;
	R = R * grow;
	if ( wave ) then
		wave = wave * grow;
	end
	local fa, lo, hi = Front(R);
	for i = 1, n do
		local it = list[i];
		local ang = t * spin + (i - 1) * 2 * PI / n;
		local cu, cv = R * math.cos(ang), R * math.sin(ang);
		local ai = a * Ease((t - 0.5 - 0.07 * i) / 0.5);
		if ( ai > 0.003 ) then
			PLAY[it.kind](it, cu, cv, r, t, ai * Lift(R, wave));
			local _, y = D.Map(cu, cv);
			if ( y and hi - lo > 1 ) then
				local k = (hi - y) / (hi - lo);
				Label(it, cu, cv, r, fa, ai * (k - 0.9) / 0.07);
			end
		end
	end
end

-- The edge: the orbits' paths, a ring of runes, your spell range and its two comets, the wave.
local function Edge(plan, t, a, grow, wave)
	local it = plan.frame;
	local R = R_FRAME * grow;
	local c = it.plain.line;
	Arc(0, 0, R_IN * grow, 1.5, c, a * 0.14, 0, 2 * PI);
	Arc(0, 0, R_OUT * grow, 1.5, c, a * 0.14, 0, 2 * PI);
	Lay("runes", 0, 0, R - 1.6 * grow, t * 0.06, c, a * 0.16, "ADD");
	Ring(0, 0, R, it.plain, a * 0.9 * Lift(R_FRAME, wave), nil, nil);
	local bright = Light(c);
	local head = -t * 2 * PI / 9;
	for i = 0, 1 do
		local h = head + i * PI;
		for k = 1, 7 do
			local f = 1 - (k - 1) / 7;
			Arc(0, 0, R, 2.5 * (1 + f), bright, a * f, h + 1.2 * (k - 1) / 7, h + 1.2 * k / 7);
		end
		Lay("blob", R * math.cos(h), R * math.sin(h), 1.4 * grow, 0, bright, a * 0.9, "BLEND");
	end
	if ( wave ) then
		local f = 1 - Mod(t, BEAT) / WAVE;
		Arc(0, 0, wave * grow, 4, bright, a * 0.6 * f, 0, 2 * PI);
		Lay("soft", 0, 0, wave * grow, 0, c, a * 0.4 * f, "BLEND");
	end
	local fa = Front(R);
	Label(it, R * math.cos(fa), R * math.sin(fa), 0, fa, a);
end

-- The centre: your main ring filling with its cooldown (cast as each fills) on a rune circle.
local function Centre(plan, t, a, grow)
	local it = plan.centre;
	if ( not it ) then
		return;
	end
	local R = R_CENTRE * grow;
	local c = it.full.line;
	Lay("rune", 0, 0, R + 0.9 * grow, -t * 0.3, c, a * 0.6, "BLEND");
	Lay("runes", 0, 0, R * 0.62, t * 0.5, c, a * 0.4, "ADD");
	if ( it.kind == "cd" or it.kind == "flash" or it.kind == "steady" ) then
		local P = BEAT / 2;
		local k = Mod(t, P);
		Ring(0, 0, R, it.full, a, k / P, k);
	else
		PLAY[it.kind](it, 0, 0, R, t, a);
	end
	local fa = Front(R);
	Label(it, 0, 0, R, fa, a);
end

-- Your cone sweeping round, filling, with its range bands; its name at its tip.
local function Sweep(plan, t, a, grow, p, now)
	local it = plan.cone;
	if ( not it ) then
		return;
	end
	local j = S.coneJob;
	if ( not j ) then
		j = {};
		S.coneJob = j;
	end
	local P = 2.4;
	local k = Mod(t + 0.3, P);
	j.def, j.st, j.size, j.facing = it.def, it.cone, L_CONE * grow, t * SPIN_CONE;
	j.progress, j.since, j.alpha = k / P, k, a * 0.9;
	if ( not ( X and X.Cone and X.Cone(j) ) ) then
		D.Cone(j);
	end
	if ( D.Depth ) then
		D.Depth(j, p, now);
	end
	Label(it, (j.size + 0.6 * grow) * math.cos(j.facing), (j.size + 0.6 * grow) * math.sin(j.facing), 0, j.facing, a);
end

-- How far round you the edge can go and stay on the screen (with a margin), in yd.
local function Fit()
	local W, Ht = WorldFrame:GetWidth() or 1024, WorldFrame:GetHeight() or 768;
	local lo, hi = 4, 40;
	for i = 1, 9 do
		local R = (lo + hi) / 2;
		local ok = true;
		for k = 0, 23 do
			local a = k * PI / 12;
			local x, y = D.Map(R * math.cos(a), R * math.sin(a));
			if ( not x or x < W * 0.04 or x > W * 0.96 or y < Ht * 0.11 or y > Ht * 0.93 ) then
				ok = false;
				break;
			end
		end
		if ( ok ) then
			lo = R;
		else
			hi = R;
		end
	end
	return lo;
end

-- Its frame: everything, round you.
function S.Draw(j, p, now)
	if ( not S.on ) then
		return;
	end
	D = AST.draw;
	X = AST.lab and AST.lab.tex;
	local t = S.Clock();
	if ( not S.plan or t - S.builtAt > 5 ) then
		-- again now and then: your settings may have changed
		S.plan, S.builtAt = S.Build(), t;
	end
	local plan = S.plan;
	local a = math.min(1, t / 0.6) * (j.alpha or 1);
	D.H.dz = 0;
	-- its size: to fit the screen, looked at four times a second and eased toward (the camera zooms)
	if ( t - S.fitAt >= 0.25 ) then
		S.fitAt = t;
		local want = math.max(0.25, math.min(1.5, Fit() / R_FRAME));
		S.scale = S.scale and S.scale + (want - S.scale) * 0.35 or want;
	end
	local grow = Ease(t / 1.4) * S.scale;
	local k = Mod(t, BEAT);
	local wave;
	if ( t > 1.4 and k < WAVE ) then
		wave = R_CENTRE + (R_FRAME - R_CENTRE) * Ease(k / WAVE);
	end
	Sweep(plan, t, a, grow, p, now);
	Centre(plan, t, a, grow);
	Orbit(plan.inner, R_IN, SPIN_IN, t, a, grow, wave);
	Orbit(plan.outer, R_OUT, SPIN_OUT, t, a, grow, wave);
	Edge(plan, t, a, grow, wave);
end

-- Its own telegraph: hidden from the lists, never on of itself, played by a Test press kept going.
AST_Register("common", { {
	id = "showcase", name = "Showcase", shape = "world", hidden = true, radius = R_FRAME,
	defaults = { enabled = false },
	points = function() return {}; end,
	demo = function() return { { rel = true, x = 0, y = 0 } }; end,
	draw = function(j, p, now) S.Draw(j, p, now); end,
} });

local frame = CreateFrame("Frame");
S.frame = frame;
frame:SetScript("OnUpdate", function()
	if ( S.on ) then
		AST.preview.showcase = GetTime() + 3;
	end
end);

function S.Start()
	local db = AST.State();
	if ( not db ) then
		return;
	end
	S.on, S.t0, S.plan, S.off, S.scale, S.fitAt = true, GetTime(), nil, {}, nil, -10;
	AST.preview.showcase = GetTime() + 3;
	if ( ASTOptions and ASTOptions:IsShown() ) then
		-- out of the way of the camera
		ASTOptions:Hide();
	end
	Print(AST_L("Showcase: all your telegraphs at once. /ast showcase (or the Showcase button) stops it."));
	AST.RefreshOptions();
end

function S.Stop()
	S.on, S.plan, S.off = false, nil, {};
	AST.preview.showcase = nil;
	Print(AST_L("Showcase stopped."));
	AST.RefreshOptions();
end

function S.Toggle()
	if ( S.on ) then
		S.Stop();
	else
		S.Start();
	end
end
