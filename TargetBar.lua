-- Azeroth Survivors Telegraphs: the target bar. The enemy you target on a bar like the hero bar:
-- its health (the game's own numbers for it), its name and kind (elite, guardian, boss), its mana,
-- and its debuffs and buffs with their stacks, and their time left where the game tells it (a
-- guardian's and a boss's). Every part has a switch on its page (Target bar), with the hero
-- bar's three looks to start from. It goes where you drag it, or beside the hero bar.
--
-- Where the numbers come from: the game's target line (AZS_TARGET: kind, id, name, hp, hpm, state,
-- elite) for its health and kind, else UnitHealth / UnitHealthMax (then only a share, of 100);
-- UnitDebuff / UnitBuff for its debuffs and buffs; a guardian's or a boss's debuffs, with their
-- times, from AZS_GetDebuffs(its id).

local T = { icons = {}, shown = {} };
AST.tbar = T;

local SOLID = "Interface\\Buttons\\WHITE8X8";
local SHADED = "Interface\\TargetingFrame\\UI-StatusBar";
local GLOW = "Spells\\GENERICGLOW64";
local POWER = { [0] = { 0.25, 0.5, 1 }, [1] = { 0.9, 0.2, 0.2 }, [2] = { 1, 0.5, 0.25 }, [3] = { 1, 0.85, 0.2 } };
-- a debuff's edge by what can take it off, in the colours the game's own frames use
local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } };
local NODISPEL = { 0.8, 0, 0 };
local KIND_KEY = { normal = "kindNormal", elite = "kindElite", guardian = "kindGuardian", boss = "kindBoss", friend = "kindFriend" };

-- Every setting and where it starts (the Sleek look).
local DEF = {
	-- off to start with, as the hero bar; anchor "screen" (where you put it) or "bar" (beside the
	-- hero bar, on `side`, `gap` px away)
	on = false, locked = true, anchor = "screen", point = "BOTTOM", rel = "BOTTOM", x = 260, y = 190,
	side = "right", gap = 14,
	width = 200, height = 14, scale = 1, alpha = 1,
	look = "sleek", texture = "shaded",
	-- its colour: "kind" (by what it is), "health" (green to red) or "custom"
	healthColor = "kind", healthRGB = { 0.8, 0.25, 0.2 },
	kindNormal = { 0.78, 0.22, 0.18 }, kindElite = { 0.95, 0.62, 0.15 }, kindGuardian = { 0.68, 0.38, 0.95 },
	kindBoss = { 0.95, 0.15, 0.35 }, kindFriend = { 0.3, 0.8, 0.4 },
	bgAlpha = 0.55, border = true, gloss = true, sheen = true, smooth = true, trail = true,
	-- execute range: a mark at execAt % and the bar lit below it (0: off)
	execAt = 0, execRGB = { 1, 0.82, 0.2 },
	text = "percent", textSize = 11, textPos = "center",
	name = true, namePos = "above", nameSize = 11, nameColor = "kind", kindTag = true, tot = false,
	-- its kind's word: "row" (on a second row, beyond the name's, at its left) or "name" (after the
	-- name, the first to go when the line is too long); whom it's after: "name" (on the name's row, at
	-- its right), "row" (on the second row, at its right) or "auto" (the name's row, moving up when the
	-- name doesn't fit beside it). A name too long for its row is shortened ("...").
	kindAt = "row", totAt = "name",
	-- whom it's after (the user, 2026-11-26: not ">"): marked by "sword" (the game's attack cursor),
	-- "arrow" (a small one), "word" ("Target: name") or "none"; a teammate in their class's colour; you
	-- as "You" in totYouRGB
	totMark = "sword", totClass = true, totYou = true, totYouRGB = { 1, 0.32, 0.25 },
	power = false, powerHeight = 4,
	-- its level: "name" (before its name), "after" (after it), "left" (a part at the bar's left end,
	-- inside its border) or "inside"
	level = false, levelPos = "name", levelSize = 11, levelRGB = { 1, 0.82, 0.2 },
	debuffs = true, debuffsMax = 16, debuffSize = 20, debuffSide = "above", debuffAlign = "left",
	buffs = true, buffsMax = 8, buffSize = 18, buffSide = "below", buffAlign = "left",
	auraGap = 2, perRow = 8, stacks = true, timers = true, shade = true, typeColor = true, tips = false,
	v = 1,
};

-- The three looks, as the hero bar's: what each sets (its place, what it shows and its colours by
-- kind stay yours).
T.LOOKS = {
	subdued = { width = 180, height = 8, alpha = 0.85, texture = "flat", healthColor = "custom", healthRGB = { 0.62, 0.36, 0.34 },
		bgAlpha = 0.35, border = false, gloss = false, sheen = false, smooth = true, trail = false, text = "none",
		nameSize = 10, powerHeight = 3, debuffSize = 16, buffSize = 14, auraGap = 2 },
	sleek = { width = 200, height = 14, alpha = 1, texture = "shaded", healthColor = "kind", bgAlpha = 0.55, border = true,
		gloss = true, sheen = true, smooth = true, trail = true, text = "percent", textSize = 11, nameSize = 11,
		powerHeight = 4, debuffSize = 20, buffSize = 18, auraGap = 2 },
	bold = { width = 260, height = 20, alpha = 1, texture = "shaded", healthColor = "kind", bgAlpha = 0.7, border = true,
		gloss = true, sheen = true, smooth = true, trail = true, text = "full", textSize = 13, nameSize = 13,
		powerHeight = 6, debuffSize = 26, buffSize = 22, auraGap = 3 },
};

local function Copy(v)
	if ( type(v) == "table" ) then
		return { v[1], v[2], v[3], v[4] };
	end
	return v;
end

-- Its settings, the defaults filled in (nil before the saved settings are there).
function T.S()
	local db = AST.State();
	if ( not db ) then
		return nil;
	end
	local s = db.tbar;
	if ( not s ) then
		s = {};
		db.tbar = s;
	end
	if ( T.filled ~= s ) then
		for k, v in pairs(DEF) do
			if ( s[k] == nil ) then
				s[k] = Copy(v);
			end
		end
		T.filled = s;
	end
	return s;
end

function T.Defaults()
	return DEF;
end

function T.ApplyLook(name)
	local s, look = T.S(), T.LOOKS[name];
	if ( not ( s and look ) ) then
		return;
	end
	for k, v in pairs(look) do
		s[k] = Copy(v);
	end
	s.look = name;
end

-- Everything back as it started (its place too).
function T.Reset()
	local db = AST.State();
	if ( db ) then
		db.tbar = nil;
		T.S();
	end
	T.hp, T.trail, T.who, T.names = nil, nil, nil, nil;
end

---------------------------------------------------------------------------------------------
-- The frame and its pieces

