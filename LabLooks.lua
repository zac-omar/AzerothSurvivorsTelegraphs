-- Azeroth Survivors Telegraphs: Lab experiments (LabLooks). See Lab.lua.
-- Polish: Rim light, Contrast underline, Eased motion. Time: Ready ping, Sweep fill, Countdown pips.
-- They draw with Core's own pieces (AST.draw): its fills and strokes, so True circles smooths them
-- too; and a wide soft band of light is a ring of big round pieces, each the patch of ground it
-- covers (so it shrinks with distance as the ground does), a quarter of their size apart: eight
-- overlap anywhere along it, so their edges fade it out smoothly, and there are few of them
-- however big the ring (about a hundred).

local K = { ready = {}, pips = {}, proxies = {}, demos = {}, cj = {} };
local PI = 3.14159265;

-- Colours made in place, so drawing makes no new tables
K.c1, K.c2, K.c3, K.c4 = { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, { 1, 1, 1, 1 };
K.INK = { 0.03, 0.025, 0.02, 1 };
K.WHITE = { 1, 1, 1, 1 };
K.GOLD_LINE, K.GOLD_FILL = { 1, 0.85, 0.35, 1 }, { 1, 0.8, 0.3, 0.3 };
K.VIOLET_LINE, K.VIOLET_FILL = { 0.75, 0.45, 1, 1 }, { 0.55, 0.25, 0.95, 0.3 };
K.EMBER_LINE, K.EMBER_FILL = { 1, 0.45, 0.2, 1 }, { 1, 0.35, 0.1, 0.25 };
K.DEMO_CONE = { id = "demo_cone", halfAngle = 60 };

-- An ease-out: fast, then settling (k: its power)
function K.EaseOut(x, k)
	x = math.max(0, math.min(1, x));
	return 1 - math.pow(1 - x, k or 3);
end

-- `c` moved `f` of the way to white, into `t`
function K.Whiter(t, c, f)
	t[1], t[2], t[3], t[4] = c[1] + (1 - c[1]) * f, c[2] + (1 - c[2]) * f, c[3] + (1 - c[3]) * f, 1;
	return t;
end

-- Core's bright version of a colour (its fill's front, its shockwave), into `t`
function K.Bright(t, c)
	return K.Whiter(t, c, 0.6);
end

-- `c` at half its saturation and 70% of its brightness, mixed `k` of the way back to itself
function K.Dim(t, c, k)
	local l = 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3];
	for i = 1, 3 do
		local d = (l + (c[i] - l) * 0.5) * 0.7;
		t[i] = d + (c[i] - d) * k;
	end
	t[4] = c[4];
	return t;
end

-- Screen units per yard at (cu, cv) (at the height being drawn at)
function K.LocalScale(cu, cv)
	local Map = AST.draw.Map;
	local x0, y0 = Map(cu, cv);
	local x1, y1 = Map(cu + 1, cv);
	local x2, y2 = Map(cu, cv + 1);
	if ( not ( x0 and x1 and x2 ) ) then
		return AST.draw.Scale();
	end
	return (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
		+ math.sqrt((x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0))) / 2;
end

-- The ground step from (cu, cv) that shows one screen unit lower
function K.Down(cu, cv)
	local D = AST.draw;
	local x, y = D.Map(cu, cv);
	if ( not x ) then
		return 0, 0;
	end
	local u, v = D.Unmap(x, y - 1, D.H.dz);
	if ( not u ) then
		return 0, 0;
	end
	return u - cu, v - cv;
end

