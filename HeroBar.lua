-- Azeroth Survivors Telegraphs: the hero bar. Your health as a bar you can move and lock (or float
-- above your hero), your shields laid over it in layers (each 100% of your max health a layer of
-- its own colour), your mana under it, and your skills', jewelry's and buffs' icons with their
-- cooldowns. Every part has a switch on its page (Hero bar, under General), with three looks to
-- start from. It can also hide the game's own player frame (with the buff icons by it) and the
-- enemy's frame.
--
-- Where the numbers come from: UnitHealth / UnitHealthMax / UnitMana; your shield from a shield
-- buff's tooltip ("Absorbs N damage.": the game writes your whole shield pool there); skills from
-- action slots 1-6 (the game's bar), their cooldowns from the spell line (Core), else
-- GetActionCooldown; jewelry from the meter's copy of your loadout (runJewelry: each piece's name and
-- icon), its clock from AZS_GetTimers; buffs from UnitBuff.

local B = { icons = {}, parked = {}, groups = {}, buffMax = {}, names = {}, test = nil, shown = {} };
AST.bar = B;

-- Whether the game's cards are up (a level's or a new piece of jewelry's): its "choosing" phase.
function AST.CardsUp()
	return type(AZS_GetPhase) == "function" and AZS_GetPhase() == "choosing";
end

local SOLID = "Interface\\Buttons\\WHITE8X8";
local SHADED = "Interface\\TargetingFrame\\UI-StatusBar";
local GLOW = "Spells\\GENERICGLOW64";
local RIM = "Interface\\Buttons\\UI-ActionButton-Border";
local SKILL_SLOTS = { 1, 2, 3, 4, 5, 6 };   -- the game's spell slots (action bars 1 to 6)
local SHIELD_PAT = "Absorbs ([%d%.,]+) damage";            -- a shield buff's line: your whole pool
local SHIELD_OWN_PAT = "Absorbs up to ([%d%.,]+) damage";    -- or that one shield's own amount
local CLASS = {
	warrior = { 0.78, 0.61, 0.43 }, paladin = { 0.96, 0.55, 0.73 }, hunter = { 0.67, 0.83, 0.45 },
	rogue = { 1, 0.96, 0.41 }, priest = { 0.95, 0.95, 0.95 }, shaman = { 0.0, 0.44, 0.87 },
	mage = { 0.41, 0.8, 0.94 }, warlock = { 0.58, 0.51, 0.79 }, druid = { 1, 0.49, 0.04 },
};
local POWER = { [0] = { 0.25, 0.5, 1 }, [1] = { 0.9, 0.2, 0.2 }, [2] = { 1, 0.5, 0.25 }, [3] = { 1, 0.85, 0.2 } };
-- the game's own frames it can hide: yours (with the buff icons by it), the enemy's
local PLAYER_FRAMES = { "PlayerFrame" };
-- your buffs by the minimap: their own setting (the user, 2026-11-25: hidden with your frame, they
-- were missed)
-- (and your debuffs' buttons by name: SurvivorsDragonUi moves them out of the buff frame into a row
-- of its own, so they'd stay; the game's own frame holds them, and they go with it either way)
local BUFF_FRAMES = { "BuffFrame", "TemporaryEnchantFrame", "BuffButton16", "BuffButton17", "BuffButton18", "BuffButton19",
	"BuffButton20", "BuffButton21", "BuffButton22", "BuffButton23" };
local TARGET_FRAMES = { "TargetFrame", "TargetofTargetFrame", "ComboFrame" };