local f;          -- the frame
local P = {};     -- its textures and texts by name

local function Font(fs, size)
	local path = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
	if ( fs.size ~= size ) then
		fs:SetFont(path, size, "OUTLINE");
		fs.size = size;
	end
end

-- A text, sent only when it changed.
local function Say(fs, text)
	if ( fs.said ~= text ) then
		fs:SetText(text);
		fs.said = text;
	end
end

local function Tex(layer, path, blend)
	local t = f:CreateTexture(nil, layer);
	t:SetTexture(path);
	t.path = path;
	if ( blend and t.SetBlendMode ) then
		t:SetBlendMode(blend);
	end
	t:Hide();
	t.on = false;
	return t;
end

-- Texture t at (x, y) from the frame's bottom left, w x h, coloured: only what changed is sent.
local function Put(t, x, y, w, h, r, g, b, a)
	if ( w < 0.5 or h < 0.5 or a <= 0.004 ) then
		if ( t.on ) then
			t:Hide();
			t.on = false;
		end
		return;
	end
	x, y = math.floor(x * 2 + 0.5) / 2, math.floor(y * 2 + 0.5) / 2;
	w, h = math.floor(w * 2 + 0.5) / 2, math.floor(h * 2 + 0.5) / 2;
	if ( t.x ~= x or t.y ~= y ) then
		t:ClearAllPoints();
		t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y);
		t.x, t.y = x, y;
	end
	if ( t.w ~= w ) then
		t:SetWidth(w);
		t.w = w;
	end
	if ( t.h ~= h ) then
		t:SetHeight(h);
		t.h = h;
	end
	if ( t.r ~= r or t.g ~= g or t.b ~= b or not t.a or math.abs(t.a - a) > 0.004 ) then
		t:SetVertexColor(r, g, b, math.min(1, a));
		t.r, t.g, t.b, t.a = r, g, b, a;
	end
	if ( not t.on ) then
		t:Show();
		t.on = true;
	end
end

local function Coords(t, l, r, top, bottom)
	if ( t.l ~= l or t.rr ~= r or t.tt ~= top or t.bb ~= bottom ) then
		t:SetTexCoord(l, r, top, bottom);
		t.l, t.rr, t.tt, t.bb = l, r, top, bottom;
	end
end

local function Off(t)
	if ( t.on ) then
		t:Hide();
		t.on = false;
	end
end

local function Make()
	f = CreateFrame("Frame", "ASTTargetBar", UIParent);
	f:SetFrameStrata("MEDIUM");
	f:SetWidth(200);
	f:SetHeight(14);
	f:SetMovable(true);
	if ( f.SetClampedToScreen ) then
		f:SetClampedToScreen(true);
	end
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", function()
		local s = T.S();
		if ( s and not s.locked ) then
			f.dragging = true;
			f:StartMoving();
		end
	end);
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing();
		f.dragging = nil;
		-- the addon keeps where it goes, not the game (as the hero bar)
		if ( f.SetUserPlaced ) then
			f:SetUserPlaced(false);
		end
		local s = T.S();
		if ( s ) then
			-- kept as its centre, in the screen's units: a new scale grows it round its middle
			local sc = ( f.GetScale and f:GetScale() ) or 1;
			local cx, cy = f:GetCenter();
			if ( cx and cy ) then
				s.point, s.rel, s.x, s.y = "CENTER", "BOTTOMLEFT", cx * sc, cy * sc;
			end
			s.anchor = "screen";
			f.where = nil;
		end
	end);
	f:SetScript("OnMouseUp", function()
		local s = T.S();
		if ( s and arg1 == "RightButton" ) then
			s.locked = true;
			if ( AST.RefreshOptions ) then
				AST.RefreshOptions();
			end
		end
	end);
	-- back to front
	P.bg = Tex("BACKGROUND", SOLID);
	for _, side in ipairs({ "edgeT", "edgeB", "edgeL", "edgeR" }) do
		P[side] = Tex("BORDER", SOLID);
	end
	P.powerBg = Tex("BORDER", SOLID);
	P.trail = Tex("ARTWORK", SOLID);
	P.fill = Tex("ARTWORK", SHADED);
	P.gloss = Tex("ARTWORK", SOLID);
	P.exec = Tex("ARTWORK", SOLID, "ADD");
	P.sheen = Tex("ARTWORK", GLOW, "ADD");
	P.power = Tex("ARTWORK", SHADED);
	P.mark = Tex("OVERLAY", SOLID);
	P.handle = Tex("OVERLAY", SOLID);
	P.levelBg = Tex("BORDER", SOLID);
	P.levelLine = Tex("ARTWORK", SOLID);
	P.totIcon = Tex("OVERLAY", "Interface\\Cursor\\Attack");
	P.levelFs = f:CreateFontString(nil, "OVERLAY");
	Font(P.levelFs, 11);
	P.text = f:CreateFontString(nil, "OVERLAY");
	P.name = f:CreateFontString(nil, "OVERLAY");
	P.tot = f:CreateFontString(nil, "OVERLAY");
	P.kind = f:CreateFontString(nil, "OVERLAY");
	P.hint = f:CreateFontString(nil, "OVERLAY");
	-- never shown: measures texts, so what's on screen isn't touched
	P.meas = f:CreateFontString(nil, "OVERLAY");
	P.meas:Hide();
	Font(P.text, 11);
	Font(P.name, 11);
	Font(P.tot, 10);
	Font(P.kind, 10);
	Font(P.hint, 10);
	if ( P.name.SetJustifyH ) then
		P.name:SetJustifyH("LEFT");
	end
	T.frame, T.P = f, P;
end

---------------------------------------------------------------------------------------------
-- What it shows: read from the game, or the Test demo's

-- What the game calls it, as one of the frame's kinds.
local function Kind(k, elite)
	if ( k == "final" or k == "finalBoss" ) then
		return "boss";
	end
	if ( k == "boss" or k == "guardian" or k == "elite" ) then
		return k;
	end
	if ( elite == 1 or elite == true or elite == "1" ) then
		return "elite";
	end
	return "normal";
end

local function IconPath(p)
	if ( type(p) ~= "string" or p == "" ) then
		return nil;
	end
	if ( not string.find(p, "\\", 1, true) ) then
		return "Interface\\Icons\\" .. p;
	end
	return p;
end