-- The ground angle from (cu, cv) that points straight up the screen (12 o'clock as you see it),
-- and which way a growing angle turns on the screen: 1 if clockwise, -1 if not
function K.Clock(cu, cv)
	local D = AST.draw;
	local x0, y0 = D.Map(cu, cv);
	if ( not x0 ) then
		return PI / 2, -1;
	end
	local u, v = D.Unmap(x0, y0 + 10, D.H.dz);
	if ( not u ) then
		return PI / 2, -1;
	end
	local up = math.atan2(v - cv, u - cu);
	local xa, ya = D.Map(cu + math.cos(up), cv + math.sin(up));
	local xb, yb = D.Map(cu + math.cos(up + 0.2), cv + math.sin(up + 0.2));
	if ( not ( xa and xb ) ) then
		return up, -1;
	end
	if ( (xa - x0) * (yb - y0) - (ya - y0) * (xb - x0) < 0 ) then
		return up, 1;
	end
	return up, -1;
end

-- Is a Test press of this telegraph playing?
function K.Testing(def)
	local t = AST.preview[def.id];
	return t ~= nil and GetTime() < t;
end

---------------------------------------------------------------------------------------------
-- Soft bands: round pieces the size of a patch of ground `rho` yd round (an upright ellipse on the
-- screen, as it shows)

function K.Piece(u, v, rho, c, alpha)
	local D = AST.draw;
	local x0, y0 = D.Map(u, v);
	local x1, y1 = D.Map(u + rho, v);
	local x2, y2 = D.Map(u, v + rho);
	if ( not ( x0 and x1 and x2 ) ) then
		return;
	end
	local ax, ay, bx, by = x1 - x0, y1 - y0, x2 - x0, y2 - y0;
	local hx, hy = math.sqrt(ax * ax + bx * bx), math.sqrt(ay * ay + by * by);
	D.Quad(D.ROUND, x0 - hx, y0 - hy, 2 * hx, 2 * hy, c, alpha);
end

-- A soft band along the arc a0..a1 of the ring `rc` yd round (cu, cv), `rho` yd either side of
-- it, brightest along it (about `alpha` there, times the colour's own) and fading to nothing at
-- its edges: pieces `rho` yd round, a quarter of that apart
function K.SoftArc(cu, cv, rc, a0, a1, rho, c, alpha, most)
	if ( rho <= 0 or rc <= 0 or alpha * c[4] <= 0.003 ) then
		return;
	end
	local gap = 0.25;
	most = most or 160;
	local n = math.ceil(rc * math.abs(a1 - a0) / (gap * rho));
	if ( n < 1 ) then
		n = 1;
	elseif ( n > most ) then
		n = most;
		gap = rc * math.abs(a1 - a0) / (n * rho);
	end
	local per = 1 - math.pow(1 - math.min(alpha, 0.95), math.min(1, gap / 2));
	local first = 0;
	if ( math.abs(math.abs(a1 - a0) - 2 * PI) < 1e-3 ) then
		first = 1;
	end
	for i = first, n do
		local a = a0 + (a1 - a0) * i / n;
		K.Piece(cu + rc * math.cos(a), cv + rc * math.sin(a), rho, c, per);
	end
end

---------------------------------------------------------------------------------------------
-- Core's pieces, put together

-- A ring `r` yd round (cu, cv) (or its arc a0..a1), stroked with Core's own line
function K.Ring(cu, cv, r, c, alpha, w, a0, a1)
	local D = AST.draw;
	if ( r <= 0 or alpha * c[4] <= 0.003 ) then
		return;
	end
	D.Begin();
	if ( D.AddArc(cu, cv, r, a0 or 0, a1 or 2 * PI) ) then
		D.Stroke(a0 == nil, c, alpha, w);
	end
end

-- A cone's outline (a0..a1, `L` yd long) moved `d` yd out (its sides along their outer sides, its
-- far edge out, round at the corners), and by (du, dv): its points, for a stroke
function K.ConeOutline(L, a0, a1, d, du, dv)
	local D = AST.draw;
	local f, h = (a0 + a1) / 2, (a1 - a0) / 2;
	local back = d / math.max(0.25, math.sin(math.min(h, PI - 0.25)));
	D.Begin();
	if ( d <= 0 ) then
		return D.Add(du, dv) and D.AddArc(du, dv, L, a0, a1);
	end
	return D.Add(du - back * math.cos(f), dv - back * math.sin(f))
		and D.AddArc(du + L * math.cos(a0), dv + L * math.sin(a0), d, a0 - PI / 2, a0)
		and D.AddArc(du, dv, L + d, a0, a1)
		and D.AddArc(du + L * math.cos(a1), dv + L * math.sin(a1), d, a1, a1 + PI / 2);
end

-- A disc `r` yd round (cu, cv) (or the sector a0..a1), filled with Core's own fill
function K.Disc(cu, cv, r, c, alpha, strip, a0, a1)
	local D = AST.draw;
	if ( r <= 0 or alpha * c[4] <= 0.003 ) then
		return;
	end
	D.Begin();
	local ok;
	if ( a0 ) then
		ok = D.Add(cu, cv) and D.AddArc(cu, cv, r, a0, a1);
	else
		ok = D.AddArc(cu, cv, r, 0, 2 * PI);
	end
	if ( ok ) then
		D.FillPoly(c, alpha, strip);
	end
end

-- Core's look of the cone, its pulse given (the Eased and Ready looks draw it so)
function K.ConeBase(L, a0, a1, st, alpha, p, pulse)
	local D = AST.draw;
	if ( p ) then
		if ( p < 1 ) then
			D.Begin();
			local ok = D.AddArc(0, 0, L, a0, a1);
			if ( ok and p > 0 ) then
				ok = D.AddArc(0, 0, L * p, a1, a0);
			elseif ( ok ) then
				ok = D.Add(0, 0);
			end
			if ( ok ) then
				D.FillPoly(st.fill, alpha * 0.35, st.strip);
			end
		end
		if ( p > 0 ) then
			K.Disc(0, 0, L * p, st.fill, alpha * (1 + pulse), st.strip, a0, a1);
		end
	else
		K.Disc(0, 0, L, st.fill, alpha * (1 + pulse), st.strip, a0, a1);
	end
	D.Begin();
	if ( D.Add(0, 0) and D.AddArc(0, 0, L, a0, a1) ) then
		D.Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	if ( p and p > 0 and p < 1 ) then
		K.Ring(0, 0, L * p, K.Bright(K.c1, st.fill), alpha, st.width, a0, a1);
	end
end

-- Core's cone in the Dots style, as it is (through a job of its own)
function K.CoreCone(def, st, alpha, L, facing, p, since)
	local j = K.cj;
	j.def, j.st, j.alpha, j.size, j.facing, j.progress, j.since = def, st, alpha, L, facing, p, since;
	AST.draw.Cone(j);
end

-- The cone's edges a0..a1 of a job
function K.ConeAngles(job)
	local h = job.def.halfAngle * PI / 180;
	return job.facing - h, job.facing + h;
end

-- A demo's colours (its own), the rest of the Lab entry's settings (its style, its width)
function K.DemoSt(key, job, line, fill)
	local d = K.demos[key];
	if ( not d ) then
		d = { line = { 1, 1, 1, 1 }, fill = { 1, 1, 1, 1 } };
		K.demos[key] = d;
	end
	local s = job.st;
	for i = 1, 4 do
		d.line[i], d.fill[i] = line[i], fill[i];
	end
	d.width, d.glow, d.strip, d.style = s.width or 3, s.glow ~= false, s.strip or 3, s.style or "smooth";
	d.size, d.spacing, d.fillSpacing, d.fillStyle = s.size or 5, s.spacing or 9, s.fillSpacing or 12, s.fillStyle or "solid";
	d.flash, d.mode, d.cdFill, d.durFill, d.most = 0.6, "cooldown", true, true, 0;
	return d;
end

-- A demo's cooldown: `t` sec into cycles of `cd` sec, a cast at the start of each
function K.Cycle(t, cd)
	local k = t - math.floor(t / cd) * cd;
	return k / cd, k;
end

---------------------------------------------------------------------------------------------
-- Rim light: the area nearly clear in the middle, a soft band of light inside its edge; a crisp,
-- bright, near-white outline in a soft halo of its colour just outside.

-- The rim-lit area of a disc `r` yd round (or a cone's sector a0..a1): a faint wash over it (one
-- piece with True circles) and, with `glow`, light rising toward its edge: a wide soft band and a
-- narrow one inside it, together a ramp from halfway out; `k` times as strong (times the fill's
-- own opacity)
function K.RimArea(cu, cv, r, c, alpha, k, strip, a0, a1, glow)
	if ( r <= 0 or c[4] * alpha * k <= 0.003 ) then
		return;
	end
	K.Disc(cu, cv, r, c, alpha * k * 0.16, strip, a0, a1);
	if ( not glow or r * K.LocalScale(cu, cv) < 10 ) then
		return;
	end
	local wide, narrow = 0.27 * r, 0.11 * r;
	local w0, w1, n0, n1 = 0, 2 * PI, 0, 2 * PI;
	if ( a0 ) then
		-- along a cone's far edge, kept off its sides
		local dw, dn = math.min(0.45 * (a1 - a0), wide / (r - wide)), math.min(0.45 * (a1 - a0), narrow / (r - narrow));
		w0, w1, n0, n1 = a0 + dw, a1 - dw, a0 + dn, a1 - dn;
	end
	K.SoftArc(cu, cv, r - wide, w0, w1, wide, c, alpha * k * 0.3, 90);
	K.SoftArc(cu, cv, r - narrow, n0, n1, narrow, c, alpha * k * 0.38, 120);
end

-- The halo: a wide faint stroke of the line's colour just outside the outline (its points made
-- already), where Core's glow would be
function K.Halo(st, alpha, pulse)
	AST.draw.Stroke(true, st.line, alpha * (0.2 + 0.15 * pulse), math.max(9, st.width * 4));
