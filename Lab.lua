-- Azeroth Survivors Telegraphs: the Lab. New looks for the telegraphs, to try out one by one on the
-- Lab page (each off to start with). On, an experiment draws under, over or instead of the
-- telegraphs it fits, so the telegraphs you already use show it; its Test press plays a demo of it
-- around you. The Lab is a separate file (and page) so it can go as a whole.
--
-- An experiment, given to AST_Lab:
--   id, name, desc, kind (its heading on the Lab page: "Polish", "Time", "Signature", "Textures"),
--   applies: a line on what it changes, for the options;
--   fits(job): whether it touches this telegraph's drawing this frame (job: see below);
--   pre(job, p, now): drawn before it (under it); draw(job, p, now): drawn instead of it (return
--   true when it did); post(job, p, now): drawn after it (over it); after(p, now): once a frame,
--   after every telegraph; demo(t, job, p, now): a Test press, t seconds in (0 to 3).
-- A job (what Core draws this frame): def, st (its settings), size (yd), alpha, progress (0..1
-- through its cooldown, or nil), since (sec since its cast, or nil), facing (a cone's, radians),
-- test (a Test press of it: seconds in). Ground spells: their spots are AST.draw.Spots() (id = the
-- def's id, x, y, z (world), at, dur, r); enemy effects: AST.draw.Rings() (kind = the def's id,
-- x, y, z, at), which whoever draws them instead must clear of the old (over 2 sec).
-- p: the hero (x, y, z, facing). Drawing: AST.draw (Core's own pieces) and the helpers below.

AST.lab = { list = {}, on = {} };
local LAB = AST.lab;

local KIND_ORDER = { "Polish", "Time", "Signature", "Textures" };
LAB.kinds = KIND_ORDER;

function AST_Lab(e)
	e.shape = "lab";
	e.kind = e.kind or "Polish";
	e.defaults = e.defaults or {};
	e.defaults.enabled = e.startOn == true;
	e.defaults.mode = "always";
	table.insert(LAB.list, e);
	AST_Register("lab", { e }, { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
		blurb = "New looks to try out. Each one changes the telegraphs it fits while it's on." });
end

-- The experiments that are on, worked out once a frame.
function LAB.Frame(now)
	local on = {};
	local _, _, _, _, byId = AST.State();
	for i = 1, table.getn(LAB.list) do
		local e = LAB.list[i];
		if ( byId and byId[e.id] and AST.Settings(e).enabled ) then
			table.insert(on, e);
		end
	end
	LAB.on = on;
	LAB.now = now;
	-- the screen's size, once a frame (each texture piece needs it)
	LAB.sw, LAB.sh = WorldFrame:GetWidth() or 1024, WorldFrame:GetHeight() or 768;
	-- True circles (Core's own drawing)
	local tc = byId and byId.lab_true;
	AST.draw.H.round = tc ~= nil and AST.Settings(tc).enabled == true;
end

local function Fits(e, j)
	if ( j.def.shape == "lab" ) then
		return false;
	end
	if ( e.fits ) then
		local ok, res = pcall(e.fits, j);
		return ok and res;
	end
	return false;
end

-- One experiment's step, an error in it reported once (with /ast debug) and that one switched off,
-- so a broken experiment can't stop the telegraphs.
LAB.errors = {};
local function Run(e, f, a, b, c, d)
	local ok, res = pcall(f, a, b, c, d);
	if ( not ok ) then
		LAB.errors[e.id] = tostring(res);
		AST.Settings(e).enabled = false;
		DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: Lab: " .. e.name .. " stopped: " .. tostring(res));
		return nil;
	end
	return res;
end

function LAB.Pre(j, p, now)
	for i = 1, table.getn(LAB.on) do
		local e = LAB.on[i];
		if ( e.pre and Fits(e, j) ) then
			Run(e, e.pre, j, p, now);
		end
	end
end

-- Whether an experiment drew job `j` instead of Core (a Lab entry's own Test press: its demo).
function LAB.Draw(j, p, now)
	if ( j.def.shape == "lab" ) then
		if ( j.test and j.def.demo ) then
			Run(j.def, j.def.demo, j.test, j, p, now);
		end
		return true;
	end
	for i = 1, table.getn(LAB.on) do
		local e = LAB.on[i];
		if ( e.draw and Fits(e, j) and Run(e, e.draw, j, p, now) ) then
			return true;
		end
	end
	return false;
end

function LAB.Post(j, p, now)
	for i = 1, table.getn(LAB.on) do
		local e = LAB.on[i];
		if ( e.post and Fits(e, j) ) then
			Run(e, e.post, j, p, now);
		end
	end
end

function LAB.After(p, now)
	for i = 1, table.getn(LAB.on) do
		local e = LAB.on[i];
		if ( e.after ) then
			Run(e, e.after, p, now);
		end
	end
end

---------------------------------------------------------------------------------------------
-- Helpers for the experiments

-- Ease-outs and a colour mixed toward another.
function LAB.EaseOut(x, k)
	x = math.max(0, math.min(1, x));
	return 1 - math.pow(1 - x, k or 3);
end

function LAB.Mix(a, b, t, alpha)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, alpha or a[4] or 1 };
end

-- A ring (or an arc a0..a1) `R` yd round (cu, cv), stroked: Core's polyline pieces.
function LAB.Ring(cu, cv, R, c, alpha, w, a0, a1)
	local D = AST.draw;
	if ( R <= 0 or alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	if ( D.AddArc(cu, cv, R, a0 or 0, a1 or 2 * D.PI) ) then
		D.Stroke(a0 == nil, c, alpha, w);
	end
end

-- A disc (or a sector a0..a1, or a band from r0 out to R), filled with strips.
function LAB.Disc(cu, cv, R, c, alpha, strip, a0, a1, r0)
	local D = AST.draw;
	if ( R <= 0 or alpha <= 0.003 ) then
		return;
	end
	D.Begin();
	local ok;
	if ( r0 and r0 > 0 ) then
		ok = D.AddArc(cu, cv, R, a0 or 0, a1 or 2 * D.PI) and D.AddArc(cu, cv, r0, a1 or 2 * D.PI, a0 or 0);
	elseif ( a0 ) then
		ok = D.Add(cu, cv) and D.AddArc(cu, cv, R, a0, a1);
	else
		ok = D.AddArc(cu, cv, R, 0, 2 * D.PI);
	end
	if ( ok ) then
		D.FillPoly(c, alpha, strip or 3);
	end
end

-- Textures of the game's own, drawn this frame: two pools, under Core's pieces and over them.
local pools = { under = { list = {}, used = 0, shown = 0, layer = "ARTWORK" },
	over = { list = {}, used = 0, shown = 0, layer = "OVERLAY" } };

-- A texture of `path` for this frame, blended "BLEND" (or "ADD": it adds its light), over Core's
-- pieces when `over`.
function LAB.Tex(path, blend, over)
	local pl = over and pools.over or pools.under;
	pl.used = pl.used + 1;
	local t = pl.list[pl.used];
	if ( not t ) then
		t = AST.draw.canvas:CreateTexture(nil, pl.layer);
		t.layer = pl.layer;   -- which pool's (the tests read it too)
		pl.list[pl.used] = t;
	end
	if ( t.path ~= path ) then
		t:SetTexture(path);
		-- a new image may come with the default coordinates and colour: LAB.Place sends them again
		t.path, t.ltc, t.la = path, nil, nil;
	end
	blend = blend or "BLEND";
	if ( t.blend ~= blend and t.SetBlendMode ) then
		t:SetBlendMode(blend);
		t.blend = blend;
	end
	if ( not t.on ) then
		t:Show();
		t.on = true;
	end
	return t;
end

-- How long this frame's telegraphs take: Core calls Start as it begins a frame, Finish as it ends.
-- In milliseconds with the client's profiling clock, else GetTime's (coarser).
local timing = { at = nil, sum = 0, most = 0, n = 0 };
LAB.timing = timing;

local function Clock()
	if ( debugprofilestop ) then
		local ok, ms = pcall(debugprofilestop);
		if ( ok and type(ms) == "number" ) then
			return ms;
		end
	end
	return GetTime() * 1000;
end

function LAB.Start()
	timing.at = Clock();
end

-- Hides what wasn't drawn this frame (Core calls it at the end of each frame).
function LAB.Finish()
	if ( timing.at ) then
		local ms = Clock() - timing.at;
		timing.at = nil;
		if ( ms >= 0 and ms < 1000 ) then
			timing.sum, timing.n = timing.sum + ms, timing.n + 1;
			if ( ms > timing.most ) then
				timing.most = ms;
			end
		end
	end
	for _, pl in pairs(pools) do
		for i = pl.used + 1, pl.shown do
			local t = pl.list[i];
			if ( t and t.on ) then
				t:Hide();
				t.on = false;
			end
		end
		pl.shown = pl.used;
		pl.used = 0;
	end
end

-- Texture `path` laid flat on the ground: its square, 2R yd across, centred (cu, cv) yd from the
-- hero (at the height AST.draw.H.dz), turned `rot` radians; colour c ({ r, g, b, a }) x alpha. One
-- piece: the screen's box round the ground circle's exact ellipse, its 8 texture coordinates
-- carrying the texture's inscribed circle onto it. Returns the texture, or nil.

-- The screen ellipse of the ground circle R round (cu, cv) at height H.dz: its centre and the two
-- half-diameters (a, b) that carry the unit circle onto it. nil when it isn't an ellipse wholly
-- in front of the camera.
function LAB.Fit(cu, cv, R, rot)
	local D = AST.draw;
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

-- Texture t at (x, y) (its bottom left on WorldFrame), w x h units, with its 8 texture coordinates and
-- colour (r, g, b, a): only what changed is sent to the client (a move or resize under a third of a
-- unit, a coordinate under 1e-5, an opacity under 0.004 are let be), as Core's pieces do. Each call
-- costs, much more so in the browser version; a ring that holds still costs next to nothing.
function LAB.Place(t, x, y, w, h, a1, a2, a3, a4, a5, a6, a7, a8, r, g, b, a)
	local abs = math.abs;
	if ( not t.lx or abs(t.lx - x) > 0.33 or abs(t.ly - y) > 0.33 ) then
		t:ClearAllPoints();
		t:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", x, y);
		t.lx, t.ly = x, y;
	end
	if ( not t.lw or abs(t.lw - w) > 0.33 or abs(t.lh - h) > 0.33 ) then
		t:SetWidth(w);
		t:SetHeight(h);
		t.lw, t.lh = w, h;
	end
	local c = t.ltc;
	if ( not c ) then
		c = {};
		t.ltc = c;
	end
	local e = 1e-5;
	if ( not c[1] or abs(c[1] - a1) > e or abs(c[2] - a2) > e or abs(c[3] - a3) > e or abs(c[4] - a4) > e
		or abs(c[5] - a5) > e or abs(c[6] - a6) > e or abs(c[7] - a7) > e or abs(c[8] - a8) > e ) then
		t:SetTexCoord(a1, a2, a3, a4, a5, a6, a7, a8);
		c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8] = a1, a2, a3, a4, a5, a6, a7, a8;
	end
	if ( t.lr ~= r or t.lg ~= g or t.lb ~= b or not t.la or abs(t.la - a) > 0.004 ) then
		t:SetVertexColor(r, g, b, a);
		t.lr, t.lg, t.lb, t.la = r, g, b, a;
	end
end

function LAB.Ground(path, cu, cv, R, rot, c, alpha, blend, over)
	if ( R <= 0 or alpha <= 0.003 ) then
		return nil;
	end
	local cx, cy, ax, ay, bx, by = LAB.Fit(cu, cv, R, rot);
	if ( not cx ) then
		return nil;
	end
	local det = ax * by - ay * bx;
	if ( math.abs(det) < 1e-6 ) then
		return nil;
	end
	local hw, hh = math.abs(ax) + math.abs(bx), math.abs(ay) + math.abs(by);
	local t = LAB.Tex(path, blend, over);
	-- a corner (dx, dy) from the middle: s = (dx by - dy bx) / det, q = (ax dy - ay dx) / det; the
	-- texture's x = 0.5 + s / 2, its y (top to bottom) 0.5 - q / 2 (no closure made per call)
	local ux, uy = 0.5 * by / det * hw, -0.5 * bx / det * hh;
	local vx, vy = 0.5 * ay / det * hw, -0.5 * ax / det * hh;
	LAB.Place(t, cx - hw, cy - hh, 2 * hw, 2 * hh, 0.5 - ux + uy, 0.5 - vx + vy, 0.5 - ux - uy, 0.5 - vx - vy,
		0.5 + ux + uy, 0.5 + vx + vy, 0.5 + ux - uy, 0.5 + vx - vy, c[1], c[2], c[3], math.min(1, (c[4] or 1) * alpha));
	return t;
end

-- A texture upright on the screen at screen point (x, y), w x h units (a flash, a spark).
function LAB.Screen(path, x, y, w, h, c, alpha, blend, over)
	if ( not x or alpha <= 0.003 ) then
		return nil;
	end
	local t = LAB.Tex(path, blend, over);
	LAB.Place(t, x - w / 2, y - h / 2, w, h, 0, 0, 0, 1, 1, 0, 1, 1, c[1], c[2], c[3], math.min(1, (c[4] or 1) * alpha));
	return t;
end

-- /ast lab ...: what the experiments add to the commands.
LAB.commands = {};
-- /ast lab tab: the Lab's tab in the options, hidden to start with (its experiments are for trying out)
LAB.commands.tab = function()
	local db = AST.State();
	db.labTab = not db.labTab or nil;
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: the Lab tab is " .. ( db.labTab and "shown" or "hidden" ) .. " in the options.");
	AST.RefreshOptions();
end
function LAB.Command(rest)
	-- (spaces by hand: the %s class misreads text under some code pages)
	local _, _, cmd, args = string.find(rest or "", "^([^ ]*) *(.-)$");
	local f = LAB.commands[cmd or ""];
	if ( f ) then
		f(args);
	else
		local names = {};
		for k in pairs(LAB.commands) do
			table.insert(names, k);
		end
		table.sort(names);
		DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: /ast lab " .. table.concat(names, " | "));
	end
end

---------------------------------------------------------------------------------------------
-- True circles: Core's own fills and outlines, smooth (on to start with). A whole circle is one
-- stretched round piece; every outline is round pieces close together along a fine path, so rings
-- have no flat sides and no steps. Off: the old way, to compare.

AST_Lab{
	-- hidden, and turned off once for everyone (LabTextures.lua; the user, 2026-11-25: it looks
	-- amazing but costs too much to run smoothly, to be made cheaper later)
	id = "lab_true", name = "True circles", kind = "Polish", hidden = true,
	desc = "Smooth, true circles: fills in one piece, outlines with no flat sides or steps.",
	applies = "Every ring, cone and spot in the Smooth style, the Lab's too.",
	demo = function(t, j, p, now)
		local st = { line = { 1, 0.85, 0.35, 1 }, fill = { 1, 0.8, 0.3, 0.3 }, width = 3, glow = true, strip = 3, style = "smooth" };
		local k = t - math.floor(t / 1.5) * 1.5;
		AST.draw.Circle(0, 0, 8, st, j.alpha, k / 1.5, k);
		AST.draw.Circle(0, 0, 25, { line = { 0.55, 0.8, 1, 0.8 }, fill = { 0.55, 0.8, 1, 0 }, width = 2, glow = true, strip = 3, style = "smooth" }, j.alpha);
	end,
};

---------------------------------------------------------------------------------------------
-- FPS counter, for testing: the frame rate, a frame's time, what the telegraphs take of it, and how
-- many pieces they draw. Twice a second, averaged; drag it where you like. /ast lab fps: on or off.

local fps;

local function BuildFps()
	fps = CreateFrame("Frame", "ASTLabFps", UIParent);
	fps:SetWidth(430);
	fps:SetHeight(22);
	fps:SetFrameStrata("DIALOG");
	fps:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		insets = { left = 0, right = 0, top = 0, bottom = 0 } });
	fps:SetBackdropColor(0, 0, 0, 0.6);
	local db = AST.State();
	local pos = db.labFps;
	if ( type(pos) == "table" and pos.point ) then
		fps:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y);
	else
		fps:SetPoint("TOP", UIParent, "TOP", 0, -40);
	end
	fps:EnableMouse(true);
	fps:SetMovable(true);
	fps:RegisterForDrag("LeftButton");
	fps:SetScript("OnDragStart", function() fps:StartMoving(); end);
	fps:SetScript("OnDragStop", function()
		fps:StopMovingOrSizing();
		local point, _, rel, x, y = fps:GetPoint();
		AST.State().labFps = { point = point, rel = rel, x = x, y = y };
	end);
	fps.text = fps:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	fps.text:SetPoint("CENTER", fps, "CENTER", 0, 0);
	fps.frames, fps.time, fps.acc = 0, 0, 0;
	fps:SetScript("OnUpdate", function()
		local dt = arg1 or 0;
		fps.frames, fps.time, fps.acc = fps.frames + 1, fps.time + dt, fps.acc + dt;
		if ( fps.acc < 0.5 ) then
			return;
		end
		local rate = fps.time > 0 and fps.frames / fps.time or 0;
		if ( GetFramerate ) then
			local ok, r = pcall(GetFramerate);
			if ( ok and type(r) == "number" and r > 0 ) then
				rate = r;
			end
		end
		local frameMs = fps.frames > 0 and fps.time * 1000 / fps.frames or 0;
		local avg = timing.n > 0 and timing.sum / timing.n or 0;
		local _, quads = AST.Stats();
		local round = AST.draw and AST.draw.H and AST.draw.H.round;
		fps.text:SetText(string.format("%d FPS  |  frame %.1f ms  |  telegraphs %.2f ms (worst %.1f)  |  %d pieces  |  true circles %s",
			math.floor(rate + 0.5), frameMs, avg, timing.most, quads or 0, round and "on" or "off"));
		fps:SetWidth(math.max(200, (fps.text:GetStringWidth() or 400) + 20));
		fps.frames, fps.time, fps.acc = 0, 0, 0;
		timing.sum, timing.most, timing.n = 0, 0, 0;
	end);