-- The demo: an enemy worn down past its execute range, debuffs ticking down, a buff on it.
local function Demo(t)
	local k = math.max(0, math.min(1, (t - 0.5) / 6));
	local hp = 1 - 0.86 * k;
	if ( t > 2 and t < 2.2 ) then
		hp = hp - 0.08;
	end
	local d = { name = AST_L("Test enemy"), hp = math.max(0.02, hp) * 12000, mx = 12000, exact = true, kind = "guardian",
		pw = 60 + 30 * math.sin(t), pmx = 100, ptype = 0, demo = true, level = 14 };
	d.tot = UnitName and UnitName("player") or nil;
	d.totYou = true;
	local deb = {
		{ tex = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", stacks = 3, left = 18 - t, max = 18, type = "Magic" },
		{ tex = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", stacks = 1, type = "Curse" },
		{ tex = "Interface\\Icons\\Spell_Fire_Immolation", stacks = 1, left = 12 - t * 1.2, max = 12 },
	};
	if ( t < 5 ) then
		table.insert(deb, 2, { tex = "Interface\\Icons\\Spell_Frost_FrostNova", stacks = 1, left = 5 - t, max = 5, type = "Magic" });
	end
	d.debuffs = deb;
	d.buffs = { { tex = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", stacks = 1, buff = true } };
	return d;
end

function T.Testing()
	return T.test ~= nil and GetTime() < T.test;
end

-- A Test press: the demo for 8 sec (shown even while it's off; your settings unchanged); a second
-- press while it plays stops it.
function T.Test()
	if ( T.Testing() ) then
		T.test = nil;
	else
		T.test = GetTime() + 8;
	end
	T.hp, T.trail, T.who = nil, nil, nil;
end

-- A guardian or boss by its name in the game's list of them (AZS_UNITS): its kind, and its id when only
-- one has that name. Asked before the game's target line has come for a new target (a moment after you
-- target it): the client alone calls a guardian "elite" (the user, 2026-11-26: "a breif moment when
-- selecting a guardian ect where its bar is orange and elite is visible").
local function Listed(name)
	local list = AZS_UNITS;
	if ( type(list) ~= "table" or not name ) then
		return nil;
	end
	local kind, id, n = nil, nil, 0;
	for i = 1, table.getn(list) do
		local u = list[i];
		if ( u.name == name and ( u.kind == "guardian" or u.kind == "boss" or u.kind == "final" or u.kind == "finalBoss" ) ) then
			kind, id, n = u.kind, u.id, n + 1;
		end
	end
	return kind, ( n == 1 ) and id or nil;
end

-- A hero's class key ("WARRIOR"...) by name: from the game's party line (its `class` the class's key;
-- this client's UnitClass has named the wrong class), else, for you, the run's class number.
local CLASS_IDS = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST", [7] = "SHAMAN",
	[8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" };
-- the classes' colours (the shaman in its later blue, as Survivor UI has it)
local CLASS_RGB = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.41, 0.8, 0.94 },
	WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1, 0.49, 0.04 } };
-- whom it's after: its marks (the game's attack cursor, the chat frame's small arrow), its plain colour
local TOT_MARKS = { sword = "Interface\\Cursor\\Attack", arrow = "Interface\\ChatFrame\\ChatFrameExpandArrow" };
local TOT_RGB = { 0.85, 0.85, 0.9 };
local function ClassOf(name, you)
	local function Key(c)
		if ( tonumber(c) ) then
			return CLASS_IDS[tonumber(c)];
		elseif ( type(c) == "string" and c ~= "" ) then
			-- (A-Z by hand: string.upper rewrites UTF-8 bytes under a code page)
			return ( string.gsub(c, "[a-z]", function(ch) return string.char(string.byte(ch) - 32); end) );
		end
		return nil;
	end
	local list = AZS_PARTY;
	if ( type(list) == "table" and name ) then
		for i = 1, table.getn(list) do
			if ( list[i].name == name ) then
				return Key(list[i].class);
			end
		end
	end
	if ( you and type(AZS_ZONE) == "table" ) then
		return Key(AZS_ZONE.class);
	end
	return nil;
end

-- Your target now: { name, hp, mx, exact, kind, id, dead, pw, pmx, ptype, tot, totYou, totClass }, nil
-- with none.
function T.Read()
	if ( T.Testing() ) then
		return Demo(8 - (T.test - GetTime()));
	end
	if ( not ( UnitExists and UnitExists("target") ) ) then
		return nil;
	end
	local d = { name = UnitName and UnitName("target") or "" };
	d.hp = UnitHealth and UnitHealth("target") or 0;
	d.mx = UnitHealthMax and UnitHealthMax("target") or 0;
	local tg = AZS_TARGET;
	local own = type(tg) == "table" and tg.name ~= nil and tg.name == d.name;
	if ( own and ( tonumber(tg.hpm) or 0 ) > 0 ) then
		-- the game's own numbers for it
		d.hp, d.mx, d.exact = tonumber(tg.hp) or 0, tonumber(tg.hpm), true;
	else
		-- the client alone gives an enemy's health as a share of 100
		d.exact = d.mx ~= 100;
	end
	if ( UnitIsFriend and UnitIsFriend("player", "target") ) then
		d.kind = "friend";
	elseif ( own ) then
		d.kind, d.id = Kind(tg.kind, tg.elite), tg.id;
	else
		local kind, id = Listed(d.name);
		if ( kind ) then
			d.kind, d.id = Kind(kind), id;
		else
			d.kind = Kind(AZS_UnitKind and AZS_UnitKind("target"));
		end
	end
	d.dead = ( UnitIsDead and UnitIsDead("target") ) and true or false;
	d.level = UnitLevel and UnitLevel("target");
	d.pw = UnitMana and UnitMana("target") or 0;
	d.pmx = UnitManaMax and UnitManaMax("target") or 0;
	d.ptype = UnitPowerType and UnitPowerType("target") or 0;
	if ( UnitExists("targettarget") and UnitName ) then
		d.tot = UnitName("targettarget");
		d.totYou = ( UnitIsUnit and UnitIsUnit("targettarget", "player") ) or d.tot == UnitName("player");
		d.totClass = ClassOf(d.tot, d.totYou);
	end
	return d;
end

-- Its debuffs and buffs: { tex, stacks, left, max, type, index, buff } each. A guardian's or a
-- boss's debuffs as the game lists them, with their times; any other's as the client has them.
function T.Auras(d)
	if ( d.debuffs ) then
		return d.debuffs, d.buffs or {};
	end
	local deb, buf = {}, {};
	if ( d.id and ( d.kind == "guardian" or d.kind == "boss" ) and AZS_GetDebuffs ) then
		local ok, list = pcall(AZS_GetDebuffs, d.id);
		if ( ok and type(list) == "table" ) then
			for i = 1, table.getn(list) do
				local e = list[i];
				local tex = IconPath(e.icon);
				if ( tex ) then
					table.insert(deb, { tex = tex, stacks = tonumber(e.stacks), left = e.remaining, max = e.duration,
						type = e.dispelType, name = e.name });
				end
			end
		end
	end
	if ( table.getn(deb) == 0 and UnitDebuff ) then
		for i = 1, 40 do
			local tex, count, kind = UnitDebuff("target", i);
			if ( not tex ) then
				break;
			end
			table.insert(deb, { tex = tex, stacks = count, type = kind, index = i });
		end
	end
	if ( UnitBuff ) then
		for i = 1, 32 do
			local tex, count = UnitBuff("target", i);
			if ( not tex ) then
				break;
			end
			table.insert(buf, { tex = tex, stacks = count, index = i, buff = true });
		end
	end
	return deb, buf;
end

---------------------------------------------------------------------------------------------
-- Drawing it

local function Mix(a, b, t)
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t;
end

local GREEN, YELLOW, RED, WHITE, GREY = { 0.25, 0.82, 0.35 }, { 1, 0.82, 0.2 }, { 0.92, 0.22, 0.16 }, { 1, 1, 1 }, { 0.45, 0.45, 0.45 };

-- Its kind's colour (yours for it).
local function KindColor(s, kind)
	return s[KIND_KEY[kind] or "kindNormal"] or s.kindNormal;
end

local function HealthColor(s, d, frac)
	if ( d.dead ) then
		return GREY[1], GREY[2], GREY[3];
	elseif ( s.healthColor == "custom" ) then
		return s.healthRGB[1], s.healthRGB[2], s.healthRGB[3];
	elseif ( s.healthColor == "health" ) then
		if ( frac > 0.5 ) then
			return Mix(YELLOW, GREEN, (frac - 0.5) / 0.5);
		end
		return Mix(RED, YELLOW, frac / 0.5);
	end
	local c = KindColor(s, d.kind);
	return c[1], c[2], c[3];
end

-- A soft light sweeping across a stretch x0..x1 every `period` sec, clipped to the stretch.
local function Sweep(t, x0, x1, y, h, c, a, now, period, speed)
	local sw = math.max(24, h * 3);
	local k = now - math.floor(now / period) * period;
	local px = x0 - sw + k * speed;
	local vx0, vx1 = math.max(px, x0), math.min(px + sw, x1);
	if ( vx1 - vx0 < 1 or px > x1 ) then
		Off(t);
		return;
	end
	Coords(t, (vx0 - px) / sw, (vx1 - px) / sw, 0.3, 0.7);
	Put(t, vx0, y, vx1 - vx0, h, c[1], c[2], c[3], a);
end

-- The numbers: as chosen, a share only where the game gives none.
local function Numbers(s, d)
	if ( d.dead ) then
		return AST_L("Dead");
	end
	local pct = d.mx > 0 and math.floor(d.hp / d.mx * 100 + 0.5) or 0;
	local mode = s.text;
	if ( not d.exact and mode ~= "none" ) then
		mode = "percent";
	end
	if ( mode == "percent" ) then
		return pct .. "%";
	elseif ( mode == "current" ) then
		return tostring(math.floor(d.hp + 0.5));
	elseif ( mode == "both" ) then
		return math.floor(d.hp + 0.5) .. " / " .. math.floor(d.mx + 0.5);
	elseif ( mode == "full" ) then
		return math.floor(d.hp + 0.5) .. " / " .. math.floor(d.mx + 0.5) .. "  (" .. pct .. "%)";
	end
	return "";
end

-- "|cffrrggbb": a colour code for a text.
local function Hex(c, light)
	local k = light or 0;
	local function H(v)
		local n = math.floor(math.max(0, math.min(1, v + (1 - v) * k)) * 255 + 0.5);
		return string.format("%02x", n);
	end
	return "|cff" .. H(c[1]) .. H(c[2]) .. H(c[3]);
end

-- Its kind's word, in the game's language (none for an ordinary enemy or a friend).
local function KindWord(kind)
	if ( kind == "elite" ) then
		return AST_L("Elite");
	elseif ( kind == "guardian" ) then
		return AST_L("Guardian");
	elseif ( kind == "boss" ) then
		return AST_L("Boss");
	end
	return nil;
end

-- Its level as shown: the number, "??" where the game hides it (-1), nil with none.
local function LevelText(d)
	local lv = tonumber(d.level);
	if ( lv == -1 ) then
		return "??";
	elseif ( lv and lv > 0 ) then
		return tostring(lv);
	end
	return nil;
end

-- s less its last character (UTF-8: a character's other bytes are 0x80-0xBF), for names in any
-- language.
local function DropLast(str)
	local n = string.len(str);
	while ( n > 0 ) do
		local byte = string.byte(str, n);
		n = n - 1;
		if ( byte < 128 or byte >= 192 ) then
			break;
		end
	end
	return string.sub(str, 1, n);
end

-- Where its level goes now: "name" (before its name), "after" (after it), "row" (at the left of the
-- row beyond the name's, before its kind's word: the user, 2026-11-26, "level should also be able to
-- go uptop with guardian"), "left" (a part at the bar's left end) or "inside". With its name off, the
-- name's places are the part at the bar's end; with the name inside the bar, there's no row: before it.
local function LevelAt(s)
	local at = s.levelPos;
	if ( ( at == "name" or at == "after" or at == "row" ) and not s.name ) then
		return "left";
	elseif ( at == "row" and s.namePos == "inside" ) then
		return "name";
	end
	return at;
end

-- How wide a text is at a size (0 where the client can't say).
local function Wide(text, size)
	local m = P.meas;
	Font(m, size);
	m:SetText(text);
	return ( m.GetStringWidth and m:GetStringWidth() ) or 0;
end

-- Its name line, all on one line within `room` px (the user's players, 2026-11-26: a long name went
-- onto a second line, its level left on the first): its level before or after the name if it goes
-- with it (a space between: "a little smaller"), the name (in its kind's colour, or white), and with
-- `withWord` its kind's word. Too long: the kind's word goes first, then the name loses letters from
-- its end ("..."). Gives the text and whether it all fitted as it was. Kept for each set of parts.
local function NameLine(s, d, room, withWord)
	local hc = Hex(s.nameColor == "kind" and KindColor(s, d.kind) or WHITE, 0.35);
	local at = LevelAt(s);
	local lv = s.level and ( at == "name" or at == "after" ) and LevelText(d);
	local lc = Hex(s.levelRGB);
	local word = withWord and s.kindTag and KindWord(d.kind);
	local wc = Hex(KindColor(s, d.kind), 0.1);
	local key = table.concat({ d.name or "", tostring(lv), at, tostring(word), hc, lc, wc, tostring(room), s.nameSize }, "|");
	local kept = T.names and T.names[key];
	if ( kept ) then
		return kept[1], kept[2];
	end
	local function Build(name, withIt)
		local text = hc .. name .. "|r";
		if ( lv and at == "after" ) then
			text = text .. " " .. lc .. lv .. "|r";
		elseif ( lv ) then
			text = lc .. lv .. "|r " .. text;
		end
		if ( withIt and word ) then
			text = text .. "  " .. wc .. word .. "|r";
		end
		return text;
	end
	local function Fits(text)
		return Wide(text, s.nameSize) <= room;
	end
	-- (no width of its own: it never wraps)
	if ( P.name.SetWidth ) then
		P.name:SetWidth(0);
	end
	local name = d.name or "";
	local text, whole = Build(name, true), true;
	if ( not Fits(text) ) then
		whole = false;
		text = Build(name, false);
		local cut = name;
		while ( not Fits(text) and string.len(cut) > 0 ) do
			cut = DropLast(cut);
			-- (no space before the dots; a plain space, not %s: game text under a code page)
			local shown = string.gsub(cut, " +$", "");
			text = Build(shown .. "...", false);
		end
	end
	if ( not T.names or T.nameCount > 40 ) then
		T.names, T.nameCount = {}, 0;
	end
	T.names[key] = { text, whole };
	T.nameCount = T.nameCount + 1;
	return text, whole;
end

-- Its level as a part at the bar's left end (LevelAt "left"): its text set, and how wide the part is
-- (0: none). Drawn as part of the bar: its background, a line between, the border round both (the
-- user's players: a box apart with a gap was "gross").
local function LevelPart(s, d, H)
	local lv = s.level and LevelAt(s) == "left" and LevelText(d);
	if ( not lv ) then
		return 0;
	end
	local fs = P.levelFs;
	Font(fs, s.levelSize);
	Say(fs, lv);
	local tw = ( fs.GetStringWidth and fs:GetStringWidth() ) or s.levelSize * 0.6 * string.len(lv);
	-- just the number with a little room round it (players: "thinner width wise, basically just
	-- housing the number")
	return math.floor(math.max(tw + 6, s.levelSize * 0.8) + 0.5);
end

-- Its level by the bar: the part at its left end (lw px wide), inside it at its left, or at the left of
-- the row beyond its name's.
local function Level(s, d, W, H, y0, a, lw)
	local at = LevelAt(s);
	local lv = s.level and LevelText(d);
	if ( not lv or ( at ~= "left" and at ~= "inside" and at ~= "row" ) ) then
		Off(P.levelBg);
		Off(P.levelLine);
		P.levelFs:Hide();
		return;
	end
	local fs, c = P.levelFs, s.levelRGB;
	Font(fs, s.levelSize);
	Say(fs, lv);
	fs:SetTextColor(c[1], c[2], c[3], a);
	fs:ClearAllPoints();
	if ( at == "inside" ) then
		fs:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
		Off(P.levelBg);
		Off(P.levelLine);
	elseif ( at == "row" ) then
		if ( s.namePos == "below" ) then
			fs:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -( s.nameSize + 4 ));
		else
			fs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, s.nameSize + 4);
		end
		Off(P.levelBg);
		Off(P.levelLine);
	else
		Put(P.levelBg, -lw, 0, lw, H + y0, 0, 0, 0, a * math.max(s.bgAlpha, 0.35));
		Put(P.levelLine, -1, 0, 1, H + y0, 0.02, 0.02, 0.03, a * 0.9);
		fs:SetPoint("CENTER", f, "BOTTOMLEFT", -lw / 2, (H + y0) / 2);
	end
	fs:Show();
end

function T.Paint(d, now, dt)
	local s = T.S();
	local W, H = s.width, s.height;
	local ph = ( s.power and d.pmx and d.pmx > 0 ) and s.powerHeight or 0;
	local y0 = ph > 0 and ph + 1 or 0;
	if ( f.w ~= W or f.h ~= H + y0 ) then
		f:SetWidth(W);
		f:SetHeight(H + y0);
		f.w, f.h = W, H + y0;
	end
	local frac = d.mx > 0 and math.max(0, math.min(1, d.hp / d.mx)) or 0;
	-- a new target: shown at once, not eased from the last one's
	local who = tostring(d.name) .. ":" .. tostring(d.id);
	if ( T.who ~= who ) then
		T.who, T.hp, T.trail = who, frac, frac;
	end
	if ( s.smooth ) then
		T.hp = T.hp + (frac - T.hp) * math.min(1, dt * 12);
	else
		T.hp = frac;
	end
	if ( not s.trail or frac >= T.trail ) then
		T.trail, T.trailAt = frac, now;
	elseif ( now - (T.trailAt or now) > 0.35 ) then
		T.trail = math.max(frac, T.trail - dt * 0.9);
	end
	local a = s.alpha;
	local tex = s.texture == "flat" and SOLID or SHADED;
	if ( P.fill.path ~= tex ) then
		P.fill:SetTexture(tex);
		P.power:SetTexture(tex);
		P.fill.path, P.fill.l, P.power.l = tex, nil, nil;
	end
	local exec = s.execAt > 0 and not d.dead and frac < s.execAt / 100;
	local pulse = exec and ( 0.5 + 0.5 * math.sin(now * 6) ) or 0;
	-- its level as a part at its left end (lw px), inside its border
	local lw = LevelPart(s, d, H + y0);
	-- the frame round it
	Put(P.bg, 0, 0, W, H + y0, 0, 0, 0, a * s.bgAlpha);
	if ( s.border ) then
		-- a thin dark line round it, the execute colour while it's in range
		local ec = s.execRGB;
		local er, eg, eb = 0.02, 0.02, 0.03;
		if ( exec ) then
			er, eg, eb = ec[1] * (0.6 + 0.4 * pulse), ec[2] * (0.6 + 0.4 * pulse), ec[3] * (0.6 + 0.4 * pulse);
		end
		local th = exec and 2 or 1;
		Put(P.edgeB, -lw - th, -th, W + lw + 2 * th, th, er, eg, eb, a);
		Put(P.edgeT, -lw - th, H + y0, W + lw + 2 * th, th, er, eg, eb, a);
		Put(P.edgeL, -lw - th, 0, th, H + y0, er, eg, eb, a);
		Put(P.edgeR, W, 0, th, H + y0, er, eg, eb, a);
	else
		Off(P.edgeB);
		Off(P.edgeT);
		Off(P.edgeL);
		Off(P.edgeR);
	end
	-- health, what's draining, the gloss, the sweep of light
	local r, g, b = HealthColor(s, d, frac);
	if ( exec ) then
		-- in execute range the bar itself turns toward the execute colour, beating (a tint laid over it
		-- would muddy it)
		local ec, k = s.execRGB, 0.5 + 0.25 * pulse;
		r, g, b = r + (ec[1] - r) * k, g + (ec[2] - g) * k, b + (ec[3] - b) * k;
	end
	local fw = W * T.hp;
	if ( s.trail and T.trail > T.hp + 0.002 ) then
		Put(P.trail, fw, y0, W * (T.trail - T.hp), H, 1, 0.62, 0.4, a * 0.7);
	else
		Off(P.trail);
	end
	Coords(P.fill, 0, math.max(0.01, T.hp), 0, 1);
	Put(P.fill, 0, y0, fw, H, r, g, b, a);
	if ( s.gloss and P.gloss.SetGradientAlpha and fw > 1 ) then
		local gl = P.gloss;
		Put(gl, 0, y0 + H * 0.45, fw, H * 0.55, 1, 1, 1, 1);
		if ( gl.ga ~= a ) then
			gl:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22 * a);
			gl.ga = a;
		end
	else
		Off(P.gloss);
	end
	if ( exec ) then
		-- and a light shimmer over it
		local ec = s.execRGB;
		Put(P.exec, 0, y0, fw, H, ec[1], ec[2], ec[3], a * (0.06 + 0.12 * pulse));
	else
		Off(P.exec);
	end
	if ( s.execAt > 0 and not d.dead ) then
		local ec = s.execRGB;
		Put(P.mark, W * s.execAt / 100 - 1, y0, 2, H, ec[1], ec[2], ec[3], a * 0.9);
	else
		Off(P.mark);
	end
	if ( s.sheen and fw > 4 and not d.dead ) then
		Sweep(P.sheen, 0, fw, y0, H, WHITE, a * 0.28, now, 3.5, (W + 80) / 1.2);
	else
		Off(P.sheen);
	end
	-- its mana (or rage, energy) under it
	if ( ph > 0 ) then
		local pc = POWER[d.ptype or 0] or POWER[0];
		local pf = math.max(0, math.min(1, d.pw / d.pmx));
		Put(P.powerBg, 0, 0, W, ph, pc[1] * 0.25, pc[2] * 0.25, pc[3] * 0.25, a * 0.8);
		Coords(P.power, 0, math.max(0.01, pf), 0, 1);
		Put(P.power, 0, 0, W * pf, ph, pc[1], pc[2], pc[3], a);
	else
		Off(P.powerBg);
		Off(P.power);
	end
	-- the numbers
	local text = Numbers(s, d);
	Font(P.text, s.textSize);
	if ( text ~= "" ) then
		if ( P.text.at ~= s.textPos or P.text.y0 ~= y0 or P.text.H ~= H ) then
			P.text:ClearAllPoints();
			if ( s.textPos == "left" ) then
				P.text:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
			elseif ( s.textPos == "right" ) then
				P.text:SetPoint("RIGHT", f, "BOTTOMRIGHT", -4, y0 + H / 2);
			else
				P.text:SetPoint("CENTER", f, "BOTTOM", 0, y0 + H / 2);
			end
			P.text.at, P.text.y0, P.text.H = s.textPos, y0, H;
		end
		Say(P.text, text);
		P.text:SetTextColor(1, 1, 1, a);
		P.text:Show();
	else
		P.text:Hide();
	end
	-- its name (above, inside or under it), its kind's word and whom it's after (the user's players,
	-- 2026-11-26: "have the guardian/elite/boss setting put on that 2nd row above the mobs name on the
	-- far left", "if the name is long, the ToT is the one that moves to the 2nd line up"; the user, the
	-- same day: "guardian didnt go on top", "level should also be able to go uptop with guardian", "the
	-- target should also remain on the bttom row"). The name keeps the row next to the bar. A second row
	-- beyond it holds its level (levelPos "row") and its kind's word (kindAt "row") at its left, and
	-- whom it's after at its right when totAt is "row", or "auto" and the name doesn't fit beside it.
	T.top, T.bottom = 0, 0;
	local line = math.max(s.name and s.nameSize or 0, s.tot and 10 or 0) + 4;
	local nameAt = s.namePos;
	local below = s.name and nameAt == "below";
	-- whom it's after: its name (you: "You" in the warning colour; a teammate in their class's colour),
	-- marked by a sword or an arrow before it, or "Target: name"
	local tot, you = nil, s.totYou and d.totYou;
	if ( s.tot and d.tot ) then
		local c = you and s.totYouRGB or ( s.totClass and CLASS_RGB[d.totClass or ""] ) or TOT_RGB;
		tot = Hex(c) .. ( you and AST_L("You") or d.tot ) .. "|r";
		if ( s.totMark == "word" ) then
			-- ("Targeting", not "Target": the languages' build matches texts to the game's names by their
			-- letters, and "Target: %s" would read as its "Targets")
			tot = string.format(AST_L("Targeting: %s"), tot);
		end
	end
	local icon = tot and TOT_MARKS[s.totMark];
	local totW, totTW = 0, 0;
	if ( tot ) then
		Font(P.tot, 10);
		Say(P.tot, tot);
		if ( T.totSaid ~= tot ) then
			T.totSaid, T.totTW = tot, Wide(tot, 10);
		end
		totTW = T.totTW;
		totW = totTW + 10 + ( icon and 16 or 0 );
	end
	local word = s.name and s.kindTag and KindWord(d.kind);
	local wordUp, totUp = false, false;
	-- its level on that row, before its kind's word: how far in the word starts
	local levelUp = s.level and LevelAt(s) == "row" and LevelText(d);
	local wordX = levelUp and Wide(levelUp, s.levelSize) + 4 or 0;
	if ( s.name ) then
		Font(P.name, s.nameSize);
		-- the room on its line: inside the bar, beside the numbers; else the bar's width (from the level's
		-- part at its end), less whom it's after while that's on the same line
		local full = math.max(20, W + lw);
		local shown, whole;
		if ( nameAt == "inside" ) then
			shown = NameLine(s, d, math.max(20, W * ( text ~= "" and s.textPos ~= "left" and 0.6 or 0.95 ) - 4), true);
		else
			wordUp = ( word and s.kindAt ~= "name" ) and true or false;
			totUp = ( tot and s.totAt == "row" ) and true or false;
			shown, whole = NameLine(s, d, math.max(20, full - ( totUp and 0 or totW )), not wordUp);
			if ( not whole and tot and s.totAt == "auto" ) then
				totUp = true;
				shown = NameLine(s, d, full, not wordUp);
			end
			-- (no room for both on that row: whom it's after wins)
			if ( wordUp and totUp and wordX + Wide(word, 10) + totW > full ) then
				wordUp = false;
			end
		end
		Say(P.name, shown);
		P.name:ClearAllPoints();
		if ( nameAt == "inside" ) then
			P.name:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
		elseif ( below ) then
			P.name:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -lw, -2);
			T.bottom = line;
		else
			P.name:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -lw, 2);
			T.top = line;
		end
		if ( P.name.SetAlpha ) then
			P.name:SetAlpha(a);
		end
		P.name:Show();
	else
		P.name:Hide();
	end
	-- the row beyond the name's: where it starts, and how far everything reaches with it
	local y2 = s.nameSize + 4;
	if ( wordUp or totUp or levelUp ) then
		if ( below ) then
			T.bottom = y2 + 13;
		else
			T.top = y2 + 13;
		end
	end
	if ( wordUp ) then
		local c = KindColor(s, d.kind);
		Font(P.kind, 10);
		Say(P.kind, word);
		P.kind:SetTextColor(c[1] + (1 - c[1]) * 0.1, c[2] + (1 - c[2]) * 0.1, c[3] + (1 - c[3]) * 0.1, a);
		P.kind:ClearAllPoints();
		if ( below ) then
			P.kind:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -lw + wordX, -y2);
		else
			P.kind:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -lw + wordX, y2);
		end
		P.kind:Show();
	else
		P.kind:Hide();
	end
	if ( tot ) then
		local y = totUp and y2 or 2;
		-- after you: a soft beat
		local beat = you and ( 0.8 + 0.2 * math.sin(now * 5) ) or 1;
		P.tot:SetTextColor(TOT_RGB[1], TOT_RGB[2], TOT_RGB[3], a * beat);
		P.tot:ClearAllPoints();
		if ( below ) then
			P.tot:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -y);
			T.bottom = math.max(T.bottom, line);
		else
			P.tot:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, y);
			T.top = math.max(T.top, line);
		end
		P.tot:Show();
		-- its mark, just before it, as tall as the text (the sword is the attack cursor, its tip to the
		-- upper left: mirrored, so it points at the name)
		if ( icon ) then
			if ( P.totIcon.path ~= icon ) then
				P.totIcon:SetTexture(icon);
				P.totIcon.path = icon;
			end
			if ( s.totMark == "sword" ) then
				Coords(P.totIcon, 1, 0, 0, 1);
			else
				Coords(P.totIcon, 0, 1, 0, 1);
			end
			Put(P.totIcon, W - totTW - 16, below and ( -y - 12 ) or ( H + y0 + y - 1 ), 12, 12, 1, 1, 1, a * beat);
		else
			Off(P.totIcon);
		end
	else
		P.tot:Hide();
		Off(P.totIcon);
	end
	Level(s, d, W, H, y0, a, lw);
	-- unlocked: a handle and a hint, and it takes the mouse
	if ( not s.locked ) then
		Put(P.handle, -3 - lw, -3, W + lw + 6, H + y0 + 6, 0.75, 0.55, 1, 0.25 + 0.1 * math.sin(now * 4));
		Font(P.hint, 10);
		P.hint:ClearAllPoints();
		P.hint:SetPoint("BOTTOM", f, "TOP", 0, T.top + 2);
		Say(P.hint, AST_L("Drag to move, right-click to lock"));
		P.hint:SetTextColor(0.85, 0.75, 1, 1);
		P.hint:Show();
	else
		Off(P.handle);
		P.hint:Hide();
	end
	if ( f.mouse ~= not s.locked ) then
		f:EnableMouse(not s.locked);
		f.mouse = not s.locked;
	end
end

---------------------------------------------------------------------------------------------
-- Its debuffs and buffs

local function Icon(n)
	local ic = T.icons[n];
	if ( ic ) then
		return ic;
	end
	ic = CreateFrame("Frame", nil, f);
	ic.edge = ic:CreateTexture(nil, "BACKGROUND");
	ic.edge:SetTexture(SOLID);
	ic.edge:SetPoint("TOPLEFT", ic, "TOPLEFT", -1, 1);
	ic.edge:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, -1);
	ic.tex = ic:CreateTexture(nil, "ARTWORK");
	ic.tex:SetAllPoints(ic);
	ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	ic.shade = ic:CreateTexture(nil, "OVERLAY");
	ic.shade:SetTexture(SOLID);
	ic.shade:SetVertexColor(0, 0, 0, 0.55);
	local font = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
	ic.time = ic:CreateFontString(nil, "OVERLAY");
	ic.time:SetFont(font, 10, "OUTLINE");
	ic.time:SetPoint("CENTER", ic, "CENTER", 0, 0);
	ic.stack = ic:CreateFontString(nil, "OVERLAY");
	ic.stack:SetFont(font, 9, "OUTLINE");
	ic.stack:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, 1);
	-- its tooltip, if wanted (what it is, as the game tells it)
	ic:SetScript("OnEnter", function()
		if ( not GameTooltip ) then
			return;
		end
		GameTooltip:SetOwner(ic, "ANCHOR_BOTTOMRIGHT");
		if ( ic.index and ic.buff and GameTooltip.SetUnitBuff ) then
			GameTooltip:SetUnitBuff("target", ic.index);
		elseif ( ic.index and GameTooltip.SetUnitDebuff ) then
			GameTooltip:SetUnitDebuff("target", ic.index);
		elseif ( ic.name ) then
			GameTooltip:SetText(ic.name, 1, 1, 1);
		end
		GameTooltip:Show();
	end);
	ic:SetScript("OnLeave", function()
		if ( GameTooltip ) then
			GameTooltip:Hide();
		end
	end);
	T.icons[n] = ic;
	return ic;
