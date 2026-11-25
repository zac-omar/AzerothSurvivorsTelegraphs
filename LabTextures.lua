-- Azeroth Survivors Telegraphs: Lab experiments (LabTextures). See Lab.lua.
-- The game's own textures laid on the ground: soft glows, rings in one piece, rune circles, light
-- that adds instead of paint, moving fills and star flashes; and /ast lab textest, which shows what
-- this client does with them.

local LAB = AST.lab;
local D = AST.draw;
local PI = 3.14159265;

-- The textures. Those with no alpha of their own (LIGHT) are light only: blended "ADD" they add
-- their brightness, blended normally they would be black squares, so they're left out where the
-- client can't blend that way.
local T = {
	disc = "Spells\\GENERICGLOW2_64",        -- a soft-edged disc
	blob = "Spells\\GENERICGLOW64",          -- a soft blob, brightest in the middle
	soft = "particles\\genericglow5",        -- a thin soft ring
	faded = "Spells\\GenericGlowFaded",      -- a wide soft ring
	thin = "Spells\\WhiteRingThin128",       -- a bright ring (light)
	fat = "SPELLS\\WhiteRingFat128",         -- a ring lit from within (light)
	ping = "Interface\\Cooldown\\ping4",     -- a fine ring with a glow inside (light)
	circle = "Spells\\Circle",               -- a very fine ring (light)
	rune = "Spells\\AuraRune8",              -- a rune circle
	runes = "Spells\\AuraRune_B",            -- a ring of runes (light)
	swirl = "Spells\\Tornado2b",             -- a swirl
	cloud = "Spells\\AlphaCloud",            -- a cloud
	star = "Spells\\StarFlash_Grey",         -- a star flash
	mask = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
};
-- How far out each one's ring (or the edge of its glow) lies, a share of its half width: the circle
-- on the ground it is laid on goes there.
local K = {
	[T.disc] = 0.7, [T.blob] = 0.75, [T.soft] = 0.65, [T.faded] = 0.56, [T.thin] = 0.897, [T.fat] = 0.843,
	[T.ping] = 0.84, [T.circle] = 0.965, [T.rune] = 0.858, [T.runes] = 0.905, [T.swirl] = 0.9,
	[T.cloud] = 0.8, [T.star] = 0.5, [T.mask] = 1,
};
-- how wide each ring's line is, a share of its radius (for picking one for a size)
local LINE = { [T.circle] = 0.016, [T.ping] = 0.054, [T.thin] = 0.11 };
local LIGHT = { [T.thin] = true, [T.fat] = true, [T.ping] = true, [T.circle] = true, [T.runes] = true };

-- Whether textures can be blended "ADD" here (asked once).
local X = { proxies = {} };
local function CanAdd()
	if ( X.add == nil ) then
		local t = D.canvas:CreateTexture(nil, "ARTWORK");
		t:Hide();
		X.add = t.SetBlendMode ~= nil;
	end
	return X.add;
end

-- Texture `path` on the screen as the parallelogram e + s a + q b (s, q from -1 to 1 across it,
-- s to the texture's right, q to its top): one piece, the screen's box round it, its 8 texture
-- coordinates the corners'. Light-only textures are always blended "ADD".
local function Lay(path, blend, over, ex, ey, ax, ay, bx, by, c, alpha)
	if ( alpha <= 0.003 or ( LIGHT[path] and not CanAdd() ) ) then
		return nil;
	end
	local det = ax * by - ay * bx;
	if ( math.abs(det) < 1e-6 ) then
		return nil;
	end
	local hw, hh = math.abs(ax) + math.abs(bx), math.abs(ay) + math.abs(by);
	local sw, sh = LAB.sw or 1024, LAB.sh or 768;
	if ( ex + hw < -50 or ex - hw > sw + 50 or ey + hh < -50 or ey - hh > sh + 50 or hw > 8 * sw ) then
		return nil;
	end
	local t = LAB.Tex(path, LIGHT[path] and "ADD" or blend, over);
	-- a corner (dx, dy) from the middle: s = (dx by - dy bx) / det, q = (ax dy - ay dx) / det; the
	-- texture's x = 0.5 + s / 2, its y (top to bottom) 0.5 - q / 2
	local ux, uy = 0.5 * by / det * hw, -0.5 * bx / det * hh;
	local vx, vy = 0.5 * ay / det * hw, -0.5 * ax / det * hh;
	LAB.Place(t, ex - hw, ey - hh, 2 * hw, 2 * hh, 0.5 - ux + uy, 0.5 - vx + vy, 0.5 - ux - uy, 0.5 - vx - vy,
		0.5 + ux + uy, 0.5 + vx + vy, 0.5 + ux - uy, 0.5 + vx - vy, c[1], c[2], c[3], math.min(1, (c[4] or 1) * alpha));
	return t;
end

-- The ellipse the ground circle R round (cu, cv) (at the height H.dz) shows as on the screen: its
-- centre and two half-diameters a, b that carry the unit circle onto it, of all such pairs the one
-- nearest the ground's own axes there turned by `rot` (so a texture laid on it keeps its way
-- round). Exact: through a perspective camera a circle's image is the conic H^-T C H^-1. nil when
-- it isn't an ellipse wholly in front of the camera.
local function Fit(cu, cv, R, rot)
	local H, Map = D.H, D.Map;
	local dz = H.dz or 0;
	local m11, m12, m13 = H[1], H[2], H[3] + H[9] * dz;
	local m21, m22, m23 = H[4], H[5], H[6] + H[10] * dz;
	local m31, m32, m33 = H[7], H[8], 1 + H[11] * dz;
	-- a screen point's ground point (homogeneous) is adj(M) (x, y, 1)
	local n11, n12, n13 = m22 * m33 - m23 * m32, m13 * m32 - m12 * m33, m12 * m23 - m13 * m22;
	local n21, n22, n23 = m23 * m31 - m21 * m33, m11 * m33 - m13 * m31, m13 * m21 - m11 * m23;
	local n31, n32, n33 = m21 * m32 - m22 * m31, m12 * m31 - m11 * m32, m11 * m22 - m12 * m21;
	-- (u - cu w)^2 + (v - cv w)^2 - (R w)^2 = 0, each term linear in (x, y, 1)
	local a1, a2, a3 = n11 - cu * n31, n12 - cu * n32, n13 - cu * n33;
	local b1, b2, b3 = n21 - cv * n31, n22 - cv * n32, n23 - cv * n33;
	local c1, c2, c3 = R * n31, R * n32, R * n33;
	local A = a1 * a1 + b1 * b1 - c1 * c1;
	local B = a1 * a2 + b1 * b2 - c1 * c2;
	local C = a2 * a2 + b2 * b2 - c2 * c2;
	local P = a1 * a3 + b1 * b3 - c1 * c3;
	local Q = a2 * a3 + b2 * b3 - c2 * c3;
	local F = a3 * a3 + b3 * b3 - c3 * c3;
	local det = A * C - B * B;
	if ( det <= 0 ) then
		return nil;
	end
	local ex, ey = (B * Q - C * P) / det, (B * P - A * Q) / det;
	local k = -(P * ex + Q * ey + F) / det;
	-- its shape G (d' G^-1 d = 1), and G's square root
	local g11, g12, g22 = k * C, -k * B, k * A;
	if ( g11 <= 0 or g22 <= 0 ) then
		return nil;
	end
	local s = math.sqrt(math.max(0, g11 * g22 - g12 * g12));
	local t = math.sqrt(g11 + g22 + 2 * s);
	local p11, p12, p22 = (g11 + s) / t, g12 / t, (g22 + s) / t;
	-- the ground's axes there, on the screen
	local cr, sr = math.cos(rot or 0), math.sin(rot or 0);
	local xa1, ya1 = Map(cu + R * cr, cv + R * sr);
	local xa2, ya2 = Map(cu - R * cr, cv - R * sr);
	local xb1, yb1 = Map(cu - R * sr, cv + R * cr);
	local xb2, yb2 = Map(cu + R * sr, cv - R * cr);
	if ( not ( xa1 and xa2 and xb1 and xb2 ) ) then
		return nil;
	end
	local j11, j21, j12, j22 = (xa1 - xa2) / 2, (ya1 - ya2) / 2, (xb1 - xb2) / 2, (yb1 - yb2) / 2;
	-- the turn (or turn and flip) O nearest to P^-1 J; then (a b) = P O
	local pd = p11 * p22 - p12 * p12;
	local x11, x12 = (p22 * j11 - p12 * j21) / pd, (p22 * j12 - p12 * j22) / pd;
	local x21, x22 = (p11 * j21 - p12 * j11) / pd, (p11 * j22 - p12 * j12) / pd;
	local o11, o12, o21, o22;
	if ( x11 * x22 - x12 * x21 >= 0 ) then
		local th = math.atan2(x21 - x12, x11 + x22);
		o11, o12, o21, o22 = math.cos(th), -math.sin(th), math.sin(th), math.cos(th);
	else
		local th = math.atan2(x21 + x12, x11 - x22);
		o11, o12, o21, o22 = math.cos(th), math.sin(th), math.sin(th), -math.cos(th);
	end
	return ex, ey, p11 * o11 + p12 * o21, p12 * o11 + p22 * o21, p11 * o12 + p12 * o22, p12 * o12 + p22 * o22;
end

-- Texture `path` laid flat on the ground, its own ring (K) exactly on the circle R round (cu, cv)
-- yd from the hero, turned `rot`; colour c x alpha. Returns the texture, or nil.
local function Ground(path, cu, cv, R, rot, c, alpha, blend, over)
	if ( R <= 0.01 or alpha <= 0.003 ) then
		return nil;
	end
	local ex, ey, ax, ay, bx, by = Fit(cu, cv, R, rot);
	if ( not ex ) then
		return nil;
	end
	local f = 1 / (K[path] or 1);
	return Lay(path, blend, over, ex, ey, ax * f, ay * f, bx * f, by * f, c, alpha);
end

-- A soft streak along the screen segment (x1, y1)-(x2, y2), w units either side of it: the soft
-- disc stretched along it, its fading ends a little past the segment's, so a chain of them glows
-- evenly where they meet.
local function Streak(path, x1, y1, x2, y2, w, c, alpha, blend, over, ext)
	if ( not ( x1 and x2 ) ) then
		return nil;
	end
	local dx, dy = (x2 - x1) / 2, (y2 - y1) / 2;
	local len = math.sqrt(dx * dx + dy * dy);
	if ( len < 0.5 ) then
		return nil;
	end
	local k = K[path] or 1;
	local ux, uy = dx / len, dy / len;
	local al, ac = math.max(len * (ext or math.min(1.15, 1 + 0.5 * w / len)), w) / k, w / k;
	return Lay(path, blend, over, (x1 + x2) / 2, (y1 + y2) / 2, ux * al, uy * al, -uy * ac, ux * ac, c, alpha);
end

-- The ring texture whose line comes nearest `w` units wide on a ring R round (cu, cv), and that
-- ring's fit; nil when even the finest would be too thick (Core's own ring is better then).
local function RingFit(cu, cv, R)
	local ex, ey, ax, ay, bx, by = Fit(cu, cv, R, 0);
	if ( not ex ) then
		return nil;
	end
	local rpx = math.sqrt(math.abs(ax * by - ay * bx));
	return ex, ey, ax, ay, bx, by, rpx;