-- Every setting and where it starts (the Sleek look).
local DEF = {
	-- off to start with (the user, 2026-11-25): it's turned on in its options page
	-- anchor: "screen" (where you put it), "hero" (`above` yd over your feet) or "under" (its top
	-- `below` px under your feet)
	on = false, locked = true, anchor = "screen", point = "BOTTOM", rel = "BOTTOM", x = 0, y = 190, above = 2.8, below = 20,
	width = 230, height = 16, scale = 1, alpha = 1, fadeFull = false, fadeAlpha = 0.35,
	look = "sleek", texture = "shaded",
	healthColor = "health", healthRGB = { 0.25, 0.8, 0.35 }, bgAlpha = 0.55, border = true, gloss = true,
	sheen = true, smooth = true, trail = true, lowAt = 30,
	text = "percent", textSize = 11, textPos = "center", textShield = false,
	power = false, powerHeight = 4,
	-- your level in the run: "left" (a small box left of the bar), "inside" or "above"
	level = false, levelPos = "left", levelSize = 11, levelRGB = { 1, 0.82, 0.2 },
	shield = true, shieldLook = "energy", shieldText = true, shieldAlpha = 0.7, shieldFx = true,
	-- "amount": layers as long as the shield holds; "marker": the bar's right end (shieldMark %)
	-- covered while you have any shield, the same however much it holds
	shieldStyle = "amount", shieldMark = 25,
	-- "amount"'s end: "left" (it fills from the bar's left end and wears away from its right) or
	-- "right" (the other way round) (the user, 2026-11-27)
	shieldFrom = "left",
	-- your health the same way: "left" (fills from the bar's left end, drains from its right) or "right"
	-- (the user, 2026-11-27: "add a toggle to do the same with hp")
	hpFrom = "left",
	-- the light running along the shield in the Energy look (the user, 2026-11-27: a switch like health's)
	shieldSheen = true,
	shield1 = { 0.35, 0.75, 1 }, shield2 = { 1, 0.78, 0.25 }, shield3 = { 0.85, 0.45, 1 },
	skills = true, jewelry = true, buffs = false, buffsMax = 8,
	-- a skill's icon only while it's on cooldown (the user, 2026-11-26)
	skillsCooling = false,
	iconSize = 22, iconGap = 3, iconSide = "below", iconRows = "each", iconAlign = "center",
	-- cooldowns on the icons: off to start with (what you have, not when it's back); each part when on
	cooldowns = false, sweep = true, timers = true, glow = true, grey = true,
	hidePlayer = false, hideTarget = false, hideBuffs = false,
	v = 4,
};

-- The three looks: what each sets (position, the icon groups and the hiding stay yours).
B.LOOKS = {
	subdued = { width = 200, height = 9, alpha = 0.85, texture = "flat", healthColor = "custom", healthRGB = { 0.42, 0.62, 0.48 },
		bgAlpha = 0.35, border = false, gloss = false, sheen = false, smooth = true, trail = false, lowAt = 0,
		text = "none", powerHeight = 3, shieldLook = "flat", shieldAlpha = 0.5, shieldFx = false, shieldText = false,
		shield1 = { 0.55, 0.72, 0.85 }, shield2 = { 0.85, 0.78, 0.55 }, shield3 = { 0.72, 0.6, 0.82 },
		iconSize = 18, iconGap = 2 },
	sleek = { width = 230, height = 16, alpha = 1, texture = "shaded", healthColor = "health", bgAlpha = 0.55, border = true,
		gloss = true, sheen = true, smooth = true, trail = true, lowAt = 30, text = "percent", textSize = 11, powerHeight = 4,
		shieldLook = "energy", shieldAlpha = 0.7, shieldFx = true, shieldText = true,
		shield1 = { 0.35, 0.75, 1 }, shield2 = { 1, 0.78, 0.25 }, shield3 = { 0.85, 0.45, 1 },
		iconSize = 22, iconGap = 3 },
	bold = { width = 290, height = 22, alpha = 1, texture = "shaded", healthColor = "class", bgAlpha = 0.7, border = true,
		gloss = true, sheen = true, smooth = true, trail = true, lowAt = 35, text = "full", textSize = 13, powerHeight = 6,
		shieldLook = "energy", shieldAlpha = 0.85, shieldFx = true, shieldText = true,
		shield1 = { 0.3, 0.8, 1 }, shield2 = { 1, 0.75, 0.15 }, shield3 = { 0.95, 0.35, 1 },
		iconSize = 30, iconGap = 4 },
};

local function Copy(v)
	if ( type(v) == "table" ) then
		return { v[1], v[2], v[3], v[4] };
	end
	return v;
end

-- Its settings, the defaults filled in (nil before the saved settings are there).
function B.S()
	local db = AST.State();
	if ( not db ) then
		return nil;
	end
	local s = db.bar;
	if ( not s ) then
		s = {};
		db.bar = s;
	end
	-- the user's second look (2026-11-25): your spells only, no cooldowns, no mana, to start with
	if ( next(s) and ( s.v or 1 ) < 2 ) then
		s.items, s.buffs, s.power, s.cooldowns, s.racial, s.v = false, false, false, false, false, 2;
	end
	-- (and the third: the jewelry you wear its own group, on; talents' clocks apart from it, off)
	if ( next(s) and ( s.v or 1 ) < 3 ) then
		s.items, s.jewelry, s.talents, s.v = nil, true, false, 3;
	end
	-- (the fourth: no talents' clocks and no racial any more; buffs and jewelry chosen for every class)
	if ( next(s) and ( s.v or 1 ) < 4 ) then
		s.talents, s.racial, s.v = nil, nil, 4;
		for _, c in pairs(s.pick or {}) do
			c.talents = nil;
		end
	end
	-- the defaults filled in once for each settings table
	if ( B.filled ~= s ) then
		for k, v in pairs(DEF) do
			if ( s[k] == nil ) then
				s[k] = Copy(v);
			end
		end
		B.filled = s;
	end
	return s;
end

function B.Defaults()
	return DEF;
end

-- A look: its settings over yours.
function B.ApplyLook(name)
	local s, look = B.S(), B.LOOKS[name];
	if ( not ( s and look ) ) then
		return;
	end
	for k, v in pairs(look) do
		s[k] = Copy(v);
	end
	s.look = name;
	B.dirty = true;
end

-- Everything back as it started (its place too).
function B.Reset()
	local db = AST.State();
	if ( db ) then
		db.bar = nil;
		B.S();
		B.dirty = true;
		B.Park();
	end
end

---------------------------------------------------------------------------------------------
-- The game's own frames: hidden by moving them into a frame that never shows (as the game does
-- with its spare action buttons), so nothing of theirs can show them again; back where they were
-- when the setting is turned off.

local attic = CreateFrame("Frame", "ASTAttic", UIParent);
attic:Hide();

-- Shown again on the way back only when it would be: the enemy frames with something targeted.
local SHOWN_IF = { TargetFrame = "target", TargetofTargetFrame = "targettarget" };
local UPDATE = { PlayerFrame = "PlayerFrame_Update", TargetFrame = "TargetFrame_Update", ComboFrame = "ComboFrame_Update",
	TargetofTargetFrame = "TargetofTarget_Update" };

-- A game frame another addon has taken over: SurvivorUI's own unit frames (shown: the game's player
-- and target frames switched off by it), or an enemy frame hidden with a target there. Put back as
-- it was, it isn't shown or updated (that would bring the game's back beside the addon's).
local OWNED = { PlayerFrame = true, TargetFrame = true, TargetofTargetFrame = true };
local function SurvivorUIOwns(name)
	local own = getglobal("SurvivorUIPlayer");
	return OWNED[name] ~= nil and own ~= nil and own.IsShown ~= nil and own:IsShown() and true or false;
end

local function Foreign(fr, name)
	if ( name and SurvivorUIOwns(name) ) then
		return true;
	end
	local unit = name and SHOWN_IF[name];
	return unit ~= nil and UnitExists ~= nil and UnitExists(unit) and not fr:IsShown();
end

local function ParkOne(fr, name)
	if ( B.parked[fr] ) then
		return;
	end
	-- (its own Show kept, to put back: a UI addon may have set one, e.g. to keep it hidden)
	B.parked[fr] = { parent = fr:GetParent() or UIParent, shown = fr:IsShown(), name = name, show = rawget(fr, "Show"),
		foreign = Foreign(fr, name) and true or nil };
	fr:SetParent(attic);
	fr:Hide();
	-- nothing of its own shows it again while it's put away
	fr.Show = function() end;
end

local function Unpark(fr)
	local p = B.parked[fr];
	if ( not p ) then
		return;
	end
	B.parked[fr] = nil;
	fr.Show = p.show;
	fr:SetParent(p.parent);
	if ( p.foreign or ( p.name and SurvivorUIOwns(p.name) ) ) then
		-- another addon's to show: left as it was
		return;
	end
	local unit = p.name and SHOWN_IF[p.name];
	if ( ( unit and UnitExists and UnitExists(unit) ) or ( not unit and p.shown ) ) then
		fr:Show();
	end
	local up = p.name and UPDATE[p.name] and getglobal(UPDATE[p.name]);
	if ( type(up) == "function" ) then
		-- as that frame: these work on `this` (else the button just clicked, which they'd hide)
		local was = this;
		this = fr;
		pcall(up);
		this = was;
	end
end

-- A group (yours, the enemy's, your buffs) hidden or back: the frames by name. (Not what sits
-- under them: that would take other addons' frames placed there; the skill and jewelry icons under
-- your portrait are the game's own Build display, its own setting: Hide your skill icons.)
local function Group(key, names, on)
	if ( on and not B.groups[key] ) then
		local list = {};
		for i = 1, table.getn(names) do
			local fr = getglobal(names[i]);
			if ( fr ) then
				table.insert(list, { fr, names[i] });
			end
		end
		for i = 1, table.getn(list) do
			ParkOne(list[i][1], list[i][2]);
		end
		B.groups[key] = list;
	elseif ( not on and B.groups[key] ) then
		local list = B.groups[key];
		for i = 1, table.getn(list) do
			Unpark(list[i][1]);
		end
		B.groups[key] = nil;
	end
end

function B.Park()
	local s = B.S();
	if ( not s ) then
		return;
	end
	Group("player", PLAYER_FRAMES, s.hidePlayer);
	Group("target", TARGET_FRAMES, s.hideTarget);
	Group("buffs", BUFF_FRAMES, s.hideBuffs);
end

-- What's hidden now, by name (for /ast what).
function B.Hidden()
	local out = {};
	for fr, p in pairs(B.parked) do
		table.insert(out, p.name or "(no name)");
	end
	table.sort(out);
	return out;
end

---------------------------------------------------------------------------------------------
-- The frame and its pieces

local f;          -- the bar's frame
local P = {};     -- its textures and texts by name

local function Font(fs, size)
	local path = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
	if ( fs.size ~= size ) then
		fs:SetFont(path, size, "OUTLINE");
		fs.size = size;
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

-- Texture t at (x, y) from the bar's bottom left, w x h, coloured: only what changed is sent.
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
	f = CreateFrame("Frame", "ASTHeroBar", UIParent);
	f:SetFrameStrata("MEDIUM");
	f:SetWidth(230);
	f:SetHeight(20);
	f:SetMovable(true);
	if ( f.SetClampedToScreen ) then
		f:SetClampedToScreen(true);
	end
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", function()
		local s = B.S();
		if ( s and not s.locked ) then
			f.dragging = true;
			f:StartMoving();
		end
	end);
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing();
		f.dragging = nil;
		-- the addon keeps where it goes: not the game, which would put it back where it was last
		-- time when you enter a game, after the addon has placed it (the user, 2026-11-25)
		if ( f.SetUserPlaced ) then
			f:SetUserPlaced(false);
		end
		local s = B.S();
		if ( s ) then
			-- kept as its centre, in the screen's units (its own are its scale's): a new scale then
			-- grows or shrinks it round its middle, where it is
			local sc = ( f.GetScale and f:GetScale() ) or 1;
			local cx, cy = f:GetCenter();
			if ( cx and cy ) then
				s.point, s.rel, s.x, s.y = "CENTER", "BOTTOMLEFT", cx * sc, cy * sc;
			else
				local point, _, rel, x, y = f:GetPoint();
				s.point, s.rel, s.x, s.y = point, rel or point, (x or 0) * sc, (y or 0) * sc;
			end
			s.anchor = "screen";
			f.where = nil;
		end
	end);
	f:SetScript("OnMouseUp", function()
		local s = B.S();
		if ( s and arg1 == "RightButton" ) then
			s.locked = true;
			B.dirty = true;
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
	P.low = Tex("ARTWORK", SOLID);
	P.sheen = Tex("ARTWORK", GLOW, "ADD");
	P.power = Tex("ARTWORK", SHADED);
	for k = 1, 3 do
		P["shield" .. k] = Tex("OVERLAY", SOLID);
		P["shieldTop" .. k] = Tex("OVERLAY", SOLID);
	end
	P.front = Tex("OVERLAY", SOLID);
	P.frontGlow = Tex("OVERLAY", GLOW, "ADD");
	P.shieldSheen = Tex("OVERLAY", GLOW, "ADD");
	P.flash = Tex("OVERLAY", SOLID);
	P.burst = Tex("OVERLAY", GLOW, "ADD");
	P.handle = Tex("OVERLAY", SOLID);
	P.levelBg = Tex("BORDER", SOLID);
	P.levelLine = Tex("ARTWORK", SOLID);
	P.text = f:CreateFontString(nil, "OVERLAY");
	P.shieldTextFs = f:CreateFontString(nil, "OVERLAY");
	P.hint = f:CreateFontString(nil, "OVERLAY");
	P.levelFs = f:CreateFontString(nil, "OVERLAY");
	Font(P.levelFs, 11);
	Font(P.text, 11);
	Font(P.shieldTextFs, 10);
	Font(P.hint, 10);
	B.frame, B.P = f, P;
end

---------------------------------------------------------------------------------------------
-- What it shows: read from the game, or the Test demo's

-- A buff's tooltip lines: as the game's own buff frame asks for them (SetPlayerBuff), else by unit.
local function BuffLines(i)
	local lines;
	if ( GetPlayerBuff ) then
		local id = GetPlayerBuff(i - 1, "HELPFUL");
		if ( id and id >= 0 ) then
			lines = AST.TipLines("SetPlayerBuff", id);
		end
	end
	if ( not lines or table.getn(lines) == 0 ) then
		lines = AST.TipLines("SetUnitBuff", "player", i);
	end
	return lines or {};
end

-- The amount a line gives a shield as, and whether it's your whole shield: "Absorbs N damage." is
-- the game's whole pool (every shield together); any other line about absorbing damage ("Absorbs up
-- to N damage.", a shield's own) is that one shield's (its biggest number; not a "% more" line).
local function ShieldIn(line, pats, own)
	-- one shield's own first (in some languages the whole pool's words sit inside its line too)
	for q = 1, table.getn(own or {}) do
		local _, _, n = string.find(line, own[q]);
		if ( n ) then
			return tonumber((string.gsub(n, "[^%d]", ""))), false;
		end
	end
	for q = 1, table.getn(pats) do
		local _, _, n = string.find(line, pats[q]);
		if ( n ) then
			return tonumber((string.gsub(n, "[^%d]", ""))), true;
		end
	end
	if ( string.find(line, "bsorb") and string.find(line, "damage") and not string.find(line, "%%") ) then
		local pos, best = 1, nil;
		while ( true ) do
			local s1, e1, n = string.find(line, "(%d[%d,]*)", pos);
			if ( not s1 ) then
				break;
			end
			local v = tonumber((string.gsub(n, "[^%d]", "")));
			if ( v and ( not best or v > best ) ) then
				best = v;
			end
			pos = e1 + 1;
		end
		return best;
	end
	return nil;
end

-- Your whole shield: every shield buff's own amount added up (the user, 2026-11-25: only the biggest
-- showed), or the game's whole pool where a tooltip gives it (counted once). 0 with none. And the
-- least time left on a shield buff (nil when none says), so a shield running out can be told from
-- one broken by a hit.
local function ReadShield()
	if ( not ( UnitBuff and AST.TipLines ) ) then
		return 0, nil;
	end
	local soonest;
	local pats = AST_Patterns and AST_Patterns(SHIELD_PAT) or { SHIELD_PAT };
	local own = AST_Patterns and AST_Patterns(SHIELD_OWN_PAT) or { SHIELD_OWN_PAT };
	local sum, pool = 0, nil;
	for i = 1, 32 do
		if ( not UnitBuff("player", i) ) then
			break;
		end
		local lines = BuffLines(i);
		for k = 1, table.getn(lines) do
			local v, whole = ShieldIn(lines[k], pats, own);
			if ( v ) then
				if ( whole ) then
					pool = math.max(pool or 0, v);
				else
					sum = sum + v;
				end
				local id = GetPlayerBuff and GetPlayerBuff(i - 1, "HELPFUL");
				local left = id and id >= 0 and GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(id);
				if ( type(left) == "number" and left > 0 and ( not soonest or left < soonest ) ) then
					soonest = left;
				end
				-- one amount a buff
				break;
			end
		end
	end
	return pool or sum, soonest;