end

-- One aura's icon: its picture, edge, stacks, time left and its shade.
local function Show1(ic, e, size, s)
	ic:SetWidth(size);
	ic:SetHeight(size);
	if ( ic.path ~= e.tex ) then
		ic.tex:SetTexture(e.tex);
		ic.path = e.tex;
	end
	ic.index, ic.buff, ic.name = e.index, e.buff, e.name;
	local c = { 0, 0, 0 };
	if ( not e.buff and s.typeColor ) then
		c = DISPEL[e.type or ""] or NODISPEL;
	end
	ic.edge:SetVertexColor(c[1], c[2], c[3], 0.95);
	if ( ic.fsize ~= size ) then
		local font = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
		ic.time:SetFont(font, math.max(8, math.floor(size * 0.45)), "OUTLINE");
		ic.stack:SetFont(font, math.max(7, math.floor(size * 0.4)), "OUTLINE");
		ic.fsize = size;
	end
	local timed = e.left and e.max and e.max > 0;
	-- the shade: how much of it has gone, from the top
	if ( s.shade and timed ) then
		local gone = 1 - math.max(0, math.min(1, e.left / e.max));
		if ( gone > 0.01 ) then
			ic.shade:ClearAllPoints();
			ic.shade:SetPoint("TOPLEFT", ic, "TOPLEFT", 0, 0);
			ic.shade:SetWidth(size);
			ic.shade:SetHeight(math.max(0.5, size * gone));
			ic.shade:Show();
		else
			ic.shade:Hide();
		end
	else
		ic.shade:Hide();
	end
	if ( s.timers and e.left and e.left > 0.05 ) then
		local left = e.left;
		ic.time:SetText(( left >= 60 and ( math.floor(left / 60) .. "m" ) ) or ( left >= 10 and tostring(math.floor(left)) )
			or string.format("%.1f", left));
		ic.time:SetTextColor(1, left < 3 and 0.6 or 1, left < 3 and 0.3 or 1);
		ic.time:Show();
	else
		ic.time:Hide();
	end
	if ( s.stacks and e.stacks and e.stacks > 1 ) then
		ic.stack:SetText(tostring(e.stacks));
		ic.stack:Show();
	else
		ic.stack:Hide();
	end
	if ( ic.mouse ~= s.tips ) then
		ic:EnableMouse(s.tips and true or false);
		ic.mouse = s.tips;
	end
	ic:Show();