end

-- Shown while its Lab entry is on (looked at twice a second, so it follows the options at once).
local watcher = CreateFrame("Frame");
local watchAcc = 0;
watcher:SetScript("OnUpdate", function()
	watchAcc = watchAcc + (arg1 or 0);
	if ( watchAcc < 0.5 ) then
		return;
	end
	watchAcc = 0;
	local db, _, _, _, byId = AST.State();
	if ( not db ) then
		return;
	end
	local def = byId and byId.lab_fps;
	local on = def and AST.Settings(def).enabled;
	if ( on and not fps ) then
		BuildFps();
	end
	if ( fps ) then
		if ( on ) then
			fps:Show();
		else
			fps:Hide();
		end
	end
end);

AST_Lab{
	id = "lab_fps", name = "FPS counter", kind = "Tools",
	desc = "For testing: frame rate, what the telegraphs take of each frame, and their pieces.",
	applies = "A bar at the top of the screen; drag it anywhere. /ast lab fps turns it on or off.",
};

LAB.commands.fps = function()
	local _, _, _, _, byId = AST.State();
	local def = byId and byId.lab_fps;
	if ( def ) then
		local st = AST.Settings(def);
		st.enabled = not st.enabled;
		DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: FPS counter " .. (st.enabled and "on." or "off."));
	end
end;