end

-- /ast bar shield: every buff on you with its tooltip lines (both ways of asking), the game's own
-- list of them, and the shield read; into chat and the saved settings (db.barDump; /reload writes it).
function B.ShieldDump()
	local out = {};
	local function Say(line)
		table.insert(out, line);
		DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: " .. line);
	end
	for i = 1, 32 do
		local tex = UnitBuff and UnitBuff("player", i);
		if ( not tex ) then
			break;
		end
		local id = GetPlayerBuff and GetPlayerBuff(i - 1, "HELPFUL");
		local a = ( id and id >= 0 and AST.TipLines("SetPlayerBuff", id) ) or {};
		local b = AST.TipLines("SetUnitBuff", "player", i) or {};
		Say(string.format("buff %d: %s (id %s) | %s | %s", i, tostring(tex), tostring(id), table.concat(a, " / "), table.concat(b, " / ")));
	end
	for i = 1, table.getn(AZS_BUFFS or {}) do
		local e = AZS_BUFFS[i];
		Say(string.format("game buff line: spell %s, %s sec left", tostring(e.spell), tostring(e.left)));
	end
	Say("shield read: " .. tostring(ReadShield()));
	local db = AST.State();
	if ( db ) then
		db.barDump = out;
	end
end

-- The demo a Test press plays (8 sec): blows, a heal, a shield past 100% worn down and broken.
local function Demo(t)
	local hp = 0.82 - 0.35 * math.min(1, math.max(0, (t - 0.6) / 1.2)) + 0.4 * math.min(1, math.max(0, (t - 5.2) / 1.5));
	if ( t > 2.2 and t < 2.4 ) then
		hp = hp - 0.12;
	end
	local sh = 0;
	if ( t > 1.8 ) then
		sh = math.min(1.65, (t - 1.8) * 3);
	end
	if ( t > 2.6 ) then
		sh = math.max(0, 1.65 - (t - 2.6) * 0.55);
	end
	if ( t > 5.6 ) then
		sh = 0;
	end
	return math.max(0.05, math.min(1, hp)) * 500, 500, sh * 500, 0.6 + 0.3 * math.sin(t), 1;
end

function B.Read(now)
	if ( B.test and GetTime() < B.test ) then
		local hp, mx, sh, pw, pmx = Demo(8 - (B.test - GetTime()));
		return hp, mx, sh, pw, pmx, 0;
	end
	local hp = UnitHealth and UnitHealth("player") or 0;
	local mx = UnitHealthMax and UnitHealthMax("player") or 0;
	local pw = UnitMana and UnitMana("player") or 0;
	local pmx = UnitManaMax and UnitManaMax("player") or 0;
	local kind = UnitPowerType and UnitPowerType("player") or 0;
	if ( not B.shieldAt or now - B.shieldAt > 0.2 or now < B.shieldAt ) then
		local v, left = ReadShield();
		-- A shield that runs out and is cast again at once: a read can fall between the old buff
		-- going and the new one coming, and the bar would blink empty (the user, 2026-11-25). So a
		-- drop just as a shield buff was in its last half second is held for one more read (0.2 sec):
		-- back by then, no blink; still gone, it shows gone (with no "broken" flash: it ran out). A
		-- shield broken by a hit (time still on it) shows at once.
		if ( v < (B.shieldNow or 0) and B.expiring and not B.held ) then
			B.held = true;
		else
			if ( B.held and v < (B.shieldNow or 0) ) then
				B.ranOut = now;
			end
			B.held, B.shieldNow = nil, v;
		end
		B.expiring = left ~= nil and left <= 0.5;
		B.shieldAt = now;
	end
	return hp, mx, B.shieldNow or 0, pw, pmx, kind;
end

---------------------------------------------------------------------------------------------
-- Drawing the bar

local function Mix(a, b, t)
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t;
end

local GREEN, YELLOW, RED, WHITE = { 0.25, 0.82, 0.35 }, { 1, 0.82, 0.2 }, { 0.92, 0.22, 0.16 }, { 1, 1, 1 };

local function HealthColor(s, frac)
	if ( s.healthColor == "class" ) then
		local _, _, class = AST.State();
		local c = CLASS[class or ""] or GREEN;
		return c[1], c[2], c[3];
	elseif ( s.healthColor == "custom" ) then
		return s.healthRGB[1], s.healthRGB[2], s.healthRGB[3];
	end
	if ( frac > 0.5 ) then
		return Mix(YELLOW, GREEN, (frac - 0.5) / 0.5);
	end
	return Mix(RED, YELLOW, frac / 0.5);
end