end

-- A group's icons in rows of perRow from the bar outward: above it from `from` px over its top,
-- or under it from `from` px below its bottom. Returns the next free icon's number and how far the
-- rows reach.
local function Lay(list, most, size, side, align, from, n, s)
	local count = math.min(table.getn(list), most);
	if ( count <= 0 ) then
		return n, 0;
	end
	local per = math.max(1, s.perRow);
	local gap = s.auraGap;
	local W = s.width;
	local rows = math.floor((count - 1) / per) + 1;
	for i = 1, count do
		local r = math.floor((i - 1) / per);
		local c = i - 1 - r * per;
		local inRow = math.min(per, count - r * per);
		local rw = inRow * size + (inRow - 1) * gap;
		local x0 = 0;
		if ( align == "center" ) then
			x0 = (W - rw) / 2;
		elseif ( align == "right" ) then
			x0 = W - rw;
		end
		local ic = Icon(n);
		ic:ClearAllPoints();
		if ( side == "below" ) then
			ic:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x0 + c * (size + gap), -(from + r * (size + gap)));
		else
			ic:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x0 + c * (size + gap), from + r * (size + gap));
		end
		Show1(ic, list[i], size, s);
		n = n + 1;
	end
	return n, rows * (size + gap);
end

function T.Icons(d)
	local s = T.S();
	local deb, buf = T.Auras(d);
	local n = 1;
	local up, down = (T.top or 0) + s.auraGap, (T.bottom or 0) + s.auraGap + 1;
	local used;
	if ( s.debuffs ) then
		if ( s.debuffSide == "below" ) then
			n, used = Lay(deb, s.debuffsMax, s.debuffSize, "below", s.debuffAlign, down, n, s);
			down = down + used;
		else
			n, used = Lay(deb, s.debuffsMax, s.debuffSize, "above", s.debuffAlign, up, n, s);
			up = up + used;
		end
	end
	if ( s.buffs ) then
		if ( s.buffSide == "above" ) then
			n, used = Lay(buf, s.buffsMax, s.buffSize, "above", s.buffAlign, up, n, s);
		else
			n, used = Lay(buf, s.buffsMax, s.buffSize, "below", s.buffAlign, down, n, s);
		end
	end
	for i = n, table.getn(T.icons) do
		T.icons[i]:Hide();
	end
	T.shown.icons = n - 1;
	T.shown.debuffs, T.shown.buffs = table.getn(deb), table.getn(buf);