end

local function LayRing(path, ex, ey, ax, ay, bx, by, scale, c, alpha, over)
	local f = scale / (K[path] or 1);
	return Lay(path, "ADD", over, ex, ey, ax * f, ay * f, bx * f, by * f, c, alpha);
end

-- The settings a job was given (not the stand-in some of these hand Core).
local function Real(st)
	return st.real or st;
end

-- A stand-in for a job's settings that Core draws with this frame: its fill's (and line's) opacity
-- times fillK (lineK); the rest its own. One per settings table, kept.
local function Proxy(j, fillK, lineK)
	local st = Real(j.st);
	local px = X.proxies[st];
	if ( not px ) then
		px = { real = st, fill = { 1, 1, 1, 1 }, line = { 1, 1, 1, 1 } };
		setmetatable(px, { __index = st });
		X.proxies[st] = px;
	end
	local f, l = st.fill, st.line;
	px.fill[1], px.fill[2], px.fill[3], px.fill[4] = f[1], f[2], f[3], f[4] * fillK;
	px.line[1], px.line[2], px.line[3], px.line[4] = l[1], l[2], l[3], (l[4] or 1) * (lineK or 1);
	j.st = px;
end

-- Whether Lab experiment `id` is on this frame.
local function On(id)
	for i = 1, table.getn(LAB.on) do
		if ( LAB.on[i].id == id ) then
			return true;
		end
	end
	return false;
end

local function Bright(c)
	return D.Bright(c);
end

local function Ease(x)
	return LAB.EaseOut(x, 3);
end

-- Each spot ground telegraph `j` shows this frame, as Core shows them: fn(j, cu, cv, R, alpha, grow,
-- age, now, around, running), at its height (H.dz, put back after). A Test press: one 6 yd away; a
-- spell that moves with you: its newest, round you (around), "running" when each lasts till the next.
local function EachSpot(j, p, now, fn)
	local def, st = j.def, Real(j.st);
	if ( j.test ) then
		fn(j, 6, 3, j.size, j.alpha, st.durFill and math.min(1, j.test / 3) or 1, j.test, now);
		return;
	end
	local follows = def.follows and D.owned.keys[def.follows];
	local spots = D.Spots();
	local newest, nfade;
	for k = 1, table.getn(spots) do
		local s = spots[k];
		local age = now - s.at;
		if ( s.id == def.id and ( s.cands or s.shown ) and age <= s.dur + 0.4 ) then
			local fade = 1;
			if ( age > s.dur ) then
				fade = 1 - (age - s.dur) / 0.4;
			end
			if ( follows ) then
				if ( not newest or s.at > newest.at ) then
					newest, nfade = s, fade;
				end
			else
				D.H.dz = s.z and s.z - p.z or 0;
				fn(j, s.x - p.x, s.y - p.y, s.r or j.size, j.alpha * fade, st.durFill and math.min(1, age / s.dur) or 1, age, now);
				D.H.dz = 0;
			end
		end
	end
	if ( newest ) then
		local age, c = now - newest.at, D.SpellOf(def);
		local cd = c and c.max;
		local running = st.uptime and cd and cd > 0 and newest.dur >= cd and age < cd + 0.5;
		fn(j, 0, 0, newest.r or j.size, j.alpha * nfade, st.durFill and math.min(1, age / newest.dur) or 1, age, now, true, running);
	end
end

-- Each enemy ring of effect telegraph `j` shown this frame (Core shows each for st.flash sec, the
-- newest first, st.most of them at most): fn(j, cu, cv, R, age, now) at its height. A Test press:
-- Core's three near the hero.
local function EachRing(j, p, now, fn)
	local st = Real(j.st);
	local flash = st.flash or 0.6;
	if ( j.test ) then
		for k = 0, 2 do
			local age = j.test - k * 0.8;
			if ( age >= 0 and age < flash ) then
				local a = k * 2.1;
				fn(j, 8 * math.cos(a), 8 * math.sin(a), j.size, age, now);
			end
		end
		return;
	end
	local rings, drawn = D.Rings(), 0;
	for k = table.getn(rings), 1, -1 do
		local r = rings[k];
		local age = now - r.at;
		if ( r.kind == j.def.id and age >= 0 and age < flash and ( (st.most or 0) <= 0 or drawn < st.most ) ) then
			drawn = drawn + 1;
			D.H.dz = r.z and r.z - p.z or 0;
			fn(j, r.x - p.x, r.y - p.y, j.size, age, now);
			D.H.dz = 0;
		end
	end
end

-- Texture rings became the standard look on this branch (2026-11-24): on once for settings saved
-- before then (Lab entries start off), after which on or off is yours.
local once = CreateFrame("Frame");
once:SetScript("OnUpdate", function()
	local db, _, _, _, byId = AST.State();
	if ( not db ) then
		return;
	end
	once:SetScript("OnUpdate", nil);
	-- and the Texture style the norm: a telegraph still on the old default (Smooth) takes it, once
	if ( not db.styleTexOnce ) then
		db.styleTexOnce = true;
		for _, s in pairs(db.t or {}) do
			if ( type(s) == "table" and s.style == "smooth" ) then
				s.style = "texture";
			end
		end
	end
	-- True circles off, once, for everyone who turned them on (Drawn and Dots never use them now; its
	-- Lab entry is hidden until it costs less)
	if ( not db.trueOffOnce ) then
		db.trueOffOnce = true;
		for i = 1, table.getn(AST.registry.lab and AST.registry.lab.defs or {}) do
			if ( AST.registry.lab.defs[i].id == "lab_true" ) then
				AST.Settings(AST.registry.lab.defs[i]).enabled = false;
			end
		end
	end
	if ( not db.texRingsOn ) then
		db.texRingsOn = true;
		for _, r in pairs(AST.registry.lab and { AST.registry.lab } or {}) do
			for i = 1, table.getn(r.defs) do
				if ( r.defs[i].id == "lab_texrings" ) then
					AST.Settings(r.defs[i]).enabled = true;
				end
			end
		end
	end
end);

-- for the tests (and other experiments)
LAB.tex = { Fit = Fit, Ground = Ground, Lay = Lay, Streak = Streak, T = T, K = K, LINE = LINE, X = X };

-- Colours and settings for the demos (a Test press of a Lab entry).
local GOLD = { line = { 1, 0.85, 0.35, 1 }, fill = { 1, 0.8, 0.3, 0.3 }, width = 3, glow = true, strip = 3,
	style = "texture", flash = 0.6, durFill = true, uptime = true, most = 0 };
local FROST = { line = { 0.55, 0.85, 1, 1 }, fill = { 0.45, 0.75, 1, 0.3 }, width = 3, glow = true, strip = 3,
	style = "texture", flash = 0.6, durFill = true, uptime = true, most = 0 };
local FIRE = { line = { 1, 0.5, 0.15, 1 }, fill = { 1, 0.45, 0.1, 0.3 }, width = 3, glow = true, strip = 3,
	style = "texture", flash = 0.6, durFill = true, uptime = true, most = 0 };
local SHADOW = { line = { 0.75, 0.45, 1, 1 }, fill = { 0.6, 0.3, 1, 0.3 }, width = 3, glow = true, strip = 3,
	style = "texture", flash = 0.6, durFill = true, uptime = true, most = 0 };


-- A demo's settings with no fill (or no line either): what Core draws for these when they're on.
local function Bare(st, noLine)
	local key = noLine and "bare2" or "bare";
	local b = st[key];
	if ( not b ) then
		b = { fill = { st.fill[1], st.fill[2], st.fill[3], 0 }, line = { st.line[1], st.line[2], st.line[3], noLine and 0 or st.line[4] } };
		setmetatable(b, { __index = st });
		st[key] = b;
	end
	return b;
end

-- Where on the screen a point on the ground is, and how many screen units a yard is there.
local function ScreenAt(cu, cv)
	local x, y = D.Map(cu, cv);
	if ( not x ) then
		return nil;
	end
	local x2, y2 = D.Map(cu + 1, cv);
	local x3, y3 = D.Map(cu, cv + 1);
	if ( not ( x2 and x3 ) ) then
		return x, y, D.Scale();
	end
	return x, y, (math.sqrt((x2 - x) * (x2 - x) + (y2 - y) * (y2 - y)) + math.sqrt((x3 - x) * (x3 - x) + (y3 - y) * (y3 - y))) / 2;
end

---------------------------------------------------------------------------------------------
-- 1. Soft glow: fills as soft light instead of stripes

-- The fill of a ring or spot: the whole area faint, the part filled so far (p; nil: all of it) full,
-- as soft discs, its front a soft glowing edge; brighter for a moment on a cast.
local function GlowFill(cu, cv, R, st, alpha, p, since, over)
	local f = st.fill;
	if ( f[4] <= 0.003 or R <= 0.05 ) then
		return;
	end
	local pulse = 0;
	if ( since and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	local fill, area, front = st.fillOn ~= false, st.areaOn ~= false, st.frontOn ~= false;
	if ( not p ) then
		if ( fill ) then
			Ground(T.disc, cu, cv, R, 0, f, alpha * (0.9 + pulse), "BLEND", over);
			Ground(T.blob, cu, cv, R, 0, f, alpha * 0.35, "BLEND", over);
		end
		return;
	end
	if ( p < 1 and area ) then
		Ground(T.disc, cu, cv, R, 0, f, alpha * 0.4, "BLEND", over);
	end
	if ( p > 0.02 ) then
		if ( fill ) then
			Ground(T.disc, cu, cv, R * p, 0, f, alpha * (1 + pulse), "BLEND", over);
			Ground(T.blob, cu, cv, R * p, 0, f, alpha * 0.5, "BLEND", over);
		end
		if ( p < 1 and front ) then
			Ground(T.soft, cu, cv, R * p, 0, Bright(f), alpha * 0.4, "BLEND", over);
		end
	end
end

-- A cone's fill front as a soft band of light along its arc.
local function GlowConeFront(j, st, alpha, p)
	local f = st.fill;
	local L, h = j.size, j.def.halfAngle * PI / 180;
	local front = L * (p or 1);
	if ( f[4] <= 0.003 or front <= 0.3 ) then
		return;
	end
	local n = math.max(2, math.ceil(2 * h / (PI / 12)));
	local w = D.Scale() * math.min(1.2, 0.12 * front);
	local c = Bright(f);
	local xa, ya = D.Map(front * math.cos(j.facing - h), front * math.sin(j.facing - h));
	for i = 1, n do
		local a = j.facing - h + 2 * h * i / n;
		local xb, yb = D.Map(front * math.cos(a), front * math.sin(a));
		Streak(T.blob, xa, ya, xb, yb, w, c, alpha * 0.4, "BLEND", nil, 1.7);
		xa, ya = xb, yb;
	end
end

local function SoftSpot(j, cu, cv, R, alpha, grow, age, now, around, running)
	local st = Real(j.st);
	if ( running ) then
		GlowFill(cu, cv, R, st, alpha * (0.8 + 0.2 * math.sin(now * 2 * PI / 3)), nil, nil);
	else
		GlowFill(cu, cv, R, st, alpha, grow, nil);
	end
end

AST_Lab{
	id = "lab_softglow", name = "Soft glow", kind = "Textures",
	desc = "Fills are soft light from the game's glow textures instead of flat paint.",
	applies = "Rings and ground spots with a fill (their fill), and cones (a soft glow at the fill's front).",
	fits = function(j)
		local s, st = j.def.shape, Real(j.st);
		if ( st.fill[4] <= 0.003 ) then
			return false;
		end
		if ( s == "circle" or s == "ground" ) then
			return not ( st.style == "texture" and On("lab_texrings") and CanAdd() );
		end
		return s == "cone";
	end,
	pre = function(j, p, now)
		local st = Real(j.st);
		if ( j.def.shape == "circle" ) then
			GlowFill(0, 0, j.size, st, j.alpha, j.progress, j.since);
		end
		-- the flat fill goes (Core still draws the outline and the fill's front)
		if ( j.def.shape ~= "cone" and st.style ~= "dots" ) then
			Proxy(j, 0, 1);
		end
	end,
	post = function(j, p, now)
		if ( j.def.shape == "ground" ) then
			EachSpot(j, p, now, SoftSpot);
		elseif ( j.def.shape == "cone" and j.progress ) then
			GlowConeFront(j, Real(j.st), j.alpha, j.progress);
		end
	end,
	demo = function(t, j, p, now)
		local k = t - math.floor(t / 1.5) * 1.5;
		GlowFill(0, 0, 8, GOLD, j.alpha, k / 1.5, k);
		D.Circle(0, 0, 8, Bare(GOLD), j.alpha, k / 1.5, k);
		local grow = math.min(1, t / 3);
		D.H.dz = 0;
		GlowFill(12, -7, 5, FIRE, j.alpha, grow, nil);
		D.Spot(12, -7, 5, Bare(FIRE), j.alpha, grow);
		local cone = X.cone or { def = { shape = "cone", halfAngle = 30 }, st = SHADOW };
		X.cone = cone;
		cone.size, cone.facing, cone.alpha, cone.progress, cone.since = 14, 2.5, j.alpha, math.min(1, t / 2.4), nil;
		D.Cone(cone);
		GlowConeFront(cone, SHADOW, j.alpha, cone.progress);
	end,
};

---------------------------------------------------------------------------------------------
-- 2. Texture rings: a whole ring in one piece

-- A big ring in arc pieces: laid whole, the texture's line would be thicker than `w` (and soft), so
-- each piece shows its own stretch of the texture's ring line, carried along the ring as it is and
-- squeezed across it to `w` units: the line stays sharp and as wide as asked at any size. The
-- pieces' boxes tile the ring without overlapping (light adds up where boxes overlap): the ring is
-- split at its four points that slope at 45 degrees on the screen; the flatter stretches (top and
-- bottom) are cut into columns, the steeper ones (the sides) into rows, so the line crosses every cut
-- at 45 degrees or more and a piece only ever shows its own short stretch; where a stretch of
-- columns meets one of rows, the cut is the upright line through that point. A piece's arc is at
-- most ~28 units long, so its straightened bend stays within a fraction of a unit.
local ARC = { t = {} };

-- One piece, in the box xl..xr, yl..yh: the ring's stretch about angle thc, whose middle is (cx, cy)
-- on the screen, the screen moving (jtx, jty) per radian along the ring and (jrx, jry) per ring's
-- radius out from it.
local function ArcPiece(path, k, line, cx, cy, jtx, jty, jrx, jry, thc, w, xl, xr, yl, yh, c, alpha, over)
	local sw, sh = LAB.sw or 1024, LAB.sh or 768;
	if ( yh <= yl or xr <= xl or xr < -50 or xl > sw + 50 or yh < -50 or yl > sh + 50 ) then
		return;
	end
	-- this piece's map: along the ring as the whole ring's, across it squeezed by q
	local rx, ry = math.cos(thc), math.sin(thc);
	local tx, ty = -ry, rx;
	local jt = math.sqrt(jtx * jtx + jty * jty);
	if ( jt < 1e-6 ) then
		return;
	end
	local across = math.abs(jrx * jty - jry * jtx) / jt;
	local q = w / math.max(0.01, line * across);
	local m11, m12 = jtx * tx + q * jrx * rx, jtx * ty + q * jrx * ry;
	local m21, m22 = jty * tx + q * jry * rx, jty * ty + q * jry * ry;
	local det = m11 * m22 - m12 * m21;
	if ( math.abs(det) < 1e-9 ) then
		return;
	end
	local t = LAB.Tex(path, "ADD", over);
	-- the box's corners to texture coordinates, back through the map: a corner (dx, dy) from the
	-- arc's middle is z = r + M^-1 (dx, dy); x = 0.5 + k zx / 2, y = 0.5 - k zy / 2
	local ux, uy = 0.5 * k * m22 / det, -0.5 * k * m21 / det;
	local vx, vy = -0.5 * k * m12 / det, 0.5 * k * m11 / det;
	local ox, oy = 0.5 + 0.5 * k * rx, 0.5 - 0.5 * k * ry;
	local dl, dr, dt, db = xl - cx, xr - cx, yh - cy, yl - cy;
	LAB.Place(t, xl, yl, xr - xl, yh - yl, ox + ux * dl + vx * dt, oy - uy * dl - vy * dt,
		ox + ux * dl + vx * db, oy - uy * dl - vy * db,
		ox + ux * dr + vx * dt, oy - uy * dr - vy * dt,
		ox + ux * dr + vx * db, oy - uy * dr - vy * db, c[1], c[2], c[3], math.min(1, (c[4] or 1) * alpha));
end

local function TexArcs(path, ex, ey, ax, ay, bx, by, lw, w, c, alpha, over)
	local k, line = K[path] or 1, LINE[path];
	local rpx = math.sqrt(math.abs(ax * by - ay * bx));
	local h = w + 1;
	-- the four points sloping at 45 degrees: where the tangent's x and y are equal or opposite
	local T4 = ARC.t;
	T4[1] = math.atan2(bx - by, ax - ay);
	T4[2] = math.atan2(bx + by, ax + ay);
	T4[3], T4[4] = T4[1] + PI, T4[2] + PI;
	for i = 2, 4 do
		while ( T4[i] < T4[1] ) do
			T4[i] = T4[i] + 2 * PI;
		end
		while ( T4[i] >= T4[1] + 2 * PI ) do
			T4[i] = T4[i] - 2 * PI;
		end
	end
	table.sort(T4);
	for s = 1, 4 do
		local a0 = T4[s];
		local a1 = s < 4 and T4[s + 1] or T4[1] + 2 * PI;
		local mid = (a0 + a1) / 2;
		local tmx, tmy = -ax * math.sin(mid) + bx * math.cos(mid), -ay * math.sin(mid) + by * math.cos(mid);
		local flat = math.abs(tmx) >= math.abs(tmy);
		-- its length on the screen, and pieces at most ~28 units long
		local len, px, py = 0, ex + ax * math.cos(a0) + bx * math.sin(a0), ey + ay * math.cos(a0) + by * math.sin(a0);
		for i = 1, 8 do
			local th = a0 + (a1 - a0) * i / 8;
			local qx, qy = ex + ax * math.cos(th) + bx * math.sin(th), ey + ay * math.cos(th) + by * math.sin(th);
			len = len + math.sqrt((qx - px) * (qx - px) + (qy - py) * (qy - py));
			px, py = qx, qy;
		end
		local m = math.max(1, math.min(60, math.ceil(len / 28)));
		-- the ends' x (the cut where columns meet rows), and which side of them a stretch of rows lies
		local xa = ex + ax * math.cos(a0) + bx * math.sin(a0);
		local xb = ex + ax * math.cos(a1) + bx * math.sin(a1);
		local xm = ex + ax * math.cos(mid) + bx * math.sin(mid);
		for i = 0, m - 1 do
			local th1, th2 = a0 + (a1 - a0) * i / m, a0 + (a1 - a0) * (i + 1) / m;
			local thm = (th1 + th2) / 2;
			local x1, y1 = ex + ax * math.cos(th1) + bx * math.sin(th1), ey + ay * math.cos(th1) + by * math.sin(th1);
			local x2, y2 = ex + ax * math.cos(th2) + bx * math.sin(th2), ey + ay * math.cos(th2) + by * math.sin(th2);
			local x3, y3 = ex + ax * math.cos(thm) + bx * math.sin(thm), ey + ay * math.cos(thm) + by * math.sin(thm);
			local xl, xr, yl, yh;
			if ( flat ) then
				-- a column: its own arc's x, its height the arc's and the line's either side
				xl, xr = math.min(x1, x2), math.max(x1, x2);
				yl, yh = math.min(y1, y2, y3) - h, math.max(y1, y2, y3) + h;
			else
				-- a row: its own arc's y, its width the arc's and the line's either side; at a stretch's
				-- ends, cut at the upright line through the 45-degree point, on the row's side of it
				yl, yh = math.min(y1, y2), math.max(y1, y2);
				xl, xr = math.min(x1, x2, x3) - h, math.max(x1, x2, x3) + h;
				if ( i == 0 ) then
					if ( xm < xa ) then xr = math.min(xr, xa); else xl = math.max(xl, xa); end
					if ( y1 >= y2 ) then yh = yh + h; else yl = yl - h; end
				end
				if ( i == m - 1 ) then
					if ( xm < xb ) then xr = math.min(xr, xb); else xl = math.max(xl, xb); end
					if ( y2 >= y1 ) then yh = yh + h; else yl = yl - h; end
				end
			end
			local thc = (th1 + th2) / 2;
			local rx, ry = math.cos(thc), math.sin(thc);
			ArcPiece(path, k, line, ex + ax * rx + bx * ry, ey + ay * rx + by * ry, bx * rx - ax * ry, by * rx - ay * ry,
				ax * rx + bx * ry, ay * rx + by * ry, thc, w, xl, xr, yl, yh, c, alpha, over);
		end
	end
	return true;
end

-- How far a ring R round (cu, cv) reaches toward the horizon: its depth w along the circle is
-- W0 + k7 cos a + k8 sin a (1 at the hero; 0 at the horizon). Past: whether any of it is nearer the
-- horizon than WMIN (then it isn't a whole ellipse on the screen).
local WMIN = 0.06;
local function Depth(cu, cv, R)
	local H = D.H;
	local k7, k8 = H[7] * R, H[8] * R;
	return H[7] * cu + H[8] * cv + 1 + H[11] * (H.dz or 0), k7, k8;
end

-- A ring reaching past the horizon, in arc pieces as TexArcs lays them, but worked out point by
-- point through the camera (its picture isn't an ellipse any more): its part in front of the horizon
-- only. True when there's nothing to draw or it's drawn.
local MAP = { a = {}, d = {} };
local function TexArcsMapped(path, cu, cv, R, w, c, alpha, over, ra0, ra1)
	local k, line = K[path] or 1, LINE[path];
	local Map = D.Map;
	local W0, k7, k8 = Depth(cu, cv, R);
	local kk = math.sqrt(k7 * k7 + k8 * k8);
	if ( W0 + kk < WMIN ) then
		return true;
	end
	-- the part in front: either side of the nearest point, out to where it reaches WMIN
	local front = math.atan2(k8, k7);
	local reach = kk > 1e-9 and math.acos(math.max(-1, math.min(1, (WMIN - W0) / kk))) or PI;
	local t0, t1 = front - reach, front + reach;
	if ( ra0 and ra1 - ra0 < 2 * PI - 1e-6 ) then
		-- only the arc ra0..ra1 (a cone's), where it is in front
		while ( ra0 < t0 ) do
			ra0, ra1 = ra0 + 2 * PI, ra1 + 2 * PI;
		end
		while ( ra0 >= t0 + 2 * PI ) do
			ra0, ra1 = ra0 - 2 * PI, ra1 - 2 * PI;
		end
		t0, t1 = math.max(t0, ra0), math.min(t1, ra1);
		if ( t1 <= t0 ) then
			return true;
		end
	end
	local function P(th)
		return Map(cu + R * math.cos(th), cv + R * math.sin(th));
	end
	-- the points where it slopes at 45 degrees on the screen, found along it (sign changes of
	-- |dx| - |dy|), and its ends: the stretches between
	local A, Dd = MAP.a, MAP.d;
	local N = 192;
	local na = 1;
	A[1] = t0;
	local prev;
	for i = 0, N do
		local th = t0 + (t1 - t0) * i / N;
		local x1, y1 = P(th - 1e-3);
		local x2, y2 = P(th + 1e-3);
		local d = ( x1 and x2 ) and ( math.abs(x2 - x1) - math.abs(y2 - y1) ) or nil;
		if ( d and prev and ( d > 0 ) ~= ( prev > 0 ) and i > 0 ) then
			na = na + 1;
			A[na] = th - (t1 - t0) / N * d / (d - prev);
		end
		prev = d or prev;
	end
	na = na + 1;
	A[na] = t1;
	local sw, sh = LAB.sw or 1024, LAB.sh or 768;
	local h = w + 1;
	for sidx = 1, na - 1 do
		local a0, a1 = A[sidx], A[sidx + 1];
		local mid = (a0 + a1) / 2;
		local mx1, my1 = P(mid - 1e-3);
		local mx2, my2 = P(mid + 1e-3);
		if ( mx1 and mx2 ) then
			local flat = math.abs(mx2 - mx1) >= math.abs(my2 - my1);
			-- its on-screen length (only what's near the screen counts), pieces ~28 units long
			local len, px, py = 0, P(a0);
			for i = 1, 16 do
				local qx, qy = P(a0 + (a1 - a0) * i / 16);
				if ( px and qx and not ( ( px < -200 and qx < -200 ) or ( px > sw + 200 and qx > sw + 200 )
					or ( py < -200 and qy < -200 ) or ( py > sh + 200 and qy > sh + 200 ) ) ) then
					len = len + math.sqrt((qx - px) * (qx - px) + (qy - py) * (qy - py));
				end
				px, py = qx, qy;
			end
			local m = math.max(1, math.min(80, math.ceil(len / 28)));
			local xa = P(a0);
			local xb = P(a1);
			local xm = P(mid);
			-- a cut at a 45-degree point (not at an end near the horizon)
			local cutA, cutB = sidx > 1, sidx < na - 1;
			for i = 0, m - 1 do
				local th1, th2 = a0 + (a1 - a0) * i / m, a0 + (a1 - a0) * (i + 1) / m;
				local thc = (th1 + th2) / 2;
				local x1, y1 = P(th1);
				local x2, y2 = P(th2);
				local x3, y3 = P(thc);
				if ( x1 and x2 and x3 ) then
					local xl, xr, yl, yh;
					if ( flat ) then
						xl, xr = math.min(x1, x2), math.max(x1, x2);
						yl, yh = math.min(y1, y2, y3) - h, math.max(y1, y2, y3) + h;
					else
						yl, yh = math.min(y1, y2), math.max(y1, y2);
						xl, xr = math.min(x1, x2, x3) - h, math.max(x1, x2, x3) + h;
						if ( i == 0 and cutA and xa ) then
							if ( xm < xa ) then xr = math.min(xr, xa); else xl = math.max(xl, xa); end
							if ( y1 >= y2 ) then yh = yh + h; else yl = yl - h; end
						end
						if ( i == m - 1 and cutB and xb ) then
							if ( xm < xb ) then xr = math.min(xr, xb); else xl = math.max(xl, xb); end
							if ( y2 >= y1 ) then yh = yh + h; else yl = yl - h; end
						end
					end
					-- the piece's map from the camera: along (per radian) and out (per radius)
					local tx1, ty1 = P(thc - 1e-3);
					local tx2, ty2 = P(thc + 1e-3);
					local ox1, oy1 = Map(cu + R * 0.999 * math.cos(thc), cv + R * 0.999 * math.sin(thc));
					local ox2, oy2 = Map(cu + R * 1.001 * math.cos(thc), cv + R * 1.001 * math.sin(thc));
					if ( tx1 and tx2 and ox1 and ox2 ) then
						ArcPiece(path, k, line, x3, y3, (tx2 - tx1) / 2e-3, (ty2 - ty1) / 2e-3,
							(ox2 - ox1) / 2e-3, (oy2 - oy1) / 2e-3, thc, w, xl, xr, yl, yh, c, alpha, over);
					end
				end
			end
		end
	end
	return true;
end

-- The part of the line (x0, y0)-(x1, y1) inside the box xl..xr, yl..yh (Liang-Barsky), or nil.
local function ClipSegment(x0, y0, x1, y1, xl, yl, xr, yh)
	local dx, dy = x1 - x0, y1 - y0;
	local t0, t1 = 0, 1;
	local p = { -dx, dx, -dy, dy };
	local q = { x0 - xl, xr - x0, y0 - yl, yh - y0 };
	for i = 1, 4 do
		if ( p[i] == 0 ) then
			if ( q[i] < 0 ) then
				return nil;
			end
		else
			local r = q[i] / p[i];
			if ( p[i] < 0 ) then
				t0 = math.max(t0, r);
			else
				t1 = math.min(t1, r);
			end
		end
	end
	if ( t1 < t0 ) then
		return nil;
	end
	return x0 + dx * t0, y0 + dy * t0, x0 + dx * t1, y0 + dy * t1;
end

-- A straight line from screen point (x0, y0) to (x1, y1), `w` units wide, of the ring texture's line:
-- a sliver of the texture ring (a twentieth of a radian: straight to a fiftieth of its width) stretched
-- along each piece of it. Only its part on the screen, in pieces about 32 units long, cut in columns
-- (a flat line) or rows (a steep one) as the arcs are: a piece's box stays close to its line. One box
-- over a long line (a cone's side, zoomed in) took in the texture ring's far side too, which showed
-- as stray lines across the screen. Its ends are cut along it (padded across only), so two lines
-- meeting end to end don't add their light twice.
local function TexSegment(path, x0, y0, x1, y1, w, c, alpha, over)
	local sw, sh = LAB.sw or 1024, LAB.sh or 768;
	x0, y0, x1, y1 = ClipSegment(x0, y0, x1, y1, -60, -60, sw + 60, sh + 60);
	if ( not x0 ) then
		return;
	end
	local dx, dy = x1 - x0, y1 - y0;
	local len = math.sqrt(dx * dx + dy * dy);
	if ( len < 0.5 or alpha <= 0.003 ) then
		return;
	end
	local h, d = w + 1, 0.05;
	local ux, uy = dx / len, dy / len;
	local flat = math.abs(dx) >= math.abs(dy);
	local n = math.max(1, math.min(80, math.ceil(len / 32)));
	local pl = len / n;
	for i = 0, n - 1 do
		local ax, ay = x0 + dx * i / n, y0 + dy * i / n;
		local bx, by = x0 + dx * (i + 1) / n, y0 + dy * (i + 1) / n;
		local xl, xr, yl, yh;
		if ( flat ) then
			xl, xr = math.min(ax, bx), math.max(ax, bx);
			yl, yh = math.min(ay, by) - h, math.max(ay, by) + h;
		else
			yl, yh = math.min(ay, by), math.max(ay, by);
			xl, xr = math.min(ax, bx) - h, math.max(ax, bx) + h;
		end
		-- along: the sliver's d radians over this piece; across: one unit (ArcPiece squeezes it to w)
		ArcPiece(path, K[path] or 1, LINE[path], (ax + bx) / 2, (ay + by) / 2, ux * pl / d, uy * pl / d, -uy, ux, 0, w,
			xl, xr, yl, yh, c, alpha, over);
	end
end

-- A cone in texture: Core's own fill and the faint area still to fill (a texture can't be cut to
-- a cone), then its edge (the arc and both sides), its glow (the same, wider and fainter) and its
-- fill's front line in the ring texture's line; each part as its settings have it.
local function TexCone(j)
	local st = Real(j.st);
	-- Core's fill only: its outline, glow and front line are drawn here
	local px = X.coneProxy;
	if ( not px ) then
		px = { lineOn = false, glow = false, frontOn = false };
		setmetatable(px, { __index = function(t, k) return t.real[k]; end });
		X.coneProxy = px;
	end
	px.real = st;
	local real = j.st;
	j.st = px;
	D.Cone(j);
	j.st = real;
	local L, h = j.size, j.def.halfAngle * PI / 180;
	local a0, a1 = j.facing - h, j.facing + h;
	local pulse = 0;
	if ( st.pulseOn ~= false and j.since and j.since < 0.35 ) then
		pulse = 1 - j.since / 0.35;
	end
	local alpha = j.alpha * (1 + pulse * 0.6);
	local Map = D.Map;
	local xo, yo = Map(0, 0);
	local xa, ya = Map(L * math.cos(a0), L * math.sin(a0));
	local xb, yb = Map(L * math.cos(a1), L * math.sin(a1));
	local function Edge(w, c, al)
		TexArcsMapped(T.circle, 0, 0, L, w, c, al, nil, a0, a1);
		if ( xo and xa ) then
			TexSegment(T.circle, xo, yo, xa, ya, w, c, al);
		end
		if ( xo and xb ) then
			TexSegment(T.circle, xo, yo, xb, yb, w, c, al);
		end
	end
	if ( st.glow ) then
		Edge(st.width * 3, st.line, alpha * 0.3);
	end
	if ( st.lineOn ~= false ) then
		Edge(st.width, st.line, alpha);
	end
	local p = j.progress;
	if ( st.frontOn ~= false and p and p > 0.02 and p < 1 ) then
		TexArcsMapped(T.circle, 0, 0, L * p, st.width, Bright(st.fill), j.alpha, nil, a0, a1);
	end
	return true;
end

-- A ring R round (cu, cv) of the game's fine ring texture: one piece, or (a small ring, whose
-- texture line is thinner than `w` units) up to three side by side, or (a big one, whose line would
-- be thicker) arc pieces; with a soft glow under it. False when it can't be laid (Core's own then).
local function TexRing(cu, cv, R, c, alpha, w, glow, over, noLine)
	local W0, k7, k8 = Depth(cu, cv, R);
	if ( W0 - math.sqrt(k7 * k7 + k8 * k8) < WMIN ) then
		-- reaching past the horizon: its part in front, point by point
		if ( not CanAdd() ) then
			return false;
		end
		return noLine or TexArcsMapped(T.circle, cu, cv, R, w, c, alpha, over);
	end
	local ex, ey, ax, ay, bx, by = Fit(cu, cv, R, 0);
	if ( not ex ) then
		return false;
	end
	local rpx = math.sqrt(math.abs(ax * by - ay * bx));
	local lw = LINE[T.circle] * rpx;
	if ( lw > 1.3 * w ) then
		if ( not CanAdd() ) then
			return false;
		end
		if ( not noLine ) then
			TexArcs(T.circle, ex, ey, ax, ay, bx, by, lw, w, c, alpha, over);
		end
		if ( glow and rpx < 420 ) then
			LayRing(T.soft, ex, ey, ax, ay, bx, by, 1, c, alpha * 0.3 * math.min(1, (420 - rpx) / 200), over);
		end
		return true;
	end
	local n = math.max(1, math.min(3, math.ceil(w / math.max(0.5, lw) - 0.25)));
	-- a big ring's line is thicker than asked: fainter, so it isn't heavier than a small one
	local a = alpha * math.min(1, 0.4 + 0.6 * w / math.max(w, lw));
	for i = 1, ( noLine and 0 or n ) do
		LayRing(T.circle, ex, ey, ax, ay, bx, by, 1 + (i - (n + 1) / 2) * w / n / rpx, c, a, over);
	end
	if ( glow and rpx < 420 ) then
		LayRing(T.soft, ex, ey, ax, ay, bx, by, 1, c, alpha * 0.3 * math.min(1, (420 - rpx) / 200), over);
	end
	return true;
end

-- A ring (cooldown, cast or always shown) drawn with textures: Core's DrawCircleAt, in pieces of
-- texture.
local function TexCircle(cu, cv, R, st, alpha, p, since, over)
	-- each part only when its setting has it (Core's own as DrawCircleAt has them)
	local pulsing, line = st.pulseOn ~= false, st.lineOn ~= false;
	local pulse = 0;
	if ( pulsing and since and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	if ( ( line or st.glow ) and not TexRing(cu, cv, R, st.line, alpha * (1 + pulse * 0.6), st.width, st.glow, over, not line) ) then
		return false;
	end
	GlowFill(cu, cv, R, st, alpha, p, pulsing and since or nil, over);
	if ( st.frontOn ~= false and p and p > 0.02 and p < 1 ) then
		TexRing(cu, cv, R * p, Bright(st.fill), alpha, st.width, false, over);
	end
	if ( pulsing and since and since < 0.4 ) then
		TexRing(cu, cv, R * (0.3 + 0.7 * since / 0.4), Bright(st.line), alpha * (1 - since / 0.4), st.width * 1.5, false, over);
	end
	return true;
end

local function TexSpot(j, cu, cv, R, alpha, grow, age, now, around, running)
	local st = Real(j.st);
	if ( running ) then
		local line = st.lineOn ~= false;
		if ( ( line or st.glow ) and not TexRing(cu, cv, R, st.line, alpha, st.width, st.glow, nil, not line) ) then
			D.Circle(cu, cv, R, st, alpha, nil, nil);
			return;
		end
		GlowFill(cu, cv, R, st, alpha * (0.8 + 0.2 * math.sin(now * 2 * PI / 3)), nil, nil);
	elseif ( not TexCircle(cu, cv, R, st, alpha, grow, around and age or nil) ) then
		-- the texture can't be laid here: Core's own spot (its pieces were made see-through)
		D.Spot(cu, cv, R, st, alpha, grow or 1);
	end
end

-- An enemy effect's ring as Core draws it (growing to its size as it fades), in texture.
local function TexBurst(j, cu, cv, R, age, now)
	local st = Real(j.st);
	local flash = st.flash or 0.6;
	local r, a = R * (0.6 + 0.4 * age / flash), j.alpha * (1 - age / flash);
	if ( not TexCircle(cu, cv, r, st, a, nil, nil) ) then
		D.Circle(cu, cv, r, st, a, nil, nil);
	end
end

AST_Lab{
	-- the standard look on this branch (the user, 2026-11-24: "replace the old circles with textures")
	id = "lab_texrings", name = "Texture rings", kind = "Textures", startOn = true, hidden = true,
	desc = "Rings and cones from the game's own fine ring texture: smooth, glowing, sharp at any size.",
	applies = "Every ring and cone in the Texture style: round you, your own, ground spots, enemies, downed.",
	fits = function(j)
		local s = j.def.shape;
		return ( s == "circle" or s == "cone" or s == "ground" or s == "enemy" or s == "downed" ) and Real(j.st).style == "texture" and CanAdd();
	end,
	pre = function(j, p, now)
		if ( j.def.shape == "ground" ) then
			-- Core goes on placing and timing the spots; its pieces go
			Proxy(j, 0, 0);
		end
	end,
	draw = function(j, p, now)
		local shape = j.def.shape;
		if ( shape == "enemy" ) then
			-- Core's rings go: clear the old ones as it would (over 2 sec), then each in texture
			local rings = D.Rings();
			for k = table.getn(rings), 1, -1 do
				if ( now - rings[k].at > 2 ) then
					table.remove(rings, k);
				end
			end
			EachRing(j, p, now, TexBurst);
			return true;
		elseif ( shape == "downed" ) then
			-- around each downed teammate, at the height they lie at, filling as you revive them
			local st = Real(j.st);
			for i = 1, table.getn(j.downed or {}) do
				local d = j.downed[i];
				local cu, cv = d.x, d.y;
				if ( not d.rel ) then
					cu, cv = d.x - p.x, d.y - p.y;
					D.H.dz = d.z and d.z - p.z or 0;
				end
				if ( not TexCircle(cu, cv, j.size, st, j.alpha, d.progress, nil) ) then
					D.Circle(cu, cv, j.size, st, j.alpha, d.progress, nil);
				end
				D.H.dz = 0;
			end
			return true;
		elseif ( shape == "cone" ) then
			return TexCone(j);
		elseif ( shape ~= "circle" ) then
			return false;
		end
		return TexCircle(0, 0, j.size, Real(j.st), j.alpha, j.progress, j.since);
	end,
	post = function(j, p, now)
		if ( j.def.shape == "ground" ) then
			EachSpot(j, p, now, TexSpot);
		end
	end,
	demo = function(t, j, p, now)
		local k = t - math.floor(t / 1.5) * 1.5;
		TexCircle(0, 0, 8, GOLD, j.alpha, k / 1.5, k);
		TexCircle(0, 0, 25, FROST, j.alpha * 0.8, nil, nil);
		for i = 1, 3 do
			local a = i * 2.1 + t * 0.2;
			TexCircle(14 * math.cos(a), 14 * math.sin(a), 3 + i, SHADOW, j.alpha, nil, nil);
		end
		TexCircle(12, -7, 5, FIRE, j.alpha, math.min(1, t / 3), nil);
	end,
};

---------------------------------------------------------------------------------------------
-- 3. Real rune circle: the game's rune art under the spots

local function RuneAt(cu, cv, R, st, alpha, age, now, seed)
	-- it opens out as the spot lands, turns slowly (one turn in 20 sec), and goes with the spot
	local open = Ease(math.min(1, age / 0.6));
	local r = R * (0.8 + 0.2 * open);
	local turn = now * 2 * PI / 20 + seed;
	Ground(T.rune, cu, cv, r, turn, st.line, alpha * 0.85 * open, "BLEND");
	-- a ring of runes inside, turning the other way
	Ground(T.runes, cu, cv, r * 0.66, -turn * 1.6, st.line, alpha * 0.55 * open, "ADD");
end

local function RuneSpot(j, cu, cv, R, alpha, grow, age, now, around, running)
	RuneAt(cu, cv, R, Real(j.st), alpha, age or 1, now, around and 0 or (now - (age or 0)) * 0.7);
end

AST_Lab{
	id = "lab_runetex", name = "Real rune circle", kind = "Textures",
	desc = "A rune circle from the game's own art under each ground spot, slowly turning.",
	applies = "Ground spots, and the ring round you of a spell that moves with you.",
	fits = function(j)
		return j.def.shape == "ground";
	end,
	post = function(j, p, now)
		EachSpot(j, p, now, RuneSpot);
	end,
	demo = function(t, j, p, now)
		local grow = math.min(1, t / 3);
		RuneAt(7, 4, 6, GOLD, j.alpha, t, now, 0);
		D.Spot(7, 4, 6, GOLD, j.alpha, grow);
		RuneAt(-6, -9, 8, FROST, j.alpha, math.max(0, t - 0.8), now, 2);
		if ( t > 0.8 ) then
			D.Spot(-6, -9, 8, FROST, j.alpha, math.min(1, (t - 0.8) / 2.2));
		end
	end,
};

---------------------------------------------------------------------------------------------
-- 4. Light, not paint: additive glow along the outlines and a bloom on each cast

-- A soft halo along a ring, and a bloom that swells out from the middle for half a second after
-- `since` (a cast, a landing, a burst).
local function Halo(cu, cv, R, st, alpha, p, since)
	local ex, ey, ax, ay, bx, by = Fit(cu, cv, R, 0);
	if ( not ex ) then
		return;
	end
	local rpx = math.sqrt(math.abs(ax * by - ay * bx));
	-- the glow either side of the line: thinner rings for bigger ones
	local big = math.min(1, math.max(0, (rpx - 250) / 350));
	LayRing(T.soft, ex, ey, ax, ay, bx, by, 1, st.line, alpha * (0.75 - 0.45 * big), true);
	LayRing(T.fat, ex, ey, ax, ay, bx, by, 1, st.line, alpha * 0.16 * (1 - big), true);
	if ( p and p > 0.05 and p < 1 ) then
		Ground(T.soft, cu, cv, R * p, 0, Bright(st.fill), alpha * 0.5, "ADD", true);
	end
	if ( since and since < 0.5 ) then
		local x = since / 0.5;
		Ground(T.blob, cu, cv, R * (0.35 + 0.75 * Ease(x)), 0, Bright(st.line), alpha * 0.9 * (1 - x) * (1 - x), "ADD", true);
	end
end

local function HaloSpot(j, cu, cv, R, alpha, grow, age, now, around, running)
	Halo(cu, cv, R, Real(j.st), alpha, not running and grow or nil, age);
end

local function HaloRing(j, cu, cv, R, age, now)
	local st = Real(j.st);
	local flash = st.flash or 0.6;
	local x = age / flash;
	Halo(cu, cv, R * (0.6 + 0.4 * x), st, (1 - x) * j.alpha, nil, age);
end

-- A cone's outline as glowing light: soft streaks along its sides and its arc.
local function HaloCone(j, st, alpha)
	local L, h = j.size, j.def.halfAngle * PI / 180;
	local w = D.Scale() * 0.45;
	local c = st.line;
	local pulse = 0;
	if ( j.since and j.since < 0.5 ) then
		pulse = (1 - j.since / 0.5) * (1 - j.since / 0.5);
	end
	local a = alpha * (0.45 + 0.8 * pulse);
	local x0, y0 = D.Map(0, 0);
	local xa, ya = D.Map(L * math.cos(j.facing - h), L * math.sin(j.facing - h));
	local xz, yz = D.Map(L * math.cos(j.facing + h), L * math.sin(j.facing + h));
	Streak(T.disc, x0, y0, xa, ya, w, c, a, "ADD", true);
	Streak(T.disc, x0, y0, xz, yz, w, c, a, "ADD", true);
	local n = math.max(2, math.ceil(2 * h / (PI / 12)));
	for i = 1, n do
		local ang = j.facing - h + 2 * h * i / n;
		local xb, yb = D.Map(L * math.cos(ang), L * math.sin(ang));
		Streak(T.blob, xa, ya, xb, yb, w * 1.3, c, a * 0.8, "ADD", true, 1.7);
		xa, ya = xb, yb;
	end
	if ( pulse > 0 ) then
		-- the cast: light down the middle of the cone
		local xm, ym = D.Map(L * 0.9 * math.cos(j.facing), L * 0.9 * math.sin(j.facing));
		Streak(T.blob, x0, y0, xm, ym, D.Scale() * L * math.sin(h) * 0.5, Bright(c), alpha * 0.6 * pulse, "ADD", true);
	end
end

AST_Lab{
	id = "lab_additive", name = "Light, not paint", kind = "Textures",
	desc = "Outlines glow with added light, and each cast blooms bright, so telegraphs look lit.",
	applies = "Rings, cones, ground spots and effects on enemies (over what they draw).",
	fits = function(j)
		local s = j.def.shape;
		return ( s == "circle" or s == "cone" or s == "ground" or s == "enemy" ) and CanAdd();
	end,
	post = function(j, p, now)
		local s, st = j.def.shape, Real(j.st);
		if ( s == "circle" ) then
			Halo(0, 0, j.size, st, j.alpha, j.progress, j.since);
		elseif ( s == "cone" ) then
			HaloCone(j, st, j.alpha);
		elseif ( s == "ground" ) then
			EachSpot(j, p, now, HaloSpot);
		elseif ( s == "enemy" ) then
			EachRing(j, p, now, HaloRing);
		end
	end,
	demo = function(t, j, p, now)
		local k = t - math.floor(t / 1.5) * 1.5;
		D.Circle(0, 0, 8, GOLD, j.alpha, k / 1.5, k);
		Halo(0, 0, 8, GOLD, j.alpha, k / 1.5, k);
		local cone = X.acone or { def = { shape = "cone", halfAngle = 30 }, st = SHADOW };
		X.acone = cone;
		cone.size, cone.facing, cone.alpha, cone.progress = 14, 2.5, j.alpha, nil;
		cone.since = t - math.floor(t / 1.5) * 1.5 - 0.2;
		if ( cone.since < 0 ) then
			cone.since = nil;
		end
		D.Cone(cone);
		HaloCone(cone, SHADOW, j.alpha);
		for i = 0, 2 do
			local age = t - i * 0.8;
			if ( age >= 0 and age < 0.6 ) then
				local a = i * 2.1 + 0.6;
				local x = age / 0.6;
				D.Circle(13 * math.cos(a), 13 * math.sin(a), 5 * (0.6 + 0.4 * x), FIRE, j.alpha * (1 - x));
				Halo(13 * math.cos(a), 13 * math.sin(a), 5 * (0.6 + 0.4 * x), FIRE, j.alpha * (1 - x), nil, age);
			end
		end
	end,
};

---------------------------------------------------------------------------------------------
-- 5. Moving fills: a turning swirl or a drifting cloud inside each ground spot

-- The ground spells whose fill swirls (frost, wind, arrows); the rest (fire, poison, holy) drift
-- as clouds.
local SWIRLS = { blizzard = true, hurricane = true, volley = true, frost_trap = true };

local function Swirl(cu, cv, R, st, alpha, now, seed)
	local f = st.fill;
	-- (the tint's own opacity: the fill's, raised, as the swirl's art is faint)
	local a = alpha * math.min(1, f[4] * 3.5) / math.max(0.01, f[4]);
	local turn = now * 2 * PI / 6 + seed;
	Ground(T.swirl, cu, cv, R, turn, f, a, "BLEND");
	Ground(T.swirl, cu, cv, R * 0.72, turn * 1.6 + 1, st.line, alpha * 0.7, "BLEND");
	if ( CanAdd() ) then
		-- a little light in it
		Ground(T.swirl, cu, cv, R * 0.9, turn * 1.3 + 2, st.line, alpha * 0.35, "ADD");
	end
end

-- Three puffs of cloud, each drifting across the spot as it fades in and out (4 sec each, a third
-- of that apart), never past its edge.
local function Cloud(cu, cv, R, st, alpha, now, seed)
	local f = st.fill;
	local a = alpha * math.min(0.55, f[4] * 1.8) / math.max(0.01, f[4]);
	for i = 0, 2 do
		local t = now / 4 + i / 3 + seed;
		local n = math.floor(t);
		local x = t - n;
		local env = math.sin(x * PI);
		local dir = n * 2.4 + i * 2.1;
		-- across from one side to the other, slightly curved
		local d = R * 0.32 * (2 * x - 1);
		local side = R * 0.12 * math.sin(n * 1.7 + i);
		local u = cu + d * math.cos(dir) - side * math.sin(dir);
		local v = cv + d * math.sin(dir) + side * math.cos(dir);
		Ground(T.cloud, u, v, R * 0.62, dir + x * 0.8, f, a * env, "BLEND");
		if ( i == 0 and CanAdd() ) then
			Ground(T.cloud, u, v, R * 0.5, dir + x * 0.8, st.line, alpha * 0.25 * env, "ADD");
		end
	end
end

local function MovingSpot(j, cu, cv, R, alpha, grow, age, now, around, running)
	local st = Real(j.st);
	-- (from when it landed: the same for a spot all its life)
	local seed = (now - (age or 0)) * 0.7;
	-- it fades in as the spot lands
	alpha = alpha * Ease(math.min(1, (age or 1) / 0.5));
	if ( SWIRLS[j.def.id] ) then
		Swirl(cu, cv, R, st, alpha, now, seed);
	else
		Cloud(cu, cv, R, st, alpha, now, seed);
	end
end

AST_Lab{
	id = "lab_swirl", name = "Moving fills", kind = "Textures",
	desc = "Ground spells fill with motion: a turning swirl for frost and wind, drifting cloud for fire.",
	applies = "Ground spots: Blizzard, Hurricane, Volley, Frost Trap swirl; the rest drift as cloud.",
	fits = function(j)
		return j.def.shape == "ground" and Real(j.st).fill[4] > 0.003;
	end,
	pre = function(j, p, now)
		if ( Real(j.st).style ~= "dots" ) then
			-- Core's flat fill faint, so the motion shows through (its time still fills)
			Proxy(j, 0.35, 1);
		end
	end,
	post = function(j, p, now)
		EachSpot(j, p, now, MovingSpot);
	end,
	demo = function(t, j, p, now)
		local grow = math.min(1, t / 3);
		Swirl(7, 5, 7, FROST, j.alpha * Ease(math.min(1, t / 0.5)), now, 0);
		D.Spot(7, 5, 7, Bare(FROST), j.alpha, grow);
		Cloud(-5, -10, 6, FIRE, j.alpha * Ease(math.min(1, t / 0.5)), now, 0.5);
		D.Spot(-5, -10, 6, Bare(FIRE), j.alpha, grow);
	end,
};

---------------------------------------------------------------------------------------------
-- 6. Flashes and wave fronts: a star flash on each cast and burst, a wave of light running out

-- A star flash at the ground point (cu, cv), `size` yd across, `age` sec in (gone at 0.3 sec).
local function Star(cu, cv, size, c, alpha, age)
	if ( age < 0 or age >= 0.3 ) then
		return;
	end
	local x, y, s = ScreenAt(cu, cv);
	if ( not x ) then
		return;
	end
	local k = age / 0.3;
	local w = size * s * (0.5 + 0.7 * Ease(math.min(1, k * 2.5)));
	LAB.Screen(T.star, x, y, w, w, c, alpha * (1 - k) * (1 - k) * 1.4, CanAdd() and "ADD" or "BLEND", true);
	LAB.Screen(T.star, x, y, w * 0.45, w * 0.45, { 1, 1, 1, 1 }, alpha * (1 - k), CanAdd() and "ADD" or "BLEND", true);
end

-- A wave of light running out from (cu, cv) to R over half a second.
local function Wave(cu, cv, R, c, alpha, age)
	if ( age < 0 or age >= 0.5 ) then
		return;
	end
	local k = age / 0.5;
	local r = R * (0.25 + 0.85 * Ease(k));
	Ground(T.fat, cu, cv, r, 0, c, alpha * (1 - k) * 0.9, "ADD", true);
	Ground(T.soft, cu, cv, r, 0, Bright(c), alpha * (1 - k), "ADD", true);
end

local function FlashRing(j, cu, cv, R, age, now)
	local st = Real(j.st);
	Star(cu, cv, R * 0.9, Bright(st.line), j.alpha, age);
	Wave(cu, cv, R * 1.05, st.line, j.alpha, age);
end

AST_Lab{
	id = "lab_flash", name = "Flashes and wave fronts", kind = "Textures",
	desc = "A star flashes on each cast and burst, and a wave of light runs out to the edge.",
	applies = "Rings round you on each cast or proc, and effects on enemies where they go off.",
	fits = function(j)
		local s = j.def.shape;
		return s == "circle" or s == "enemy";
	end,
	post = function(j, p, now)
		local st = Real(j.st);
		if ( j.def.shape == "circle" ) then
			if ( j.since ) then
				Star(0, 0, math.min(j.size, 10) * 0.9, Bright(st.line), j.alpha, j.since);
				Wave(0, 0, j.size, st.line, j.alpha, j.since);
			end
		else
			EachRing(j, p, now, FlashRing);
		end
	end,
	demo = function(t, j, p, now)
		local k = t - math.floor(t / 1.5) * 1.5;
		D.Circle(0, 0, 8, GOLD, j.alpha, nil, k);
		Star(0, 0, 8 * 0.9, Bright(GOLD.line), j.alpha, k);
		Wave(0, 0, 8, GOLD.line, j.alpha, k);
		for i = 0, 2 do
			local age = t - i * 0.8 - 0.3;
			if ( age >= 0 and age < 0.6 ) then
				local a = i * 2.1 + 0.6;
				local x = age / 0.6;
				local cu, cv = 13 * math.cos(a), 13 * math.sin(a);
				D.Circle(cu, cv, 6 * (0.6 + 0.4 * x), FIRE, j.alpha * (1 - x));
				Star(cu, cv, 6 * 0.9, Bright(FIRE.line), j.alpha, age);
				Wave(cu, cv, 6.3, FIRE.line, j.alpha, age);
			end
		end
	end,
};

---------------------------------------------------------------------------------------------
-- /ast lab textest: every texture above, drawn both ways, and what the client does with texture
-- coordinates outside 0..1 and with eight of them.

local TEST_LIST = { T.mask, T.disc, T.blob, T.soft, T.faded, T.thin, T.fat, T.ping, T.circle, T.rune, T.runes,
	T.swirl, T.cloud, T.star };

local function TestFrame()
	local f = X.test;
	if ( f ) then
		return f;
	end
	local cols, cell, pad = 5, 56, 6;
	local cw = 2 * cell + 3 * pad;
	local rows = math.ceil(table.getn(TEST_LIST) / cols);
	f = CreateFrame("Frame", "ASTLabTexTest", UIParent);
	f:SetFrameStrata("HIGH");
	f:SetWidth(cols * cw + 2 * pad);
	f:SetHeight(rows * (cell + 22) + cell * 2 + 60);
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40);
	f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	f:SetBackdropColor(0.32, 0.32, 0.34, 0.97);
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	title:SetPoint("TOP", f, "TOP", 0, -8);
	title:SetText("Lab texture test: each one blended (left) and added as light (right)");
	f.cells = {};
	for i = 1, table.getn(TEST_LIST) do
		local path = TEST_LIST[i];
		local col, row = i - 1 - math.floor((i - 1) / cols) * cols, math.floor((i - 1) / cols);
		local x, y = pad + col * cw + pad, -28 - row * (cell + 22);
		local pair = {};
		for k = 1, 2 do
			local t = f:CreateTexture(nil, "ARTWORK");
			t:SetTexture(path);
			t:SetWidth(cell);
			t:SetHeight(cell);
			t:SetPoint("TOPLEFT", f, "TOPLEFT", x + (k - 1) * (cell + pad), y);
			if ( t.SetBlendMode ) then
				t:SetBlendMode(k == 1 and "BLEND" or "ADD");
			end
			pair[k] = t;
		end
		local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		label:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - cell - 2);
		label:SetWidth(2 * cell + pad);
		local _, _, short = string.find(path, "([^\\]+)$");
		label:SetText(short or path);
		f.cells[i] = pair;
	end
	-- the probes: texture coordinates -0.5..1.5 (one picture in the middle, its edges smeared out:
	-- clamp; whole pictures repeated round it: repeat), and eight coordinates turning a rune
	local y = -28 - rows * (cell + 22) - 6;
	local probes = { { T.soft, "ring, -0.5..1.5" }, { T.mask, "disc, -0.5..1.5" }, { T.rune, "8 numbers, turning" } };
	f.probes = {};
	for i = 1, 3 do
		local t = f:CreateTexture(nil, "ARTWORK");
		t:SetTexture(probes[i][1]);
		t:SetWidth(cell * 2);
		t:SetHeight(cell * 2);
		t:SetPoint("TOPLEFT", f, "TOPLEFT", pad + (i - 1) * (cell * 2 + 40) + 40, y);
		if ( i < 3 ) then
			t:SetTexCoord(-0.5, 1.5, -0.5, 1.5);
		end
		local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		label:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2);
		label:SetText(probes[i][2]);
		f.probes[i] = t;
		f.probeLabel = label;
	end
	f:SetScript("OnUpdate", function()
		local left = (f.untilAt or 0) - GetTime();
		if ( left <= 0 ) then
			f:Hide();
			return;
		end
		-- the turning probe: the rune's corners turned about its middle (a square half its width
		-- turned: the corners at 0.5 +- (c -+ s) / 2)
		local a = GetTime() * 2 * PI / 6;
		local c, s = math.cos(a) * 0.5, math.sin(a) * 0.5;
		local ok = pcall(f.probes[3].SetTexCoord, f.probes[3], 0.5 - c + s, 0.5 - s - c, 0.5 - c - s, 0.5 - s + c,
			0.5 + c + s, 0.5 + s - c, 0.5 + c - s, 0.5 + s + c);
		if ( not ok and not f.failed ) then
			f.failed = true;
			f.probeLabel:SetText("8 numbers: not taken here");
		end
	end);
	X.test = f;
	return f;
end

LAB.commands.textest = function(args)
	local f = TestFrame();
	if ( f:IsShown() and (f.untilAt or 0) > GetTime() ) then
		f.untilAt = 0;
		f:Hide();
		return;
	end
	f.untilAt = GetTime() + 15;
	f:Show();
	local say = DEFAULT_CHAT_FRAME;
	say:AddMessage("|cffb080ffAS Telegraphs|r: Lab texture test, 15 sec (/ast lab textest again closes it). Each texture is drawn twice: left blended, right added as light. "
		.. "Black squares = no alpha, needs ADD; nothing at all = the path didn't load. Bottom: the ring and disc drawn with coordinates -0.5..1.5 "
		.. "(repeated rings = repeat; one in the middle with a smeared edge = clamp), and a rune that should turn. Please report what you see.");
	say:AddMessage("|cffb080ffAS Telegraphs|r: blend modes " .. (CanAdd() and "can" or "can't") .. " be set on textures here.");
end

-- An arc a0..a1 of a ring R round (cu, cv) (at the height H.dz), `w` units wide, in the ring
-- texture's line: thin lines are cheaper so than in Core's pieces. False where light can't be added.
LAB.tex.Arc = function(cu, cv, R, w, c, alpha, a0, a1)
	if ( not CanAdd() ) then
		return false;
	end
	return TexArcsMapped(T.circle, cu, cv, R, w, c, alpha, nil, a0, a1);
end

-- A whole ring round (cu, cv) as the texture rings draw one (its settings' parts, `p` a fill from
-- the centre, `since` a cast's pulse): for other files' rings (a guardian's). False where it can't.
LAB.tex.Circle = function(cu, cv, R, st, alpha, p, since)
	if ( not CanAdd() ) then
		return false;
	end
	return TexCircle(cu, cv, R, st, alpha, p, since);
end

-- A cone job (its st, size, facing, progress, since, alpha, def.halfAngle) as the texture cones draw
-- one; the game's textures laid on the ground (Ground(T.rune, ...): R is where its ring or glow's
-- edge lies); a ring of the fine ring texture: for the showcase. False / nil where they can't be.
LAB.tex.Cone = function(j)
	if ( not CanAdd() ) then
		return false;
	end
	return TexCone(j);
end
LAB.tex.T = T;
LAB.tex.Ground = Ground;
LAB.tex.Ring = function(cu, cv, R, c, alpha, w, glow)
	if ( not CanAdd() ) then
		return false;
	end
	return TexRing(cu, cv, R, c, alpha, w, glow);
end