-- A soft light sweeping across a stretch x0..x1 of the bar (at y, h tall) every `period` sec,
-- clipped to the stretch.
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

local function Text(s, hp, mx)
	local pct = mx > 0 and math.floor(hp / mx * 100 + 0.5) or 0;
	if ( s.text == "percent" ) then
		return pct .. "%";
	elseif ( s.text == "current" ) then
		return tostring(math.floor(hp + 0.5));
	elseif ( s.text == "both" ) then
		return math.floor(hp + 0.5) .. " / " .. math.floor(mx + 0.5);
	elseif ( s.text == "full" ) then
		return math.floor(hp + 0.5) .. " / " .. math.floor(mx + 0.5) .. "  (" .. pct .. "%)";
	end
	return "";
end

-- The shield's layers over the health: each 100% of your max health a layer of its own colour,
-- drawn from the left (it wears away from the right, as it does). Each stretch of the bar shows only
-- the topmost layer there (an overshield takes over the colour where it reaches, as in Halo; three
-- layers on top of each other would be mud), as light glass over your health with a bright top line,
-- the higher layers a little stronger.
local function Shields(s, frac, W, y, h, now, a)
	local colors = { s.shield1, s.shield2, s.shield3 };
	local energy = s.shieldLook == "energy";
	local breath = energy and ( 0.9 + 0.1 * math.sin(now * 3.1) ) or 1;
	local hit = 0;
	if ( s.shieldFx and B.hitAt and now - B.hitAt < 0.25 ) then
		hit = 1 - (now - B.hitAt) / 0.25;
	end
	local parts = {};
	for k = 1, 3 do
		local part = math.max(0, math.min(1, frac - (k - 1)));
		parts[k] = part;
	end
	-- from the bar's right end instead (shieldFrom "right"): the same, mirrored
	local right = s.shieldFrom == "right";
	local function X(x, w)
		if ( right ) then
			return W - x - w;
		end
		return x;
	end
	local top, topC = 0, nil;
	for k = 1, 3 do
		local c = colors[k];
		local x0, x1 = W * (parts[k + 1] or 0), W * parts[k];
		local body = s.shieldAlpha * ( energy and ( 0.34 + 0.1 * (k - 1) ) or ( 0.55 + 0.08 * (k - 1) ) ) * breath + hit * 0.3;
		Put(P["shield" .. k], X(x0, x1 - x0), y, x1 - x0, h, c[1], c[2], c[3], a * body);
		if ( energy ) then
			local lh = math.max(1, h * 0.14);
			Put(P["shieldTop" .. k], X(x0, x1 - x0), y + h - lh, x1 - x0, lh, c[1], c[2], c[3], a * math.min(1, s.shieldAlpha + 0.25));
		else
			Off(P["shieldTop" .. k]);
		end
		if ( parts[k] > 0 ) then
			top, topC = W * parts[k], c;
		end
	end
	if ( energy and top > 0 ) then
		-- its front (where it's wearing away): a bright edge with a glow; a light running along it
		local lc = { 0.6 + 0.4 * topC[1], 0.6 + 0.4 * topC[2], 0.6 + 0.4 * topC[3] };
		Put(P.front, X(top - 2, 2), y, 2, h, lc[1], lc[2], lc[3], a * (0.9 + 0.1 * hit));
		Coords(P.frontGlow, 0, 1, 0, 1);
		Put(P.frontGlow, X(top - h * 0.9, h * 1.8), y - h * 0.4, h * 1.8, h * 1.8, topC[1], topC[2], topC[3], a * 0.45 * breath);
		if ( s.shieldSheen ) then
			Sweep(P.shieldSheen, X(0, W * parts[1]), X(0, W * parts[1]) + W * parts[1], y, h, lc, a * 0.5, now, 2.2, (W * parts[1] + 60) / 0.9);
		else
			Off(P.shieldSheen);
		end
	else
		Off(P.front);
		Off(P.frontGlow);
		Off(P.shieldSheen);
	end
end

-- The shield as a mark only (shieldStyle "marker"): the bar's right end, shieldMark % of it,
-- covered while you have any shield at all; it doesn't shrink as the shield wears.
local function Marker(s, W, y, h, now, a)
	local c = s.shield1;
	local energy = s.shieldLook == "energy";
	local breath = energy and ( 0.9 + 0.1 * math.sin(now * 3.1) ) or 1;
	local hit = 0;
	if ( s.shieldFx and B.hitAt and now - B.hitAt < 0.25 ) then
		hit = 1 - (now - B.hitAt) / 0.25;
	end
	local mw = W * math.max(1, math.min(100, s.shieldMark)) / 100;
	local x0 = W - mw;
	Put(P.shield1, x0, y, mw, h, c[1], c[2], c[3], a * ( s.shieldAlpha * ( energy and 0.34 or 0.55 ) * breath + hit * 0.3 ));
	if ( energy ) then
		local lh = math.max(1, h * 0.14);
		Put(P.shieldTop1, x0, y + h - lh, mw, lh, c[1], c[2], c[3], a * math.min(1, s.shieldAlpha + 0.25));
	else
		Off(P.shieldTop1);
	end
	for k = 2, 3 do
		Off(P["shield" .. k]);
		Off(P["shieldTop" .. k]);
	end
	-- its inner edge: a bright line; a light running across it
	local lc = { 0.6 + 0.4 * c[1], 0.6 + 0.4 * c[2], 0.6 + 0.4 * c[3] };
	Put(P.front, x0, y, 2, h, lc[1], lc[2], lc[3], a * (0.9 + 0.1 * hit));
	Off(P.frontGlow);
	if ( energy and s.shieldSheen ) then
		Sweep(P.shieldSheen, x0, W, y, h, lc, a * 0.5, now, 2.2, (mw + 60) / 0.9);
	else
		Off(P.shieldSheen);
	end
end

-- Your level in the run (the game's run line, else the client's), nil with none.
local function LevelNow()
	local lv = ( B.test and GetTime() < B.test ) and 12 or ( tonumber(AZS_RUN and AZS_RUN.lvl)
		or ( UnitLevel and UnitLevel("player") ) );
	return lv and lv > 0 and lv or nil;
end

-- Your level as a part at the bar's left end ("left"): its text set, and how wide the part is (0:
-- none). Drawn as part of the bar: its background, a line between, the border round both (the
-- user's players, 2026-11-26: a box apart with a gap was "gross").
local function LevelPart(s, H)
	local lv = s.level and s.levelPos == "left" and LevelNow();
	if ( not lv ) then
		return 0;
	end
	local fs = P.levelFs;
	Font(fs, s.levelSize);
	fs:SetText(tostring(lv));
	local tw = ( fs.GetStringWidth and fs:GetStringWidth() ) or s.levelSize * 0.6 * string.len(tostring(lv));
	-- just the number with a little room round it (players: "thinner width wise, basically just
	-- housing the number")
	return math.floor(math.max(tw + 6, s.levelSize * 0.8) + 0.5);
end

-- Your level: the part at the bar's left end (lw px wide), inside it at its left, or over it.
local function Level(s, W, H, y0, a, lw)
	local lv = LevelNow();
	if ( not s.level or not lv ) then
		Off(P.levelBg);
		Off(P.levelLine);
		P.levelFs:Hide();
		return;
	end
	local fs, c = P.levelFs, s.levelRGB;
	Font(fs, s.levelSize);
	fs:SetText(tostring(lv));
	fs:SetTextColor(c[1], c[2], c[3], a);
	fs:ClearAllPoints();
	if ( s.levelPos == "inside" ) then
		fs:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
		Off(P.levelBg);
		Off(P.levelLine);
	elseif ( s.levelPos == "above" ) then
		fs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2);
		Off(P.levelBg);
		Off(P.levelLine);
	else
		Put(P.levelBg, -lw, 0, lw, H + y0, 0, 0, 0, a * math.max(s.bgAlpha, 0.35));
		Put(P.levelLine, -1, 0, 1, H + y0, 0.02, 0.02, 0.03, a * 0.9);
		fs:SetPoint("CENTER", f, "BOTTOMLEFT", -lw / 2, (H + y0) / 2);
	end
	fs:Show();
end

function B.Paint(now, dt)
	local s = B.S();
	if ( not s ) then
		return;
	end
	local hp, mx, sh, pw, pmx, kind = B.Read(now);
	local W, H = s.width, s.height;
	local ph = ( s.power and pmx > 0 ) and s.powerHeight or 0;
	local y0 = ph > 0 and ph + 1 or 0;
	if ( f.w ~= W or f.h ~= H + y0 ) then
		f:SetWidth(W);
		f:SetHeight(H + y0);
		f.w, f.h = W, H + y0;
	end
	if ( mx <= 0 ) then
		if ( f.alphaSet ~= 0 ) then
			f:SetAlpha(0);
			f.alphaSet = 0;
		end
		return;
	end
	local frac = math.max(0, math.min(1, hp / mx));
	-- what's shown eases to what is; what was lost lingers, then drains away
	B.hp = B.hp or frac;
	if ( s.smooth ) then
		B.hp = B.hp + (frac - B.hp) * math.min(1, dt * 12);
	else
		B.hp = frac;
	end
	if ( not B.trail or frac >= B.trail ) then
		B.trail, B.trailAt = frac, now;
	elseif ( now - (B.trailAt or now) > 0.35 ) then
		B.trail = math.max(frac, B.trail - dt * 0.9);
	end
	-- the shield: eased the same way; worn (a hit) and broken (all gone) noticed
	local sfrac = math.max(0, sh / mx);
	B.sh = B.sh or sfrac;
	-- (not for one that ran out by its time: nothing hit it or broke it)
	local ranOut = B.ranOut and now - B.ranOut < 0.5;
	if ( sfrac < B.sh - 0.01 and not ranOut ) then
		B.hitAt = now;
	end
	if ( sfrac <= 0 and B.sh > 0.02 and not ranOut ) then
		B.breakAt, B.breakColor = now, s.shield1;
	end
	if ( s.smooth ) then
		B.sh = B.sh + (sfrac - B.sh) * math.min(1, dt * 10);
	else
		B.sh = sfrac;
	end
	-- faded while full with no shield, if wanted
	local alpha = s.alpha;
	if ( s.fadeFull and frac >= 0.999 and sfrac <= 0 and not ( B.test and GetTime() < B.test ) ) then
		alpha = s.alpha * s.fadeAlpha;
	end
	if ( f.alphaSet ~= 1 ) then
		f:SetAlpha(1);
		f.alphaSet = 1;
	end
	local a = alpha;
	local tex = s.texture == "flat" and SOLID or SHADED;
	if ( P.fill.path ~= tex ) then
		P.fill:SetTexture(tex);
		P.power:SetTexture(tex);
		P.fill.path, P.fill.l, P.power.l = tex, nil, nil;
	end
	-- your level as a part at its left end (lw px), inside its border
	local lw = LevelPart(s, H + y0);
	-- the frame round it
	Put(P.bg, 0, 0, W, H + y0, 0, 0, 0, a * s.bgAlpha);
	if ( s.border ) then
		-- a thin dark line round it, red and pulsing at low health
		local low = s.lowAt > 0 and frac < s.lowAt / 100;
		local pulse = low and ( 0.5 + 0.5 * math.sin(now * 7) ) or 0;
		local er, eg, eb, ea = 0.02 + 0.85 * pulse, 0.02 + 0.08 * pulse, 0.03, a * (0.9 + 0.1 * pulse);
		local th = 1 + pulse;
		Put(P.edgeB, -lw - th, -th, W + lw + 2 * th, th, er, eg, eb, ea);
		Put(P.edgeT, -lw - th, H + y0, W + lw + 2 * th, th, er, eg, eb, ea);
		Put(P.edgeL, -lw - th, 0, th, H + y0, er, eg, eb, ea);
		Put(P.edgeR, W, 0, th, H + y0, er, eg, eb, ea);
	else
		Off(P.edgeB);
		Off(P.edgeT);
		Off(P.edgeL);
		Off(P.edgeR);
	end
	-- health, what's draining, the gloss, the low-health pulse, the sweep of light
	local r, g, b = HealthColor(s, frac);
	local fw = W * B.hp;
	-- where the health starts: the bar's left end, or its right (hpFrom "right": all of it mirrored)
	local hr = s.hpFrom == "right";
	local fx = hr and ( W - fw ) or 0;
	if ( s.trail and B.trail > B.hp + 0.002 ) then
		local tw = W * (B.trail - B.hp);
		Put(P.trail, hr and ( fx - tw ) or fw, y0, tw, H, 1, 0.62, 0.4, a * 0.7);
	else
		Off(P.trail);
	end
	if ( hr ) then
		Coords(P.fill, 1 - math.max(0.01, B.hp), 1, 0, 1);
	else
		Coords(P.fill, 0, math.max(0.01, B.hp), 0, 1);
	end
	Put(P.fill, fx, y0, fw, H, r, g, b, a);
	if ( s.gloss and P.gloss.SetGradientAlpha and fw > 1 ) then
		-- light at its top fading down (a gradient: its colour isn't set the usual way, which would undo it)
		local gl = P.gloss;
		Put(gl, fx, y0 + H * 0.45, fw, H * 0.55, 1, 1, 1, 1);
		if ( gl.ga ~= a ) then
			gl:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22 * a);
			gl.ga = a;
		end
	else
		Off(P.gloss);
	end
	if ( s.lowAt > 0 and frac < s.lowAt / 100 ) then
		Put(P.low, fx, y0, fw, H, 1, 0.1, 0.05, a * 0.3 * (0.5 + 0.5 * math.sin(now * 7)));
	else
		Off(P.low);
	end
	if ( s.sheen and fw > 4 ) then
		Sweep(P.sheen, fx, fx + fw, y0, H, WHITE, a * 0.28, now, 3.5, (W + 80) / 1.2);
	else
		Off(P.sheen);
	end
	-- the shield's layers (or its mark only)
	if ( s.shield and s.shieldStyle == "marker" and sfrac > 0 ) then
		Marker(s, W, y0, H, now, a);
	elseif ( s.shield and s.shieldStyle ~= "marker" and B.sh > 0.002 ) then
		Shields(s, B.sh, W, y0, H, now, a);
	else
		for k = 1, 3 do
			Off(P["shield" .. k]);
			Off(P["shieldTop" .. k]);
		end
		Off(P.front);
		Off(P.frontGlow);
		Off(P.shieldSheen);
	end
	-- broken: a flash of its colour over the bar, a burst of light
	if ( s.shield and s.shieldFx and B.breakAt and now - B.breakAt < 0.5 ) then
		local k = (now - B.breakAt) / 0.5;
		local c = B.breakColor or s.shield1;
		Put(P.flash, 0, y0, W, H, c[1], c[2], c[3], a * 0.55 * (1 - k));
		Coords(P.burst, 0, 1, 0, 1);
		Put(P.burst, -W * 0.1 * k, y0 - H * (0.5 + k), W * (1 + 0.2 * k), H * (2 + 2 * k), c[1], c[2], c[3], a * 0.5 * (1 - k));
	else
		Off(P.flash);
		Off(P.burst);
	end
	-- mana (or rage, energy) under it
	if ( ph > 0 ) then
		local pc = POWER[kind] or POWER[0];
		local pf = math.max(0, math.min(1, pw / pmx));
		Put(P.powerBg, 0, 0, W, ph, pc[1] * 0.25, pc[2] * 0.25, pc[3] * 0.25, a * 0.8);
		Coords(P.power, 0, math.max(0.01, pf), 0, 1);
		Put(P.power, 0, 0, W * pf, ph, pc[1], pc[2], pc[3], a);
	else
		Off(P.powerBg);
		Off(P.power);
	end
	-- the numbers (with your shield added, if wanted: health + shield, of your max health)
	local text = Text(s, hp + ( s.textShield and sh or 0 ), mx);
	Font(P.text, s.textSize);
	if ( text ~= "" ) then
		P.text:ClearAllPoints();
		if ( s.textPos == "left" ) then
			P.text:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
		elseif ( s.textPos == "right" ) then
			P.text:SetPoint("RIGHT", f, "BOTTOMRIGHT", -4, y0 + H / 2);
		elseif ( s.textPos == "above" ) then
			P.text:SetPoint("BOTTOM", f, "TOP", 0, 2);
		else
			P.text:SetPoint("CENTER", f, "BOTTOM", 0, y0 + H / 2);
		end
		P.text:SetText(text);
		P.text:SetTextColor(1, 1, 1, a);
		P.text:Show();
	else
		P.text:Hide();
	end
	if ( s.shield and s.shieldText and sh > 0 ) then
		local c = sfrac > 2 and s.shield3 or ( sfrac > 1 and s.shield2 or s.shield1 );
		Font(P.shieldTextFs, math.max(8, s.textSize - 1));
		P.shieldTextFs:ClearAllPoints();
		if ( s.textPos == "right" ) then
			P.shieldTextFs:SetPoint("LEFT", f, "BOTTOMLEFT", 4, y0 + H / 2);
		else
			P.shieldTextFs:SetPoint("RIGHT", f, "BOTTOMRIGHT", -4, y0 + H / 2);
		end
		P.shieldTextFs:SetText("+" .. math.floor(sh + 0.5));
		P.shieldTextFs:SetTextColor(0.55 + 0.45 * c[1], 0.55 + 0.45 * c[2], 0.55 + 0.45 * c[3], a);
		P.shieldTextFs:Show();
	else
		P.shieldTextFs:Hide();
	end
	Level(s, W, H, y0, a, lw);
	-- unlocked: a handle and a hint, and it takes the mouse
	if ( not s.locked ) then
		Put(P.handle, -3 - lw, -3, W + lw + 6, H + y0 + 6, 0.75, 0.55, 1, 0.25 + 0.1 * math.sin(now * 4));
		Font(P.hint, 10);
		P.hint:ClearAllPoints();
		P.hint:SetPoint("BOTTOM", f, "TOP", 0, s.textPos == "above" and 16 or 4);
		P.hint:SetText(AST_L("Drag to move, right-click to lock"));
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
-- The icons: skills, jewelry, buffs

local function Icon(n)
	local ic = B.icons[n];
	if ( ic ) then
		return ic;
	end
	ic = CreateFrame("Frame", nil, f);
	ic.bg = ic:CreateTexture(nil, "BACKGROUND");
	ic.bg:SetTexture(SOLID);
	ic.bg:SetVertexColor(0, 0, 0, 0.85);
	ic.bg:SetPoint("TOPLEFT", ic, "TOPLEFT", -1, 1);
	ic.bg:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, -1);
	ic.tex = ic:CreateTexture(nil, "ARTWORK");
	ic.tex:SetAllPoints(ic);
	ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	ic.shade = ic:CreateTexture(nil, "OVERLAY");
	ic.shade:SetTexture(SOLID);
	ic.shade:SetVertexColor(0, 0, 0, 0.62);
	ic.glow = ic:CreateTexture(nil, "OVERLAY");
	ic.glow:SetTexture(RIM);
	if ( ic.glow.SetBlendMode ) then
		ic.glow:SetBlendMode("ADD");
	end
	ic.glow:SetPoint("CENTER", ic, "CENTER", 0, 0);
	ic.glow:Hide();
	local font = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
	ic.time = ic:CreateFontString(nil, "OVERLAY");
	ic.time:SetFont(font, 10, "OUTLINE");
	ic.time:SetPoint("CENTER", ic, "CENTER", 0, 0);
	ic.stack = ic:CreateFontString(nil, "OVERLAY");
	ic.stack:SetFont(font, 9, "OUTLINE");
	ic.stack:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, 1);
	B.icons[n] = ic;
	return ic;
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