end

---------------------------------------------------------------------------------------------
-- Where it is: on the screen where you put it, or beside the hero bar

local SIDES = {
	right = { "LEFT", "RIGHT", 1, 0 }, left = { "RIGHT", "LEFT", -1, 0 },
	above = { "BOTTOM", "TOP", 0, 1 }, below = { "TOP", "BOTTOM", 0, -1 },
};

-- Whether it's anchored by `point` to `rel` at x, y now (something else may have moved it).
local function At(point, rel, x, y)
	local p1, r1, _, x1, y1 = f:GetPoint();
	return p1 == point and ( rel == nil or r1 == rel ) and x1 ~= nil and y1 ~= nil and math.abs(x1 - x) < 0.5
		and math.abs(y1 - y) < 0.5;
end

function T.Place()
	local s = T.S();
	local sc = s.scale or 1;
	if ( f.scaleSet ~= sc ) then
		f:SetScale(sc);
		f.scaleSet = sc;
	end
	if ( f.dragging ) then
		return;
	end
	local hb = AST.bar and AST.bar.frame;
	if ( s.anchor == "bar" and hb and hb:IsShown() ) then
		local sd = SIDES[s.side] or SIDES.right;
		-- its gap in the screen's units (its own: divided by its scale)
		local gx, gy = sd[3] * s.gap / sc, sd[4] * s.gap / sc;
		if ( f.where ~= "bar" or f.side ~= s.side or f.gx ~= gx or f.gy ~= gy or not At(sd[1], hb, gx, gy) ) then
			f:ClearAllPoints();
			f:SetPoint(sd[1], hb, sd[2], gx, gy);
			f.where, f.side, f.gx, f.gy = "bar", s.side, gx, gy;
		end
		return;
	end
	if ( f.where ~= "screen" or f.px ~= s.x or f.py ~= s.y or f.pp ~= s.point or f.ps ~= sc
		or not At(s.point or "BOTTOM", nil, s.x / sc, s.y / sc) ) then
		f:ClearAllPoints();
		f:SetPoint(s.point or "BOTTOM", UIParent, s.rel or s.point or "BOTTOM", s.x / sc, s.y / sc);
		f.where, f.px, f.py, f.pp, f.ps = "screen", s.x, s.y, s.point, sc;
	end