end

-- The outline: one crisp stroke, near-white with its colour (the halo round it brings the colour)
function K.RimLine(st, alpha, ww)
	AST.draw.Stroke(true, K.Whiter(K.c2, st.line, 0.45), alpha * st.line[4], ww);
end

function K.RimCircle(cu, cv, R, st, alpha, p, since)
	local pulse = 0;
	if ( since and since >= 0 and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	local w, sc = st.width, K.LocalScale(cu, cv);
	local D = AST.draw;
	-- the halo, centred a little outside the rim so most of it falls outside
	D.Begin();
	if ( D.AddArc(cu, cv, R + math.max(3, w * 1.2) / sc, 0, 2 * PI) ) then
		K.Halo(st, alpha, pulse);
	end
	if ( p ) then
		-- what is still to fill dim, what has filled bright, its front a bright ring
		if ( p < 1 ) then
			K.RimArea(cu, cv, R, st.fill, alpha, 1.8, st.strip, nil, nil, false);
		end
		if ( p > 0 ) then
			K.RimArea(cu, cv, R * p, st.fill, alpha, 1.6 + 0.8 * pulse, st.strip, nil, nil, true);
		end
		if ( p > 0 and p < 1 ) then
			K.Ring(cu, cv, R * p, K.Bright(K.c1, st.fill), alpha * 0.9, math.max(1.5, w * 0.75));
		end
	else
		K.RimArea(cu, cv, R, st.fill, alpha, 1.6 + 0.8 * pulse, st.strip, nil, nil, true);
	end
	D.Begin();
	if ( D.AddArc(cu, cv, R, 0, 2 * PI) ) then
		K.RimLine(st, alpha, w * (1 + 0.6 * pulse));
	end
	-- a cast: Core's shockwave
	if ( since and since >= 0 and since < 0.4 ) then
		K.Ring(cu, cv, R * (0.3 + 0.7 * since / 0.4), K.Bright(K.c1, st.line), alpha * (1 - since / 0.4), w * 1.5);
	end
end

function K.RimCone(L, a0, a1, st, alpha, p, since)
	local D = AST.draw;
	local pulse = 0;
	if ( since and since >= 0 and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	local w = st.width;
	if ( K.ConeOutline(L, a0, a1, math.max(3, w * 1.2) / D.Scale(), 0, 0) ) then
		K.Halo(st, alpha, pulse);
	end
	if ( p ) then
		if ( p < 1 ) then
			K.RimArea(0, 0, L, st.fill, alpha, 1.8, st.strip, a0, a1, false);
		end
		if ( p > 0 ) then
			K.RimArea(0, 0, L * p, st.fill, alpha, 1.6 + 0.8 * pulse, st.strip, a0, a1, true);
		end
		if ( p > 0 and p < 1 ) then
			K.Ring(0, 0, L * p, K.Bright(K.c1, st.fill), alpha * 0.9, math.max(1.5, w * 0.75), a0, a1);
		end
	else
		K.RimArea(0, 0, L, st.fill, alpha, 1.6 + 0.8 * pulse, st.strip, a0, a1, true);
	end
	if ( K.ConeOutline(L, a0, a1, 0, 0, 0) ) then
		K.RimLine(st, alpha, w * (1 + 0.6 * pulse));
	end
end

AST_Lab{
	id = "lab_rim", name = "Rim light", kind = "Polish",
	desc = "Areas lit from the rim: clear in the middle, bright at a crisp edge with a soft halo.",
	applies = "Your rings and cones in the Smooth style: cooldown fills, always-on rings and flashes.",
	fits = function(j)
		return ( j.def.shape == "circle" or j.def.shape == "cone" ) and j.st.style ~= "dots";
	end,
	draw = function(j, p, now)
		if ( j.def.shape == "cone" ) then
			local a0, a1 = K.ConeAngles(j);
			K.RimCone(j.size, a0, a1, j.st, j.alpha, j.progress, j.since);
		else
			K.RimCircle(0, 0, j.size, j.st, j.alpha, j.progress, j.since);
		end
		return true;
	end,
	demo = function(t, j, p, now)
		local ring = K.DemoSt("rim", j, K.GOLD_LINE, K.GOLD_FILL);
		local cone = K.DemoSt("rimc", j, K.VIOLET_LINE, K.VIOLET_FILL);
		ring.style, cone.style = "smooth", "smooth";
		local q, k = K.Cycle(t, 1.5);
		local f = j.facing or 0;
		K.RimCone(12, f - PI / 3, f + PI / 3, cone, j.alpha, nil, nil);
		K.RimCircle(0, 0, 8, ring, j.alpha, q, k);
	end,
};

---------------------------------------------------------------------------------------------
-- Contrast underline: a thin dark line just outside every outline and a unit lower, under it, so
-- the shapes read on snow and sand. One stroke per outline, solid (see-through round pieces would
-- show their overlaps), half of it under the outline: what shows is a dark edge as wide as the
-- outline just outside it, wider below (a unit lower), like a shadow.

-- Under a ring `R` yd round (cu, cv): `off` units out from its middle line, `w` wide
function K.UnderRing(cu, cv, R, st, alpha, off, w)
	if ( R <= 0 or alpha <= 0.003 ) then
		return;
	end
	local du, dv = K.Down(cu, cv);
	K.Ring(cu + du, cv + dv, R + off / K.LocalScale(cu, cv), K.INK, alpha, w);
end

-- Under the Dots style's dots along an arc: each a dark dot a little bigger, a unit lower (where
-- Core's DotArc puts its own)
function K.UnderDots(cu, cv, r, a0, a1, st, alpha)
	local D = AST.draw;
	if ( r <= 0 or alpha <= 0.003 ) then
		return;
	end
	local n = math.ceil(r * math.abs(a1 - a0) * D.Scale() / st.spacing);
	if ( n < 2 ) then
		n = 2;
	end
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n;
		local x, y = D.Map(cu + r * math.cos(a), cv + r * math.sin(a));
		if ( x ) then
			D.Dot(x, y - 1, K.INK, alpha, st.size + 2);
		end
	end
end

-- A ring's outline underlined, as Core draws it: one dark stroke, its inner half under the line
-- (hidden), its outer half the dark edge just outside it (one wide stroke costs fewer pieces than
-- a thin one)
function K.UnderCircle(cu, cv, R, st, alpha)
	if ( st.style == "dots" ) then
		K.UnderDots(cu, cv, R, 0, 2 * PI, st, alpha * 0.7);
		return;
	end
	K.UnderRing(cu, cv, R, st, alpha * st.line[4], st.width * 0.5, st.width * 2);
end

-- A cone's outline underlined: its sides moved out along their outer sides, its far edge out, round
-- at the corners
function K.UnderCone(L, a0, a1, st, alpha)
	local D = AST.draw;
	if ( st.style == "dots" ) then
		local x, y = D.Map(0, 0);
		if ( x ) then
			D.Dot(x, y - 1, K.INK, alpha * 0.6, st.size + 2);
		end
		for s = 0, 1 do
			local a = a0 + (a1 - a0) * s;
			local n = math.ceil(L * D.Scale() / st.spacing);
			for i = 1, n do
				local d = L * i / n;
				x, y = D.Map(d * math.cos(a), d * math.sin(a));
				if ( x ) then
					D.Dot(x, y - 1, K.INK, alpha * 0.6, st.size + 2);
				end
			end
		end
		K.UnderDots(0, 0, L, a0, a1, st, alpha * 0.6);
		return;
	end
	local w = st.width;
	local du, dv = K.Down(0, 0);
	if ( K.ConeOutline(L, a0, a1, w * 0.5 / D.Scale(), du, dv) ) then
		D.Stroke(true, K.INK, alpha * st.line[4], w * 2);
	end
end

-- One telegraph's underlines: whatever its shape, where Core draws it (each outline: not the
-- fill's front or a shockwave, which are inside the shape, over its fill)
function K.Under(j, p, now)
	local D = AST.draw;
	local st, shape = j.st, j.def.shape;
	if ( shape == "circle" ) then
		K.UnderCircle(0, 0, j.size, st, j.alpha);
	elseif ( shape == "cone" ) then
		local a0, a1 = K.ConeAngles(j);
		K.UnderCone(j.size, a0, a1, st, j.alpha);
	elseif ( shape == "downed" ) then
		for i = 1, table.getn(j.downed or {}) do
			local d = j.downed[i];
			local cu, cv = d.x, d.y;
			if ( not d.rel ) then
				cu, cv = d.x - p.x, d.y - p.y;
				D.H.dz = d.z and d.z - p.z or 0;
			end
			K.UnderCircle(cu, cv, j.size, st, j.alpha);
			D.H.dz = 0;
		end
	elseif ( shape == "ground" ) then
		if ( j.test ) then
			K.UnderCircle(6, 3, j.size, st, j.alpha);
			return;
		end
		local spots, def = D.Spots(), j.def;
		local follows = def.follows and D.owned.keys[def.follows];
		local newest;
		for k = 1, table.getn(spots) do
			local s = spots[k];
			local age = now - s.at;
			if ( s.id == def.id and ( s.cands or s.shown ) and not s.over and age <= s.dur + 0.4 ) then
				local fade = 1;
				if ( age > s.dur ) then
					fade = 1 - (age - s.dur) / 0.4;
				end
				if ( follows ) then
					if ( not newest or s.at > newest.at ) then
						newest = s;
					end
				else
					D.H.dz = s.z and s.z - p.z or 0;
					K.UnderCircle(s.x - p.x, s.y - p.y, s.r or j.size, st, j.alpha * fade);
					D.H.dz = 0;
				end
			end
		end
		if ( newest ) then
			K.UnderCircle(0, 0, newest.r or j.size, st, j.alpha * (newest.fade or 1));
		end
	elseif ( shape == "enemy" ) then
		local flash = st.flash;
		if ( j.test ) then
			for k = 0, 2 do
				local age = j.test - k * 0.8;
				if ( age >= 0 and age < flash ) then
					local a = k * 2.1;
					K.UnderCircle(8 * math.cos(a), 8 * math.sin(a), j.size * (0.6 + 0.4 * age / flash), st,
						j.alpha * (1 - age / flash));
				end
			end
		end
		-- the newest first, as many as Core draws
		local rings, drawn = D.Rings(), 0;
		for k = table.getn(rings), 1, -1 do
			local r = rings[k];
			local age = now - r.at;
			if ( r.kind == j.def.id and age >= 0 and age < flash and ( st.most <= 0 or drawn < st.most ) ) then
				drawn = drawn + 1;
				D.H.dz = r.z and r.z - p.z or 0;
				K.UnderCircle(r.x - p.x, r.y - p.y, j.size * (0.6 + 0.4 * age / flash), st, 1 - age / flash);
				D.H.dz = 0;
			end
		end
	end
end

K.under = {
	id = "lab_underline", name = "Contrast underline", kind = "Polish",
	desc = "A thin dark line under every outline, so shapes stay readable on snow and sand.",
	applies = "Every telegraph: rings, cones, ground spots, enemy effects and downed teammates.",
	fits = function(j)
		local s = j.def.shape;
		return s == "circle" or s == "cone" or s == "ground" or s == "enemy" or s == "downed";
	end,
	pre = function(j, p, now)
		K.Under(j, p, now);
	end,
	demo = function(t, j, p, now)
		local ring = K.DemoSt("under", j, K.GOLD_LINE, K.GOLD_FILL);
		local cone = K.DemoSt("underc", j, K.VIOLET_LINE, K.VIOLET_FILL);
		local spot = K.DemoSt("unders", j, K.EMBER_LINE, K.EMBER_FILL);
		local D = AST.draw;
		local q, k = K.Cycle(t, 1.5);
		local f = j.facing or 0;
		local a0, a1 = f - PI / 3, f + PI / 3;
		-- a cone ahead, a ring around you, a spot on the ground behind you
		K.UnderCone(12, a0, a1, cone, j.alpha);
		K.CoreCone(K.DEMO_CONE, cone, j.alpha, 12, f, nil, nil);
		local su, sv = -9 * math.cos(f) + 3 * math.sin(f), -9 * math.sin(f) - 3 * math.cos(f);
		K.UnderCircle(su, sv, 4, spot, j.alpha);
		D.Spot(su, sv, 4, spot, j.alpha, math.min(1, t / 3));
		K.UnderCircle(0, 0, 8, ring, j.alpha);
		D.Circle(0, 0, 8, ring, j.alpha, q, k);
	end,
};
AST_Lab(K.under);

---------------------------------------------------------------------------------------------
-- Eased motion: a flash comes in from 92% easing out and leaves easing in; a cast's shockwave
-- slows as it reaches the edge, a soft band trailing behind its front; the pulse dies away
-- smoothly; a full fill fades as the next cooldown starts, rather than vanishing.

K.FLASH = { cast = true, proc = true, shield = true };

-- A flash's look at `since` (sec): how opaque, and how big (of its size)
function K.Envelope(since, flash)
	if ( not since or since < 0 or since >= flash ) then
		return 0, 1;
	end
	local a, s = 1, 1;
	if ( since < 0.15 ) then
		local e = K.EaseOut(since / 0.15, 3);
		a, s = e, 0.92 + 0.08 * e;
	end
	local out = math.min(0.3, flash * 0.5);
	local u = (since - (flash - out)) / out;
	if ( u > 0 ) then
		local e = u * u;
		a, s = a * (1 - e), s * (1 - 0.06 * e);
	end
	return a, s;
end

-- The pulse a cast gives, dying away smoothly (Core's stops dead)
function K.Pulse(since)
	if ( since and since >= 0 and since < 0.4 ) then
		local u = 1 - since / 0.4;
		return u * u;
	end
	return 0;
end

-- The soft band trailing a front `r` yd round (cu, cv) (or its arc a0..a1): brightest just behind
-- it, fading inward
function K.Trail(cu, cv, r, st, alpha, a0, a1)
	local rho = 0.15 * r;
	local inset = 0;
	if ( a1 - a0 < 2 * PI - 1e-3 ) then
		inset = math.min(0.45 * (a1 - a0), rho / math.max(0.1, r - rho));
	end
	K.SoftArc(cu, cv, r - rho, a0 + inset, a1 - inset, rho, st.fill, alpha * 0.7);
end

-- The shockwave: out from 30% of the size, slowing to the edge (cubic), a soft band behind it
function K.EasedShock(cu, cv, R, st, alpha, since)
	if ( not since or since < 0 or since >= 0.55 ) then
		return;
	end
	local s = since / 0.55;
	local r = R * (0.3 + 0.7 * K.EaseOut(s, 3));
	local fade = math.pow(1 - s, 1.6);
	local bright = K.Bright(K.c3, st.line);
	if ( st.style == "dots" ) then
		local D = AST.draw;
		D.DotArc(cu, cv, r * 0.86, 0, 2 * PI, st.fill, alpha * fade * 0.8, st.size * 0.8, st.spacing);
		D.DotArc(cu, cv, r, 0, 2 * PI, bright, alpha * fade, st.size * (1 + 0.3 * fade), st.spacing);
		return;
	end
	K.Trail(cu, cv, r, st, alpha * fade, 0, 2 * PI);
	K.Ring(cu, cv, r, bright, alpha * math.min(1, 2 * fade), st.width * 1.2);
end

-- The cone's: an arc running out along it
function K.EasedWave(L, a0, a1, st, alpha, since)
	if ( not since or since < 0 or since >= 0.5 ) then
		return;
	end
	local s = since / 0.5;
	local r = L * (0.1 + 0.9 * K.EaseOut(s, 3));
	local fade = math.pow(1 - s, 1.5);
	local bright = K.Bright(K.c3, st.line);
	local inset = math.min(0.4 * (a1 - a0), 0.06);
	if ( st.style == "dots" ) then
		AST.draw.DotArc(0, 0, r, a0 + inset, a1 - inset, bright, alpha * fade, st.size, st.spacing);
		return;
	end
	K.Trail(0, 0, r, st, alpha * fade, a0 + inset, a1 - inset);
	K.Ring(0, 0, r, bright, alpha * math.min(1, 2 * fade), st.width * 1.2, a0 + inset, a1 - inset);
end

-- A ring, eased: `flashing` (its mode a flash) brings in its envelope
function K.EasedCircle(cu, cv, R, st, alpha, p, since)
	local D = AST.draw;
	local pulse = K.Pulse(since);
	if ( st.style == "dots" ) then
		D.Circle(cu, cv, R, st, alpha, p, nil);
		K.EasedShock(cu, cv, R, st, alpha, since);
		return;
	end
	if ( p ) then
		if ( p < 1 ) then
			K.Disc(cu, cv, R, st.fill, alpha * 0.35, st.strip);
		end
		-- the fill that was full when it went off, fading rather than gone at once
		if ( since and since >= 0 and since < 0.3 and p < 0.5 ) then
			K.Disc(cu, cv, R, st.fill, alpha * 0.65 * (1 - K.EaseOut(since / 0.3, 2)), st.strip);
		end
		if ( p > 0 ) then
			K.Disc(cu, cv, R * p, st.fill, alpha * (1 + pulse), st.strip);
		end
		if ( p > 0 and p < 1 ) then
			K.Ring(cu, cv, R * p, K.Bright(K.c1, st.fill), alpha, st.width);
		end
	else
		K.Disc(cu, cv, R, st.fill, alpha * (1 + pulse), st.strip);
	end
	D.Begin();
	if ( D.AddArc(cu, cv, R, 0, 2 * PI) ) then
		D.Outline(true, st, alpha, 1 + pulse * 0.6);
	end
	K.EasedShock(cu, cv, R, st, alpha, since);
end

function K.EasedCone(def, L, facing, st, alpha, p, since)
	local h = def.halfAngle * PI / 180;
	local a0, a1 = facing - h, facing + h;
	if ( st.style == "dots" ) then
		K.CoreCone(def, st, alpha, L, facing, p, nil);
	else
		K.ConeBase(L, a0, a1, st, alpha, p, K.Pulse(since));
	end
	K.EasedWave(L, a0, a1, st, alpha, since);
end

-- A job, eased: a flash's envelope (a Test press of one: a flash every 1.5 sec)
function K.Eased(j)
	local st, since, alpha, scale = j.st, j.since, j.alpha, 1;
	if ( K.FLASH[st.mode] ) then
		if ( K.Testing(j.def) ) then
			since = since and since - math.floor(since / 1.5) * 1.5;
		else
			alpha = 1;
		end
		local a, s = K.Envelope(since, math.max(0.2, st.flash or 0.6));
		alpha, scale = alpha * a, s;
		if ( alpha <= 0.003 ) then
			return;
		end
	end
	if ( j.def.shape == "cone" ) then
		K.EasedCone(j.def, j.size * scale, j.facing, st, alpha, j.progress, since);
	else
		K.EasedCircle(0, 0, j.size * scale, st, alpha, j.progress, since);
	end
end

AST_Lab{
	id = "lab_eased", name = "Eased motion", kind = "Polish",
	desc = "Flashes ease in and out, shockwaves slow as they land, a cast's pulse dies away smoothly.",
	applies = "Your rings and cones: flashes on cast or proc, and every cast's shockwave.",
	fits = function(j)
		return j.def.shape == "circle" or j.def.shape == "cone";
	end,
	draw = function(j, p, now)
		K.Eased(j);
		return true;
	end,
	demo = function(t, j, p, now)
		local ring = K.DemoSt("eased", j, K.GOLD_LINE, K.GOLD_FILL);
		local cone = K.DemoSt("easedc", j, K.VIOLET_LINE, K.VIOLET_FILL);
		-- the cone on a cooldown of 1.5 sec; the ring a cast flash, twice
		local q, k = K.Cycle(t + 0.75, 1.5);
		K.EasedCone(K.DEMO_CONE, 12, j.facing or 0, cone, j.alpha, q, k);
		local _, since = K.Cycle(t, 1.5);
		local a, s = K.Envelope(since, 0.6);
		if ( a * j.alpha > 0.003 ) then
			K.EasedCircle(0, 0, 8 * s, ring, j.alpha * a, nil, since);
		end
	end,
};

---------------------------------------------------------------------------------------------
-- Ready ping: dim and greyed while cooling down; the moment it's ready, a ring pops outward and
-- the fill flashes; while it waits to be cast (for enemies in range), a comet runs round its rim.

-- What a telegraph's cooldown is doing, kept by `key` in `list`: k (how bright, 0 dim to 1),
-- ready, readyAt, pingAt (when it last came ready, or went off on coming ready)
function K.Track(list, key, now, ready, castAt)
	local s = list[key];
	if ( not s ) then
		-- first seen: as it is, with no ping
		s = { k = ready and 1 or 0, ready = ready, readyAt = ready and now - 10 or nil, castAt = castAt, last = now };
		list[key] = s;
	end
	local dt = math.max(0, math.min(0.1, now - s.last));
	s.last = now;
	if ( castAt and ( not s.castAt or math.abs(castAt - s.castAt) > 0.02 ) ) then
		-- a cast: one that came the moment it was ready (most do) pings as it goes off
		if ( not s.ready and now - castAt < 0.3 ) then
			s.pingAt, s.k = castAt, 1;
		end
		s.castAt, s.ready, s.readyAt = castAt, false, nil;
	elseif ( ready and not s.ready ) then
		s.ready, s.readyAt, s.pingAt, s.k = true, now, now, 1;
	elseif ( not ready ) then
		s.ready, s.readyAt = false, nil;
	end
	local target = 0;
	if ( s.ready ) then
		target = 1;
	end
	s.k = target + (s.k - target) * math.exp(-dt / 0.18);
	return s;
end

-- A demo's tracking starts afresh with each Test press (`t` sec into it)
function K.Fresh(list, key, t)
	local s = list[key];
	if ( s and s.t and t < s.t ) then
		list[key] = nil;
	elseif ( s ) then
		s.t = t;
	end
end

-- A telegraph's settings with its colours dimmed `k` (Core draws through it)
function K.Proxy(key, st, k)
	local px = K.proxies[key];
	if ( not px ) then
		px = { line = { 1, 1, 1, 1 }, fill = { 1, 1, 1, 1 } };
		setmetatable(px, { __index = function(t, f) return rawget(t, "src")[f]; end });
		K.proxies[key] = px;
	end
	px.src = st;
	K.Dim(px.line, st.line, k);
	K.Dim(px.fill, st.fill, k);
	return px;
end

-- Its cooldown's progress (0..1): the job's, or (its fill turned off) the spell's; and whether ready
function K.Progress(j)
	local p = j.progress;
	if ( p ) then
		return p, p >= 0.999;
	end
	local c = AST.draw.SpellOf(j.def);
	if ( c and c.max and c.max > 0 and c.left ) then
		return math.max(0, math.min(1, 1 - c.left / c.max)), c.left <= 0 and not ( j.since and j.since < 0.25 );
	end
	return nil, false;
end

-- Where round a cone's outline (apex, side a0, far edge, side a1) the length `d` in yd comes
function K.ConePoint(L, a0, a1, d)
	local arc = L * (a1 - a0);
	local P = 2 * L + arc;
	d = d - math.floor(d / P) * P;
	if ( d < L ) then
		return d * math.cos(a0), d * math.sin(a0);
	elseif ( d < L + arc ) then
		local a = a0 + (d - L) / L;
		return L * math.cos(a), L * math.sin(a);
	end
	local r = P - d;
	return r * math.cos(a1), r * math.sin(a1);
end

-- The ping: a ring popping out 10% and fading (0.45 sec), the fill flashing (0.3 sec)
function K.Ping(cu, cv, R, st, alpha, age, a0, a1)
	if ( not age or age < 0 or age >= 0.45 ) then
		return;
	end
	local s = age / 0.45;
	local f = 1 - s;
	local r = R * (1 + 0.1 * K.EaseOut(s, 3));
	local bright = K.Bright(K.c3, st.line);
	local D = AST.draw;
	if ( st.style == "dots" ) then
		D.DotArc(cu, cv, r, a0 or 0, a1 or 2 * PI, bright, alpha * f, st.size * (1 + 0.5 * f), st.spacing);
		return;
	end
	if ( age < 0.3 ) then
		K.Disc(cu, cv, R, st.fill, alpha * 1.2 * (1 - age / 0.3), st.strip, a0, a1);
	end
	D.Begin();
	local ok;
	if ( a0 ) then
		ok = D.Add(cu, cv) and D.AddArc(cu, cv, r, a0, a1);
	else
		ok = D.AddArc(cu, cv, r, 0, 2 * PI);
	end
	if ( ok ) then
		-- one wide bright ring (a wide stroke is few pieces), solid for most of its time (a see-through
		-- one shows its pieces' overlaps), fading at the end
		D.Stroke(true, bright, alpha * math.min(1, 2.5 * f), math.max(6, st.width * 2.4));
	end
end

-- The comet: a bright head and a fading, thinning tail of round pieces (a soft glow round its
-- front), `head` yd along the rim, going the way `dir` says; on a ring `R` yd round (cu, cv), or
-- round a cone's outline (a0..a1). In the Dots style its tail is dots, as far apart as the style's.
function K.Comet(cu, cv, R, st, alpha, head, dir, a0, a1)
	local D = AST.draw;
	local sc = D.Scale();
	local tail = 0.9 * math.min(R, 10);
	local bright = K.Whiter(K.c3, st.line, 0.7);
	local dotty = st.style == "dots";
	local big = math.max(6, st.width * 3);
	if ( dotty ) then
		big = st.size * 1.6;
	end
	local d, k = 0, 0;
	while ( d < tail and k < 100 ) do
		local f = 1 - d / tail;
		local size = big * (0.3 + 0.7 * f);
		local at = head - dir * d;
		local u, v;
		if ( a0 ) then
			u, v = K.ConePoint(R, a0, a1, at);
		else
			u, v = cu + R * math.cos(at / R), cv + R * math.sin(at / R);
		end
		local x, y = D.Map(u, v);
		if ( x ) then
			if ( not dotty and k - math.floor(k / 2) * 2 == 0 and f > 0.3 ) then
				D.Dot(x, y, st.line, alpha * 0.22 * f, size * 3);
			end
			D.Dot(x, y, bright, alpha * f, size);
		end
		k = k + 1;
		if ( dotty ) then
			d = d + st.spacing / sc;
		else
			d = d + math.max(0.8, 0.6 * size) / sc;
		end
	end
end

-- A telegraph in the Ready look: Core's, dimmed while it cools down; then the ping and the comet
function K.ReadyLook(s, now, def, st, alpha, R, facing, p, since, cone)
	local D = AST.draw;
	local px = K.Proxy(def.id or "demo", st, s.k);
	local a0, a1;
	if ( cone ) then
		local h = def.halfAngle * PI / 180;
		a0, a1 = facing - h, facing + h;
		K.CoreCone(def, px, alpha, R, facing, p, since);
	else
		D.Circle(0, 0, R, px, alpha, p, since);
	end
	K.Ping(0, 0, R, st, alpha, s.pingAt and now - s.pingAt, a0, a1);
	-- waiting to be cast: the comet, one lap every 2.4 sec, starting at the top as you see it
	if ( s.ready and s.readyAt ) then
		local t = now - s.readyAt - 0.25;
		if ( t > 0 ) then
			local up, dir = K.Clock(0, 0);
			local fi = math.min(1, t / 0.3);
			if ( cone ) then
				local P = 2 * R + R * (a1 - a0);
				-- from the far edge's middle, the way that's clockwise on the screen
				K.Comet(0, 0, R, st, alpha * fi, R + R * (a1 - a0) / 2 + dir * t * P / 2.4, dir, a0, a1);
			else
				K.Comet(0, 0, R, st, alpha * fi, R * up + dir * t * 2 * PI * R / 2.4, dir);
			end
		end
	end
end

AST_Lab{
	id = "lab_ready", name = "Ready ping", kind = "Time",
	desc = "Dim while cooling down; a bright ping when ready, and a shimmer while it waits to cast.",
	applies = "Your rings and cones that show their cooldown.",
	fits = function(j)
		return ( j.def.shape == "circle" or j.def.shape == "cone" ) and j.st.mode == "cooldown"
			and ( j.progress ~= nil or AST.draw.SpellOf(j.def) ~= nil );
	end,
	draw = function(j, p, now)
		local prog, ready = K.Progress(j);
		local s = K.Track(K.ready, j.def.id, now, ready, j.since and now - j.since);
		K.ReadyLook(s, now, j.def, j.st, j.alpha, j.size, j.facing, j.progress, j.since, j.def.shape == "cone");
		return true;
	end,
	demo = function(t, j, p, now)
		local ring = K.DemoSt("ready", j, K.GOLD_LINE, K.GOLD_FILL);
		local cone = K.DemoSt("readyc", j, K.VIOLET_LINE, K.VIOLET_FILL);
		-- the ring: 1 sec of cooldown, ready (waiting) for 1.5, cast at 2.5; the cone: casts every 1.5 sec
		local q, since, ready = math.min(1, t), t + 0.5, t >= 1;
		if ( t >= 2.5 ) then
			q, since, ready = (t - 2.5) / 1, t - 2.5, false;
		end
		K.Fresh(K.ready, "demo_ring", t);
		local s = K.Track(K.ready, "demo_ring", now, ready, now - since);
		K.ReadyLook(s, now, j.def, ring, j.alpha, 8, 0, q, since, false);
		local cq, ck = K.Cycle(t + 0.4, 1.5);
		K.Fresh(K.ready, "demo_cone", t);
		local sc = K.Track(K.ready, "demo_cone", now, false, now - ck);
		K.ReadyLook(sc, now, K.DEMO_CONE, cone, j.alpha, 12, j.facing or 0, cq, ck, true);
	end,
};

---------------------------------------------------------------------------------------------
-- Sweep fill: the cooldown sweeps round clockwise from 12 o'clock (as you see it) like a clock's
-- hand, a bright edge leading it.

function K.SweepCircle(cu, cv, R, st, alpha, p, since)
	local D = AST.draw;
	local pulse = 0;
	if ( since and since >= 0 and since < 0.35 ) then
		pulse = 1 - since / 0.35;
	end
	local up, dir = K.Clock(cu, cv);
	local a1 = up + dir * 2 * PI * p;
	local lo, hi = math.min(up, a1), math.max(up, a1);
	local bright = K.Bright(K.c1, st.fill);
	local ex, ey = cu + R * math.cos(a1), cv + R * math.sin(a1);
	if ( st.style == "dots" ) then
		D.DotArc(cu, cv, R, 0, 2 * PI, st.line, alpha, st.size, st.spacing);
		if ( p > 0.002 ) then
			D.DotFill(cu, cv, R - st.fillSpacing / D.Scale(), lo, hi, st, alpha);
		end
		if ( p > 0 and p < 1 ) then
			-- the hand, dot by dot
			local n = math.max(2, math.ceil(R * D.Scale() / st.spacing));
			for i = 1, n do
				local x, y = D.Map(cu + (ex - cu) * i / n, cv + (ey - cv) * i / n);
				if ( x ) then
					D.Dot(x, y, bright, alpha, st.size * 1.15);
				end
			end
		end
	else
		-- the whole area faint (one piece, with true circles), what has filled over it, as full as
		-- Core's fill then
		local over = math.min(0.99, st.fill[4] * alpha * (1 + pulse));
		local under = st.fill[4] * alpha * 0.35;
		if ( p < 0.998 ) then
			K.Disc(cu, cv, R, st.fill, alpha * 0.35, st.strip);
			over = (over - under) / (1 - under);
		end
		if ( p > 0.002 and st.fill[4] > 0 and over > 0 ) then
			K.Disc(cu, cv, R, st.fill, over / st.fill[4], st.strip, p < 0.998 and up or nil, a1);
		end
		-- the hand: a soft glow and a bright line from the centre to the rim, a spark at its tip
		if ( p > 0.002 and p < 0.998 ) then
			D.Begin();
			if ( D.Add(cu, cv) and D.Add(ex, ey) ) then
				D.Stroke(false, st.line, alpha * 0.25, st.width * 3);
				D.Stroke(false, bright, alpha, math.max(1.5, st.width * 0.8));
			end
			local x, y = D.Map(ex, ey);
			if ( x ) then
				D.Dot(x, y, st.line, alpha * 0.35, st.width * 4);
				D.Dot(x, y, K.Whiter(K.c2, st.line, 0.7), alpha, st.width * 1.8);
			end
		end
		D.Begin();
		if ( D.AddArc(cu, cv, R, 0, 2 * PI) ) then
			D.Outline(true, st, alpha, 1 + pulse * 0.6);
		end
	end
	-- a cast: Core's shockwave
	if ( since and since >= 0 and since < 0.4 ) then
		local r = R * (0.3 + 0.7 * since / 0.4);
		if ( st.style == "dots" ) then
			D.DotArc(cu, cv, r, 0, 2 * PI, K.Bright(K.c3, st.line), alpha * (1 - since / 0.4), st.size, st.spacing);
		else
			K.Ring(cu, cv, r, K.Bright(K.c3, st.line), alpha * (1 - since / 0.4), st.width * 1.5);
		end
	end
end

AST_Lab{
	id = "lab_sweep", name = "Sweep fill", kind = "Time",
	desc = "The cooldown sweeps round clockwise from 12 o'clock, like a clock's hand.",
	applies = "Your cooldown rings (with their cooldown fill on).",
	fits = function(j)
		return j.def.shape == "circle" and j.progress ~= nil;
	end,
	draw = function(j, p, now)
		K.SweepCircle(0, 0, j.size, j.st, j.alpha, j.progress, j.since);
		return true;
	end,
	demo = function(t, j, p, now)
		local q, k = K.Cycle(t, 1.5);
		K.SweepCircle(0, 0, 8, K.DemoSt("sweep", j, K.GOLD_LINE, K.GOLD_FILL), j.alpha, q, k);
	end,
};

---------------------------------------------------------------------------------------------
-- Countdown pips: eight small dots round the rim (a cone's: along its far edge) light up one by
-- one as the spell recovers; the one charging pulses; all lit and a sparkle when it's ready.

-- The pips' size (across, in screen units)
function K.PipSize(st)
	return math.max(6, st.width * 2.8);
end

-- Where pip i (0 to 7) is: round the ring from 12 o'clock clockwise, or along a cone's far edge
-- from its left (as you see it)
function K.PipAt(cu, cv, R, i, n, up, dir, a0, a1)
	local a;
	if ( a0 ) then
		if ( dir > 0 ) then
			a = a0 + (a1 - a0) * (i + 0.5) / n;
		else
			a = a1 - (a1 - a0) * (i + 0.5) / n;
		end
	else
		a = up + dir * i * 2 * PI / n;
	end
	return AST.draw.Map(cu + R * math.cos(a), cv + R * math.sin(a));
end

function K.Pips(cu, cv, R, st, alpha, p, now, s, a0, a1)
	local D = AST.draw;
	if ( not p or alpha <= 0.003 ) then
		return;
	end
	local n = 8;
	local up, dir = K.Clock(cu, cv);
	local lit = math.floor(p * n + 1e-6);
	local frac = p * n - lit;
	local d = K.PipSize(st);
	local bright = K.Bright(K.c1, st.line);
	local white = K.Whiter(K.c2, st.line, 0.85);
	-- just ready (or gone off on coming ready): all lit, fading to what they show now
	local ping = s and s.pingAt and now - s.pingAt;
	local q = 0.5 + 0.5 * math.sin(now * 2 * PI * 2);
	for i = 0, n - 1 do
		local x, y = K.PipAt(cu, cv, R, i, n, up, dir, a0, a1);
		if ( x ) then
			D.Dot(x, y, K.INK, alpha * 0.55, d * 1.6);
			if ( i < lit ) then
				D.Dot(x, y, st.line, alpha * 0.18, d * 3);
				D.Dot(x, y, st.line, alpha * 0.4, d * 1.8);
				D.Dot(x, y, bright, alpha, d);
			else
				-- unlit: a faint ring
				D.Dot(x, y, st.line, alpha * 0.6, d);
				D.Dot(x, y, K.INK, alpha * 0.8, d * 0.6);
				D.Dot(x, y, st.line, alpha * 0.12, d * 0.6);
				if ( i == lit ) then
					-- charging: it pulses, brighter as it nears full
					local al = (0.25 + 0.6 * q) * (0.4 + 0.6 * frac);
					D.Dot(x, y, st.line, alpha * 0.3 * al, d * 2.6);
					D.Dot(x, y, st.line, alpha * al, d * 0.9);
				end
				if ( ping and ping >= 0 and ping < 0.5 ) then
					local f = 1 - ping / 0.5;
					f = f * f;
					D.Dot(x, y, st.line, alpha * 0.4 * f, d * 1.8);
					D.Dot(x, y, bright, alpha * f, d);
				end
			end
			-- the sparkle: each pip flares in turn round the ring, a little star on it
			if ( ping and ping >= 0 ) then
				local tt = ping - i * 0.04;
				if ( tt >= 0 and tt < 0.35 ) then
					local f = 1 - tt / 0.35;
					local g = K.EaseOut(tt / 0.35, 2);
					D.Dot(x, y, white, alpha * f, d * (1 + 1.2 * g));
					local len, th = d * (1.5 + 2.5 * g), math.max(1, d * 0.16);
					D.Quad(D.SOLID, x - len, y - th / 2, 2 * len, th, white, alpha * f * 0.9);
					D.Quad(D.SOLID, x - th / 2, y - len, th, 2 * len, white, alpha * f * 0.9);
				end
			end
		end
	end
end

AST_Lab{
	id = "lab_pips", name = "Countdown pips", kind = "Time",
	desc = "Eight dots round the rim light up one by one as the cooldown runs, with a sparkle when ready.",
	applies = "Your cooldown rings and cones (with their cooldown fill on), drawn over them.",
	fits = function(j)
		return ( j.def.shape == "circle" or j.def.shape == "cone" ) and j.progress ~= nil;
	end,
	post = function(j, p, now)
		local prog, ready = K.Progress(j);
		local s = K.Track(K.pips, j.def.id, now, ready, j.since and now - j.since);
		if ( j.def.shape == "cone" ) then
			local a0, a1 = K.ConeAngles(j);
			K.Pips(0, 0, j.size, j.st, j.alpha, j.progress, now, s, a0, a1);
		else
			K.Pips(0, 0, j.size, j.st, j.alpha, j.progress, now, s);
		end
	end,
	demo = function(t, j, p, now)
		local ring = K.DemoSt("pips", j, K.GOLD_LINE, K.GOLD_FILL);
		local cone = K.DemoSt("pipsc", j, K.VIOLET_LINE, K.VIOLET_FILL);
		local D = AST.draw;
		local f = j.facing or 0;
		local cq, ck = K.Cycle(t + 0.6, 1.5);
		K.CoreCone(K.DEMO_CONE, cone, j.alpha, 12, f, cq, ck);
		K.Fresh(K.pips, "demo_cone", t);
		local sc = K.Track(K.pips, "demo_cone", now, false, now - ck);
		K.Pips(0, 0, 12, cone, j.alpha, cq, now, sc, f - PI / 3, f + PI / 3);
		local q, k = K.Cycle(t, 1.5);
		D.Circle(0, 0, 8, ring, j.alpha, q, k);
		K.Fresh(K.pips, "demo_ring", t);
		local s = K.Track(K.pips, "demo_ring", now, false, now - k);
		K.Pips(0, 0, 8, ring, j.alpha, q, now, s);
	end,
};