-- A skill slot's name (its tooltip's first line), kept while its icon stays the same.
local function SlotName(slot, tex)
	local c = B.names[slot];
	if ( not c or c.tex ~= tex ) then
		local lines = AST.TipLines and AST.TipLines("SetAction", slot);
		c = { tex = tex, name = lines and lines[1] };
		B.names[slot] = c;
	end
	return c.name;
end

-- The icons each group shows now: { tex, left, max, stacks, key }.
local function Gather(s)
	local groups = {};
	local now = GetTime();
	if ( B.test and now < B.test ) then
		local t = 8 - (B.test - now);
		local function cd(per, off)
			local k = (t + off) - math.floor((t + off) / per) * per;
			return per - k, per;
		end
		local a1, m1 = cd(3, 0);
		local a2, m2 = cd(5, 1.5);
		local a3, m3 = cd(2.2, 0.4);
		groups.skills = { { tex = "Interface\\Icons\\Spell_Holy_HolyNova", left = a1 > 2.6 and 0 or a1, max = m1, key = "d1" },
			{ tex = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", left = a2, max = m2, key = "d2" },
			{ tex = "Interface\\Icons\\Spell_Frost_FrostNova", left = a3 > 1.8 and 0 or a3, max = m3, key = "d3" },
			{ tex = "Interface\\Icons\\Spell_Fire_FlameBolt", left = 0, max = 1, key = "d4" } };
		groups.jewelry = { { tex = "Interface\\Icons\\INV_Jewelry_Necklace_07", left = math.max(0, 6 - t), max = 6, key = "d5" },
			{ tex = "Interface\\Icons\\INV_Misc_Gem_Pearl_04", left = 0, max = 1, key = "d6" } };
		groups.buffs = { { tex = "Interface\\Icons\\Spell_Nature_LightningShield", left = 12 - t, max = 12, stacks = 3, key = "d7" },
			{ tex = "Interface\\Icons\\Spell_Holy_HealingAura", left = 0, max = 0, key = "d8" } };
		return groups;
	end
	if ( s.skills and GetActionTexture ) then
		local list = {};
		for i = 1, table.getn(SKILL_SLOTS) do
			local slot = SKILL_SLOTS[i];
			local tex = GetActionTexture(slot);
			if ( tex ) then
				local left, max;
				local name = SlotName(slot, tex);
				if ( name and AST.CooldownOf ) then
					left, max = AST.CooldownOf(name);
				end
				if ( not max and GetActionCooldown ) then
					local start, dur = GetActionCooldown(slot);
					if ( start and dur and dur > 0 and start > 0 ) then
						left, max = start + dur - now, dur;
					end
				end
				table.insert(list, { tex = tex, left = left or 0, max = max or 0, key = "s" .. slot, name = name });
			end
		end
		groups.skills = list;
	end
	-- the clocks (jewelry's among them), by name
	local clocks = {};
	if ( s.jewelry and type(AZS_GetTimers) == "function" ) then
		local ok, timers = pcall(AZS_GetTimers);
		for i = 1, table.getn(ok and timers or {}) do
			local t = timers[i];
			if ( type(t) == "table" and t.name ) then
				clocks[t.name] = t;
			end
		end
	end
	local worn = {};
	if ( s.jewelry ) then
		-- the jewelry you wear: the meter's copy of your loadout (each piece's name and icon), its
		-- clock if it has one
		local list = {};
		local st = AZS_ML and AZS_ML.st;
		local l = st and st.owner and st.loadouts and st.loadouts[st.owner];
		local sources = st and st.sources or {};
		for i = 1, table.getn(l and l.runJewelry or {}) do
			local x = l.runJewelry[i];
			local src = type(x) == "table" and sources[x.sourceKey];
			local icon = type(src) == "table" and type(src.icon) == "table" and src.icon.status == "ready" and src.icon.path;
			if ( src and IconPath(icon) and x.learned ~= false ) then
				local c = src.name and clocks[src.name];
				if ( src.name ) then
					worn[src.name] = true;
				end
				table.insert(list, { tex = IconPath(icon), left = c and c.remaining or 0, max = c and c.duration or 0,
					key = "j" .. tostring(x.itemInstanceKey or x.sourceKey), name = src.name });
			end
		end
		groups.jewelry = list;
	end
	if ( s.buffs and UnitBuff ) then
		local list = {};
		for i = 1, 32 do
			if ( table.getn(list) >= s.buffsMax ) then
				break;
			end
			local tex, apps = UnitBuff("player", i);
			if ( not tex ) then
				break;
			end
			local left = 0;
			if ( GetPlayerBuff and GetPlayerBuffTimeLeft ) then
				local id = GetPlayerBuff(i - 1, "HELPFUL");
				left = ( id and id >= 0 ) and ( GetPlayerBuffTimeLeft(id) or 0 ) or 0;
			end
			-- its length: the longest seen of it
			local mx = math.max(left, B.buffMax[tex] or 0);
			B.buffMax[tex] = mx;
			table.insert(list, { tex = tex, left = left, max = mx, stacks = apps, key = "b" .. tex, buff = true, index = i });
		end
		groups.buffs = list;
	end
	return groups;
end

-- Which icons each class shows (the user, 2026-11-25: "so people can display only the skills they
-- want to see"): for each class and group, everything that has been on its bar, by its icon (the
-- same in every language) with the name it had: s.pick[class][group][key] = { n = name, t = texture,
-- off = true while it's not shown }. At most PICK_MAX a group (buffs come and go).
local PICK_MAX = 40;

function B.Picks(class, group)
	local s = B.S();
	-- buffs and jewelry are chosen once for every class (the user, 2026-11-25); skills class by class
	if ( group ~= "skills" ) then
		class = "all";
	end
	if ( not s or not class ) then
		return nil;
	end
	s.pick = s.pick or {};
	local c = s.pick[class];
	if ( not c ) then
		c = {};
		s.pick[class] = c;
	end
	if ( not c[group] ) then
		c[group] = {};
	end
	return c[group];
end

-- An icon's key: its path with A to Z lowered (only those: the code page could turn other bytes).
local function PickKey(tex)
	return (string.gsub(tostring(tex), "[A-Z]", function(c) return string.char(string.byte(c) + 32); end));
end

-- What's on the bar now remembered for your class (a buff's name read from its tooltip the first
-- time); the ones turned off for it left out.
local function Choose(groups, class)
	for group, list in pairs(groups) do
		local picks = B.Picks(class, group);
		if ( picks ) then
			local count = 0;
			for _ in pairs(picks) do
				count = count + 1;
			end
			for i = table.getn(list), 1, -1 do
				local it = list[i];
				local key = PickKey(it.tex);
				local e = picks[key];
				if ( not e and count < PICK_MAX ) then
					local name = it.name;
					if ( not name and it.index ) then
						local lines = BuffLines(it.index);
						name = lines and lines[1];
					end
					if ( not name ) then
						-- no name to be read: its icon's ("Spell_Holy_HolyNova" -> "Spell Holy HolyNova")
						local _, _, file = string.find(tostring(it.tex), "([^\\]+)$");
						name = file and string.gsub(file, "_", " ");
					end
					e = { t = it.tex, n = name };
					picks[key] = e;
					count = count + 1;
					B.seenV = (B.seenV or 0) + 1;
				end
				if ( e and not e.n and it.name ) then
					e.n = it.name;
				end
				if ( e and e.off ) then
					table.remove(list, i);
				end
			end
		end
	end
end

-- Everything a group can hold, to choose from on the Hero bar page: the catalog's (HeroCatalog.lua:
-- the class's skills; every buff and every piece of jewelry, the same for every class) and then
-- whatever else has been on the bar (a buff from a talent or an amulet...). One entry an icon (two
-- skills with one icon are one choice, as the bar can't tell them apart): { key, name, icon, e },
-- e its saved entry (nil until it's been on the bar or chosen).
function B.Choices(class, group)
	local out, at = {}, {};
	local cat = B.catalog or {};
	local lists = {};
	if ( group == "jewelry" ) then
		lists = { { cat.jewelry } };
	elseif ( group == "skills" ) then
		lists = { { cat.skills and cat.skills[class] } };
	elseif ( group == "buffs" ) then
		lists = { { cat.buffs } };
	end
	local picks = B.Picks(class, group) or {};
	for l = 1, table.getn(lists) do
		local list = lists[l][1];
		for i = 1, table.getn(list or {}) do
			local name, icon = list[i][1], IconPath(list[i][2]);
			local key = icon and PickKey(icon);
			if ( key and at[key] ) then
				at[key].name = at[key].name .. " / " .. AST_GameName(name);
			elseif ( key ) then
				local c = { key = key, name = AST_GameName(name), icon = icon, e = picks[key] };
				at[key] = c;
				table.insert(out, c);
			end
		end
	end
	-- then what else has been on the bar, by name
	local more = {};
	for key, e in pairs(picks) do
		if ( not at[key] ) then
			table.insert(more, { key = key, name = e.n or key, icon = e.t, e = e });
		end
	end
	table.sort(more, function(a, b) return a.name < b.name; end);
	for i = 1, table.getn(more) do
		table.insert(out, more[i]);
	end
	return out;
end

-- Show or hide choice c (from B.Choices) for class's group.
function B.SetChoice(class, group, c, off)
	local picks = B.Picks(class, group);
	if ( not picks ) then
		return;
	end
	local e = picks[c.key];
	if ( not e ) then
		e = { t = c.icon, n = c.name };
		picks[c.key] = e;
		c.e = e;
	end
	e.off = off or nil;
end

-- Lays the icons out in rows (a row a group, or one row), under or over the bar.
function B.Icons(now)
	local s = B.S();
	if ( not s ) then
		return;
	end
	local groups = Gather(s);
	local _, _, class = AST.State();
	if ( class and not ( B.test and GetTime() < B.test ) ) then
		Choose(groups, class);
	end
	-- skills only while on cooldown (the user, 2026-11-26): each from its cast until it's back, and the
	-- glow's moment longer when it glows as it's ready
	if ( s.skillsCooling and groups.skills ) then
		local keep, linger = {}, ( s.cooldowns and s.glow ) and 0.7 or 0;
		B.cooled = B.cooled or {};
		for i = 1, table.getn(groups.skills) do
			local d = groups.skills[i];
			if ( d.left and d.left > 0.05 and d.max and d.max > 0 ) then
				B.cooled[d.key] = true;
				table.insert(keep, d);
			else
				if ( B.cooled[d.key] == true ) then
					B.cooled[d.key] = now;
				end
				if ( type(B.cooled[d.key]) == "number" and now - B.cooled[d.key] < linger ) then
					table.insert(keep, d);
				end
			end
		end
		groups.skills = keep;
	end
	local rows = {};
	local order = { "skills", "jewelry", "buffs" };
	local one = s.iconRows == "one" and {} or nil;
	for i = 1, table.getn(order) do
		local g = groups[order[i]];
		if ( g and table.getn(g) > 0 and s[order[i]] ~= false ) then
			if ( one ) then
				for k = 1, table.getn(g) do
					table.insert(one, g[k]);
				end
			else
				table.insert(rows, g);
			end
		end
	end
	if ( one and table.getn(one) > 0 ) then
		rows = { one };
	end
	local size, gap = s.iconSize, s.iconGap;
	local cd = s.cooldowns;
	local n = 0;
	local below = s.iconSide ~= "above";
	local font = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF";
	for r = 1, table.getn(rows) do
		local row = rows[r];
		local count = table.getn(row);
		local rw = count * size + (count - 1) * gap;
		local x0 = 0;
		if ( s.iconAlign == "center" ) then
			x0 = (s.width - rw) / 2;
		elseif ( s.iconAlign == "right" ) then
			x0 = s.width - rw;
		end
		local dy = (r - 1) * (size + gap) + gap + 2;
		for k = 1, count do
			local d = row[k];
			n = n + 1;
			local ic = Icon(n);
			ic:ClearAllPoints();
			if ( below ) then
				ic:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x0 + (k - 1) * (size + gap), -dy);
			else
				ic:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x0 + (k - 1) * (size + gap), dy + ( s.textPos == "above" and 14 or 0 ));
			end
			ic:SetWidth(size);
			ic:SetHeight(size);
			if ( ic.path ~= d.tex ) then
				ic.tex:SetTexture(d.tex);
				ic.path = d.tex;
			end
			local cooling = d.left and d.left > 0.05 and d.max and d.max > 0;
			-- ready again: a glow for a moment
			if ( ic.key == d.key and ic.cooling and not cooling and not d.buff ) then
				ic.readyAt = now;
			end
			ic.key, ic.cooling = d.key, cooling;
			if ( ic.tex.SetDesaturated ) then
				ic.tex:SetDesaturated(( cd and s.grey and cooling and not d.buff ) and 1 or nil);
			end
			-- the shade: what's left of the cooldown, from the top
			if ( cd and s.sweep and cooling and not d.buff ) then
				local k2 = math.max(0, math.min(1, d.left / d.max));
				ic.shade:ClearAllPoints();
				ic.shade:SetPoint("TOPLEFT", ic, "TOPLEFT", 0, 0);
				ic.shade:SetWidth(size);
				ic.shade:SetHeight(math.max(0.5, size * k2));
				ic.shade:Show();
			else
				ic.shade:Hide();
			end
			if ( ic.fsize ~= size ) then
				ic.time:SetFont(font, math.max(8, math.floor(size * 0.45)), "OUTLINE");
				ic.stack:SetFont(font, math.max(7, math.floor(size * 0.38)), "OUTLINE");
				ic.fsize = size;
			end
			if ( cd and s.timers and d.left and d.left > 0.05 ) then
				local left = d.left;
				ic.time:SetText(( left >= 60 and ( math.floor(left / 60) .. "m" ) ) or ( left >= 10 and tostring(math.floor(left)) )
					or string.format("%.1f", left));
				-- the last 3 sec in orange
				ic.time:SetTextColor(1, left < 3 and 0.6 or 1, left < 3 and 0.3 or 1);
				ic.time:Show();
			else
				ic.time:Hide();
			end
			if ( d.stacks and d.stacks > 1 ) then
				ic.stack:SetText(tostring(d.stacks));
				ic.stack:Show();
			else
				ic.stack:Hide();
			end
			if ( cd and s.glow and ic.readyAt and now - ic.readyAt < 0.7 ) then
				local k3 = (now - ic.readyAt) / 0.7;
				ic.glow:SetWidth(size * (1.9 + 0.4 * k3));
				ic.glow:SetHeight(size * (1.9 + 0.4 * k3));
				ic.glow:SetVertexColor(1, 0.9, 0.5, 1 - k3);
				ic.glow:Show();
			else
				ic.glow:Hide();
			end
			ic:Show();
		end
	end
	for i = n + 1, table.getn(B.icons) do
		B.icons[i]:Hide();
	end
	B.shown.icons = n;
end

---------------------------------------------------------------------------------------------
-- Where it is: on the screen where you put it, or floating over your hero

-- Whether the bar is anchored by `point` at x, y now: something else may have moved it (the game puts
-- frames you've dragged back where they were last time, after the addon has placed them), and it's
-- then put back at once rather than when you next move.
local function At(point, x, y)
	local p1, _, _, x1, y1 = f:GetPoint();
	return p1 == point and x1 ~= nil and y1 ~= nil and math.abs(x1 - x) < 0.5 and math.abs(y1 - y) < 0.5;
end

function B.Place(now)
	local s = B.S();
	if ( f.scaleSet ~= s.scale ) then
		f:SetScale(s.scale);
		f.scaleSet = s.scale;
	end
	-- (being dragged: where the mouse takes it)
	if ( f.dragging ) then
		return;
	end
	local follow = s.anchor == "hero" or s.anchor == "under";
	AST.wantMap = follow or nil;
	if ( follow and AST.draw and AST.mapAt and GetTime() - AST.mapAt < 0.5 ) then
		local H = AST.draw.H;
		local was = H.dz;
		-- over you: that high above your feet; under you: at your feet
		H.dz = s.anchor == "hero" and s.above or 0;
		local x, y = AST.draw.Map(0, 0);
		H.dz = was;
		if ( x ) then
			-- the map's units are WorldFrame's; the bar's its own (UI scale, its scale)
			local k = (WorldFrame:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1);
			x, y = x * k, y * k;
			local point = "BOTTOM";
			if ( s.anchor == "under" ) then
				-- its top that far under your feet (the gap in the screen's units, so its own / its scale)
				point, y = "TOP", y - (s.below or 20) / (s.scale or 1);
			end
			if ( not f.hx or math.abs(f.hx - x) > 0.4 or math.abs(f.hy - y) > 0.4 or f.where ~= s.anchor
				or not At(point, f.hx, f.hy) ) then
				f:ClearAllPoints();
				f:SetPoint(point, UIParent, "BOTTOMLEFT", x, y);
				f.hx, f.hy, f.where = x, y, s.anchor;
			end
			-- where that is on the screen (its units: the bar's times its scale), kept for when there's
			-- no map yet
			local m, ux, uy = s.lastAt, x * (s.scale or 1), y * (s.scale or 1);
			if ( not m ) then
				m = {};
				s.lastAt = m;
			end
			if ( m.anchor ~= s.anchor or m.point ~= point or math.abs((m.x or 0) - ux) > 1 or math.abs((m.y or 0) - uy) > 1 ) then
				m.anchor, m.point, m.x, m.y = s.anchor, point, ux, uy;
			end
			return;
		end
	end
	-- following you with no map yet (a game's first moments, before your hero's place on the screen is
	-- known; the user, 2026-11-25: it sat out of place until you moved): where it last was over or
	-- under you, not where it was once dragged to
	local m = s.lastAt;
	if ( follow and m and m.anchor == s.anchor and m.x and m.y ) then
		local x, y = m.x / (s.scale or 1), m.y / (s.scale or 1);
		if ( f.where ~= "last" or not At(m.point, x, y) ) then
			f:ClearAllPoints();
			f:SetPoint(m.point, UIParent, "BOTTOMLEFT", x, y);
			f.where = "last";
		end
		return;
	end
	-- its offsets are kept in the screen's units; the game reads them in the bar's own (times its
	-- scale), so they're divided by it: its point stays where it is as its scale changes (the user,
	-- 2026-11-25: it moved off as the scale went down)
	local sc = s.scale or 1;
	if ( f.where ~= "screen" or f.px ~= s.x or f.py ~= s.y or f.pp ~= s.point or f.ps ~= sc
		or not At(s.point or "BOTTOM", s.x / sc, s.y / sc) ) then
		f:ClearAllPoints();
		f:SetPoint(s.point or "BOTTOM", UIParent, s.rel or s.point or "BOTTOM", s.x / sc, s.y / sc);
		f.where, f.px, f.py, f.pp, f.ps = "screen", s.x, s.y, s.point, sc;
	end
end

---------------------------------------------------------------------------------------------
-- Each frame

local driver = CreateFrame("Frame", "ASTHeroBarDriver", UIParent);
local acc, last = 0, nil;
driver:SetScript("OnUpdate", function()
	local s = B.S();
	if ( not s ) then
		return;
	end
	local now = GetTime();
	local dt = last and math.min(0.5, now - last) or 0;
	last = now;
	if ( B.dirty or not B.parkedOnce ) then
		B.parkedOnce, B.dirty = true, nil;
		B.Park();
		B.buildUntil = now + 5;
	end
	-- "Hide your skill icons": put on again at the start (and on entering the world) and kept for a few
	-- seconds (Survivor UI shows the game's row again as you enter, once its Build list is off), then
	-- left alone
	if ( s.hideBuild and B.buildUntil and now < B.buildUntil and type(AZS_SetHudShown) == "function"
		and type(AZS_IsHudShown) == "function" and AZS_IsHudShown("build") ) then
		AZS_SetHudShown("build", false);
	end
	-- (a Test press shows it even while it's off)
	-- The game's cards up (a level's, a new piece of jewelry): put away. The game draws over its veil
	-- any art its card screen shows too (your spells' icons in its row of spells), so a skill's icon
	-- here would come through on the cards (the user, 2026-11-26: Power Word: Shield's on a card).
	if ( ( not s.on and not B.Testing() ) or AST.CardsUp() ) then
		if ( f ) then
			f:Hide();
		end
		AST.wantMap = nil;
		return;
	end
	if ( not f ) then
		Make();
	end
	f:Show();
	B.Place(now);
	B.Paint(now, dt);
	acc = acc + dt;
	if ( acc >= 0.1 or not B.shown.icons ) then
		acc = 0;
		B.Icons(now);
	end
end);

-- Entering the world: the game's frames put away again, "Hide your skill icons" kept a few seconds
-- more (above), and Survivor UI's modules that wait for a reload (its Unit frames, its Buffs) taken
-- as they are now: they run as they were set then until the next reload, whatever its setting says
-- meanwhile (Options' notes say so; the user, 2026-11-26, with all its modules switched off but not
-- reloaded).
driver:RegisterEvent("PLAYER_ENTERING_WORLD");
driver:SetScript("OnEvent", function()
	B.dirty = true;
	if ( type(SurvivorUI_Feature) == "function" ) then
		B.sui = { unitFrames = SurvivorUI_Feature("unitFrames") and true or false,
			buffs = SurvivorUI_Feature("buffs") and true or false };
	end
end);

-- A Test press: the demo for 8 sec (shown even while the bar is off; your settings unchanged); a
-- second press while it plays stops it.
function B.Testing()
	return B.test ~= nil and GetTime() < B.test;
end

function B.Test()
	if ( B.Testing() ) then
		B.test = nil;
	else
		B.test = GetTime() + 8;
	end
	B.hp, B.sh, B.trail = nil, nil, nil;
end

-- /ast what: the frame under the mouse, and what it sits in.
function B.What()
	local fr = GetMouseFocus and GetMouseFocus();
	local chain = {};
	local guard = 0;
	while ( fr and guard < 12 ) do
		table.insert(chain, ( fr.GetName and fr:GetName() ) or "(no name)");
		fr = fr.GetParent and fr:GetParent();
		guard = guard + 1;
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: under the mouse: "
		.. ( table.getn(chain) > 0 and table.concat(chain, " < ") or "nothing" ));
	local hidden = B.Hidden();
	if ( table.getn(hidden) > 0 ) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: hidden by the hero bar's settings: " .. table.concat(hidden, ", "));
	end
end