end

---------------------------------------------------------------------------------------------
-- Each frame

local driver = CreateFrame("Frame", "ASTTargetBarDriver", UIParent);
local acc, last = 0, nil;
driver:SetScript("OnUpdate", function()
	local s = T.S();
	if ( not s ) then
		return;
	end
	local now = GetTime();
	local dt = last and math.min(0.5, now - last) or 0;
	last = now;
	-- put away while the game's cards are up: their screen's own art (spells' icons) would bring a
	-- debuff's icon here through onto the cards (as the hero bar's)
	if ( ( not s.on and not T.Testing() ) or ( AST.CardsUp and AST.CardsUp() ) ) then
		if ( f ) then
			f:Hide();
		end
		return;
	end
	local d = T.Read();
	-- unlocked with nothing targeted: a stand-in, to place it
	if ( not d and not s.locked ) then
		d = { name = AST_L("Your target"), hp = 100, mx = 100, exact = false, kind = "normal", debuffs = {}, buffs = {} };
	end
	if ( not d ) then
		if ( f ) then
			f:Hide();
		end
		T.who = nil;
		return;
	end
	if ( not f ) then
		Make();
	end
	f:Show();
	T.Place();
	T.Paint(d, now, dt);
	acc = acc + dt;
	if ( acc >= 0.1 or T.shown.icons == nil or T.shownFor ~= T.who ) then
		acc = 0;
		T.shownFor = T.who;
		T.Icons(d);
	end
end);
