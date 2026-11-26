-- The options window. Its pages are tabs down the left side: General (what isn't one
-- telegraph's), one per class that has telegraphs, yours first, and Any class (the telegraphs
-- any hero can use). A telegraph page lists its telegraphs by kind, with the chosen one's settings
-- beside the list. Core.lua hands over what the window needs as AST.

local SOLID = AST.solid;
local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
};
local FLAT = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 10,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
};
local PRESETS = {
	{ 1, 0.25, 0.25 }, { 1, 0.6, 0.15 }, { 1, 0.95, 0.3 }, { 0.35, 1, 0.35 },
	{ 0.3, 0.9, 1 }, { 0.35, 0.5, 1 }, { 0.75, 0.45, 1 }, { 1, 1, 1 },
};
-- class names in their usual colours
local CLASS_COLORS = {
	warrior = { 0.78, 0.61, 0.43 }, paladin = { 0.96, 0.55, 0.73 }, hunter = { 0.67, 0.83, 0.45 },
	rogue = { 1, 0.96, 0.41 }, priest = { 1, 1, 1 }, shaman = { 0, 0.44, 0.87 },
	mage = { 0.41, 0.8, 0.94 }, warlock = { 0.58, 0.51, 0.79 }, druid = { 1, 0.49, 0.04 },
};
local KINDS = { "Spells", "Ranges", "Talents", "Amulets", "Sets", "Racial", "Guardians", "Other", "Experimental",
	"Tools", "Polish", "Time", "Signature", "Textures" };
local ICONS = {
	general = "Interface\\Icons\\INV_Misc_Gear_01",
	common = "Interface\\Icons\\INV_Misc_Gem_01",
	class = "Interface\\Icons\\INV_Misc_QuestionMark",
	addon = "Interface\\Icons\\Spell_Holy_HolyNova",
	hero = "Interface\\Icons\\Spell_Holy_SealOfProtection",
	target = "Interface\\Icons\\Ability_Hunter_SniperShot",
};

local W, H = 800, 600;          -- the window
local NAV_W, LIST_W = 150, 184; -- the tabs, a page's list
local TOP = 112;                -- where a page's list and settings start, below its heading
local BODY_H = H - TOP - 12;
local CX = 124;                 -- where a row's controls start, right of its label

local win;              -- the window, made the first time it opens
local page;             -- the page shown: "general", "common" or a class
local selected;         -- the telegraph whose settings show
local refreshers = {};  -- the header's, the tabs' and the list's
local ui = {};          -- the window's parts

local ShowPage;         -- below; the tabs call it

-- Text in the game's language (Locale.lua); a heading in capitals in English only (string.upper
-- would garble letters past ASCII).
local L = AST_L;
local function Upper(s)
	return AST_Language() == "en" and string.upper(s) or s;
end

local function Refresh()
	for i = 1, table.getn(refreshers) do
		refreshers[i]();
	end
	if ( ui.panel and ui.panel:IsShown() and selected ) then
		for i = 1, table.getn(ui.panel.refreshers) do
			ui.panel.refreshers[i]();
		end
	end
	if ( ui.general and ui.general:IsShown() ) then
		for i = 1, table.getn(ui.general.refreshers) do
			ui.general.refreshers[i]();
		end
	end
	if ( ui.all and ui.all:IsShown() ) then
		for i = 1, table.getn(ui.all.refreshers) do
			ui.all.refreshers[i]();
		end
	end
	if ( ui.hero and ui.hero:IsShown() ) then
		for i = 1, table.getn(ui.hero.refreshers) do
			ui.hero.refreshers[i]();
		end
	end
	if ( ui.target and ui.target:IsShown() ) then
		for i = 1, table.getn(ui.target.refreshers) do
			ui.target.refreshers[i]();
		end
	end
end

-- "priest" -> "Priest"; Title: as the game names the class in its language
local function Cap(word)
	word = tostring(word or "");
	return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2);
end

local function Title(word)
	return L(Cap(word));
end

local function ClassColor(class)
	return CLASS_COLORS[class] or { 1, 0.82, 0 };
end

-- A telegraph's name as the window shows it: your own rings by their number.
local function Named(def)
	if ( def.custom ) then
		return string.format(L("Custom ring %d"), def.custom);
	elseif ( def.of ) then
		-- a skill's ring (Skills.lua): the skill's name in the game's language, in its format
		return string.format(L(def.ofFmt), L(def.of));
	end
	return L(def.name);
end

-- Which list heading a telegraph goes under: an experimental one under its own, last.
local function Kind(def)
	if ( def.experimental ) then
		return "Experimental";
	elseif ( def.kind ) then
		return def.kind;
	elseif ( def.spellKey or def.tipNames ) then
		return "Spells";
	elseif ( def.talentKeys ) then
		return "Talents";
	elseif ( def.match ) then
		return "Amulets";
	end
	return "Other";
end

-- The telegraphs of a page, and whether Priest Telegraphs draws `def` instead.
local function PageDefs(p)
	local r = AST.registry[p];
	return r and r.defs or {};
end

local function Skipped(def)
	local _, _, _, skipped = AST.State();
	if ( def.custom ) then
		-- your own rings are this addon's only (Priest Telegraphs has the first one)
		return false;
	end
	for i = 1, table.getn(skipped) do
		if ( skipped[i] == def.name ) then
			return true;
		end
	end
	return false;
end

-- The telegraph a free one goes with (Free Consecration: Consecration), while that one is off.
local function MainOff(def)
	local _, _, _, _, byId = AST.State();
	local main = def.freeFall and byId and byId[def.freeFall];
	return main and not AST.Settings(main).enabled and main or nil;
end

-- Whether your hero has what a telegraph on this page needs right now (its spell this run, the
-- item or talent it comes of), and if not, why: its dot in the list is green or amber by it.
-- Third: it waits on another telegraph being on, not on your hero.
local function Readiness(def)
	local _, _, myClass = AST.State();
	if ( page ~= "common" and page ~= "lab" and page ~= myClass ) then
		return false, string.format(L("You're playing %s."), myClass and Title(myClass) or L("another class"));
	elseif ( Skipped(def) ) then
		return false, L("Priest Telegraphs draws it while it runs.");
	end
	local main = MainOff(def);
	if ( main ) then
		return false, string.format(L("Shows only while %s is on."), L(main.name)), true;
	end
	local i = AST.info[def.id] or {};
	if ( def.match ) then
		return i.has ~= nil, string.format(L("Your hero needs %s."), L(def.needName or def.name));
	elseif ( def.spellKey ) then
		return i.known == true, L("Not in your spells this run.");
	end
	return true;
end

---------------------------------------------------------------------------------------------
-- Pieces

-- A text. One made with its text (not filled in later) keeps its English, and is put in the
-- game's language again when that changes; `upper`: a heading's capitals.
local function Label(parent, text, font, upper)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall");
	if ( text and text ~= "" ) then
		fs.en, fs.upper = text, upper;
		ui.labels = ui.labels or {};
		table.insert(ui.labels, fs);
		text = upper and Upper(L(text)) or L(text);
	end
	fs:SetText(text);
	return fs;
end

-- The window's fixed texts in the game's language, after it changed.
local function Retranslate()
	for i = 1, table.getn(ui.labels or {}) do
		local fs = ui.labels[i];
		fs:SetText(fs.upper and Upper(L(fs.en)) or L(fs.en));
	end
end

-- A thin line, under headings and between the window's parts.
local function Rule(parent, alpha)
	local t = parent:CreateTexture(nil, "ARTWORK");
	AST.SetPiece(t, SOLID);
	t:SetVertexColor(1, 1, 1, alpha or 0.12);
	t:SetHeight(1);
	return t;
end

local function Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(h);
	b:SetBackdrop(FLAT);
	b:SetBackdropColor(0.12, 0.12, 0.16, 0.95);
	b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1);
	b.text = Label(b, text);
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0);
	-- wide enough for its text in the game's language
	if ( text ~= "" and b.text.GetStringWidth ) then
		b:SetWidth(math.max(w, (b.text:GetStringWidth() or 0) + 16));
	end
	b:SetScript("OnClick", onClick);
	b:SetScript("OnEnter", function() b:SetBackdropBorderColor(1, 0.82, 0, 1); end);
	b:SetScript("OnLeave", function()
		if ( b.active ) then
			b:SetBackdropBorderColor(0.75, 0.55, 1, 1);
		else
			b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1);
		end
	end);
	return b;
end

local function SetActive(b, on)
	b.active = on;
	if ( on ) then
		b:SetBackdropColor(0.3, 0.18, 0.45, 0.95);
		b:SetBackdropBorderColor(0.75, 0.55, 1, 1);
	else
		b:SetBackdropColor(0.12, 0.12, 0.16, 0.95);
		b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1);
	end
end

-- A dark box for a part of the window.
local function Box(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop(FLAT);
	f:SetBackdropColor(0, 0, 0, 0.35);
	f:SetBackdropBorderColor(0.3, 0.3, 0.38, 1);
	return f;
end

-- Asked first, for what can't be undone (a misclick mustn't wipe a setup): `text`, a red button
-- `yes` that does it, and Cancel; the window shaded behind it and taking no clicks meanwhile.
local function Confirm(text, yes, onYes)
	local c = ui.confirm;
	if ( not c ) then
		c = CreateFrame("Frame", "ASTConfirm", win);
		c:SetAllPoints(win);
		c:SetFrameLevel((win:GetFrameLevel() or 1) + 40);
		c:EnableMouse(true);
		c.shade = c:CreateTexture(nil, "BACKGROUND");
		AST.SetPiece(c.shade, SOLID);
		c.shade:SetAllPoints(c);
		c.shade:SetVertexColor(0, 0, 0, 0.65);
		local box = CreateFrame("Frame", nil, c);
		box:SetWidth(400);
		box:SetHeight(150);
		box:SetPoint("CENTER", c, "CENTER", 0, 30);
		box:SetBackdrop(FLAT);
		box:SetBackdropColor(0.07, 0.07, 0.09, 0.98);
		box:SetBackdropBorderColor(1, 0.45, 0.3, 1);
		c.title = Label(box, "Are you sure?", "GameFontNormalLarge");
		c.title:SetPoint("TOP", box, "TOP", 0, -14);
		c.text = Label(box, "");
		c.text:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -44);
		c.text:SetPoint("RIGHT", box, "RIGHT", -20, 0);
		c.text:SetJustifyH("CENTER");
		c.yes = Button(box, "", 170, 24, function()
			c:Hide();
			if ( c.onYes ) then
				c.onYes();
			end
		end);
		c.yes:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 16);
		c.yes:SetBackdropColor(0.5, 0.12, 0.08, 0.95);
		c.no = Button(box, "Cancel", 110, 24, function() c:Hide(); end);
		c.no:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 16);
		ui.confirm = c;
	end
	c.text:SetText(text);
	c.yes.text:SetText(L(yes));
	c.onYes = onYes;
	c:Show();
end

-- Every telegraph back to its defaults, and the General page's settings: your own rings stay (with
-- their settings reset too), as do where the window, the minimap button and the FPS bar sit.
local function ResetEverything()
	local db = AST.State();
	db.t = {};
	db.mirror, db.rotate, db.meterOff, db.hidden = nil, nil, nil, nil;
	if ( db.ui ) then
		db.ui.bulkLeave = nil;
	end
	if ( db.minimapHidden ) then
		AST.ShowMinimapButton(true);
	end
	AST.SetupClass();
	DEFAULT_CHAT_FRAME:AddMessage("|cffb080ffAS Telegraphs|r: " .. L("every telegraph is back to its defaults."));
end

---------------------------------------------------------------------------------------------
-- Rows of settings. A panel keeps its rows (panel.rows), what updates them (panel.refreshers)
-- and the texts that change on their own (panel.live).

-- A row: its label on the left, the caller fills the rest. `when(def)` says whether it shows.
local function Row(panel, label, when, h)
	local row = CreateFrame("Frame", nil, panel);
	row.height = h or 20;
	row:SetHeight(row.height);
	row.label = Label(row, label);
	row.label:SetTextColor(0.8, 0.8, 0.85);
	row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4);
	-- a long one (in another language) stays left of the row's controls
	row.label:SetWidth(CX - 6);
	row.label:SetJustifyH("LEFT");
	row.when, row.tag, row.sub = when, panel.tag, panel.subTag;
	table.insert(panel.rows, row);
	return row;
end

-- A heading over the rows after it, hidden when they all are.
local function Section(panel, title)
	local row = CreateFrame("Frame", nil, panel);
	row.height, row.section, row.tag, row.sub = 26, true, panel.tag, panel.subTag;
	row:SetHeight(row.height);
	local text = Label(row, title, "GameFontNormalSmall", true);
	text:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 6);
	local rule = Rule(row, 0.15);
	rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2);
	rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2);
	table.insert(panel.rows, row);
	return row;
end

-- Places a panel's rows from panel.top down, scrolled by panel.offset (its mouse wheel); a row that
-- would reach past panel.floor (the panel's bottom bar) waits below it. panel.total: the rows'
-- height in all.
local function Layout(panel)
	local rows, shown = panel.rows, {};
	for i = 1, table.getn(rows) do
		shown[i] = rows[i].section or not rows[i].when or rows[i].when(selected);
		if ( selected and selected.shape == "lab" and panel == ui.panel ) then
			shown[i] = false;
		end
		-- a telegraph with rows of its own (the minimap's pins) shows only those, and only it them
		if ( selected and panel == ui.panel and ( selected.ownRows or rows[i].tag ) and rows[i].tag ~= selected.ownRows ) then
			shown[i] = false;
		end
		-- a page on tabs (the Hero bar's): only the rows of the tab shown
		if ( panel.sub and rows[i].sub and rows[i].sub ~= panel.sub ) then
			shown[i] = false;
		end
	end
	for i = 1, table.getn(rows) do
		if ( rows[i].section ) then
			local any, j = false, i + 1;
			while ( rows[j] and not rows[j].section ) do
				any = any or shown[j];
				j = j + 1;
			end
			shown[i] = any;
		end
	end
	local top, floor, off = panel.top, panel.floor or -100000, panel.offset or 0;
	local y = top + off;
	for i = 1, table.getn(rows) do
		local row = rows[i];
		if ( shown[i] ) then
			if ( y <= top + 0.5 and y - row.height >= floor ) then
				row:ClearAllPoints();
				row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y);
				row:SetPoint("RIGHT", panel, "RIGHT", -14, 0);
				row:Show();
			else
				row:Hide();
			end
			y = y - row.height - 2;
		else
			row:Hide();
		end
	end
	panel.total = top + off - y;
	-- more above or below: say so
	if ( panel.more ) then
		local most = math.max(0, panel.total - (top - floor));
		if ( most > 1 ) then
			panel.more:SetText(off < most - 1 and L("Scroll for more") or L("Scroll up for more"));
			panel.more:Show();
		else
			panel.more:Hide();
		end
	end
end

-- A panel of rows that scrolls with the mouse wheel, its rows above `floor`. panel.Scroll(delta):
-- whether it scrolled (it has more than shows), for a row that would take the wheel for itself.
local function Scrolls(panel, floor, moreY)
	panel.floor, panel.offset = floor, 0;
	panel.more = Label(panel, "");
	panel.more:SetTextColor(0.5, 0.5, 0.58);
	panel.more:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, moreY or 6);
	panel.Scroll = function(delta)
		local most = math.max(0, (panel.total or 0) - (panel.top - panel.floor));
		if ( most <= 1 ) then
			return false;
		end
		panel.offset = math.max(0, math.min(most, (panel.offset or 0) - (delta or 0) * 44));
		Layout(panel);
		return true;
	end;
	panel:EnableMouseWheel(true);
	panel:SetScript("OnMouseWheel", function() panel.Scroll(arg1); end);
end

-- `hint`: a line beside the box on what it does.
local function Check(panel, label, when, get, set, hint)
	local row = Row(panel, label, when);
	local b = Button(row, "", 16, 16, function()
		set(not get());
		Refresh();
	end);
	b:SetPoint("LEFT", row, "LEFT", CX, 0);
	if ( hint ) then
		local text = Label(row, hint);
		text:SetTextColor(0.55, 0.55, 0.6);
		text:SetPoint("LEFT", b, "RIGHT", 8, 0);
	end
	local mark = b:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(mark, SOLID);
	mark:SetVertexColor(0.75, 0.55, 1, 1);
	mark:SetWidth(8);
	mark:SetHeight(8);
	mark:SetPoint("CENTER", b, "CENTER", 0, 0);
	table.insert(panel.refreshers, function()
		if ( get() ) then
			mark:Show();
		else
			mark:Hide();
		end
	end);
	return row;
end

-- choices: { value, label, width } each, or a function of the selected telegraph giving them.
local function Choice(panel, label, when, choices, get, set)
	local row = Row(panel, label, when);
	local buttons = {};
	for i = 1, 5 do
		-- Lua 5.0 has one `i` for the whole loop, so each button keeps its own copy
		local index = i;
		buttons[index] = Button(row, "", 60, 18, function()
			set(buttons[index].value);
			Refresh();
		end);
	end
	table.insert(panel.refreshers, function()
		local list = choices;
		if ( type(list) == "function" ) then
			list = list(selected) or {};
		end
		local x = CX;
		for i = 1, 5 do
			local b, ch = buttons[i], list[i];
			if ( ch ) then
				b.value = ch[1];
				b.text:SetText(L(ch[2]));
				local w = math.max(ch[3], b.text.GetStringWidth and (b.text:GetStringWidth() or 0) + 16 or 0);
				b:SetWidth(w);
				b:ClearAllPoints();
				b:SetPoint("LEFT", row, "LEFT", x, 0);
				x = x + w + 4;
				SetActive(b, get() == ch[1]);
				b:Show();
			else
				b:Hide();
			end
		end
	end);
	return row;
end

-- A number with - and + (shift: five steps), the mouse wheel over the row too. `typed`: a click on
-- the number opens a box to type it in, any value from lo to hi (it takes effect as you type; Enter
-- or a click away keeps it, Escape puts the old one back).
local function Stepper(panel, label, when, get, set, step, lo, hi, fmt, typed)
	local row = Row(panel, label, when);
	local value = Label(row, "");
	local box;
	local function Nudge(n)
		if ( box and box.open ) then
			box.Close();
		end
		if ( IsShiftKeyDown and IsShiftKeyDown() ) then
			n = n * 5;
		end
		local v = math.floor((get() + n * step) / step + 0.5) * step;
		set(math.max(lo, math.min(hi, v)));
		Refresh();
	end
	if ( typed ) then
		box = CreateFrame("EditBox", nil, row);
		box:SetAutoFocus(false);
		box:SetMaxLetters(10);
		box:SetFontObject(GameFontHighlightSmall);
		box:SetWidth(100);
		box:SetHeight(18);
		box:SetPoint("LEFT", row, "LEFT", CX + 26, 0);
		box:SetBackdrop(FLAT);
		box:SetBackdropColor(0.05, 0.05, 0.08, 0.95);
		box:SetBackdropBorderColor(0.75, 0.55, 1, 1);
		if ( box.SetTextInsets ) then
			box:SetTextInsets(5, 5, 0, 0);
		end
		box:Hide();
		-- what is typed: its first number ("27.5", "27,5" and "27.5 yd" all are 27.5), or nil
		local function Typed()
			local text = string.gsub(box:GetText() or "", ",", ".");
			local _, _, n = string.find(text, "([0-9]*%.?[0-9]+)");
			n = tonumber(n);
			return n and math.max(lo, math.min(hi, math.floor(n * 100 + 0.5) / 100));
		end
		-- closes the box; `put` puts that value back (Escape). Only while the telegraph it was opened
		-- for is still the one selected: a click on another doesn't give that one this number.
		-- `quiet`: the window is closing, nothing to redraw.
		box.Close = function(put, quiet)
			if ( not box.open ) then
				return;
			end
			box.open = false;
			if ( put and selected == box.owner ) then
				set(put);
			end
			box:ClearFocus();
			box:Hide();
			value:Show();
			if ( not quiet ) then
				Refresh();
			end
		end
		box:SetScript("OnTextChanged", function()
			local n = box.open and selected == box.owner and Typed();
			if ( n ) then
				set(n);
				Refresh();
			end
		end);
		box:SetScript("OnEnterPressed", function() box.Close(); end);
		box:SetScript("OnEditFocusLost", function() box.Close(); end);
		box:SetScript("OnEscapePressed", function() box.Close(box.before); end);
		-- the window (or this row) closing keeps what was typed
		row:SetScript("OnHide", function() box.Close(nil, true); end);
		-- the number itself is the button that opens it
		local hit = CreateFrame("Button", nil, row);
		hit:SetWidth(104);
		hit:SetHeight(18);
		hit:SetPoint("LEFT", row, "LEFT", CX + 24, 0);
		hit:SetScript("OnEnter", function()
			value:SetTextColor(0.85, 0.7, 1);
			GameTooltip:SetOwner(hit, "ANCHOR_RIGHT");
			GameTooltip:SetText(L("Click to type a number"), 1, 1, 1);
			GameTooltip:Show();
		end);
		hit:SetScript("OnLeave", function()
			value:SetTextColor(1, 1, 1);
			GameTooltip:Hide();
		end);
		hit:SetScript("OnClick", function()
			box.owner, box.before = selected, get();
			-- the box opens holding the number alone, ready to be typed over
			box:SetText(string.format("%g", box.before));
			box.open = true;
			value:Hide();
			box:Show();
			box:SetFocus();
			box:HighlightText();
		end);
		-- another telegraph picked: it closes (this runs in a Refresh already, before the number's own)
		table.insert(panel.refreshers, function()
			if ( box.open and selected ~= box.owner ) then
				box.Close(nil, true);
			end
		end);
	end
	local minus = Button(row, "-", 20, 18, function() Nudge(-1); end);
	minus:SetPoint("LEFT", row, "LEFT", CX, 0);
	value:SetPoint("LEFT", row, "LEFT", CX + 24, 0);
	value:SetWidth(104);
	local plus = Button(row, "+", 20, 18, function() Nudge(1); end);
	plus:SetPoint("LEFT", row, "LEFT", CX + 132, 0);
	row:EnableMouseWheel(true);
	row:SetScript("OnMouseWheel", function()
		-- a panel with more than shows scrolls; else the wheel steps the number
		if ( panel.Scroll and panel.Scroll(arg1) ) then
			return;
		end
		if ( arg1 and arg1 > 0 ) then
			Nudge(1);
		else
			Nudge(-1);
		end
	end);
	table.insert(panel.refreshers, function()
		value:SetText(fmt(get()));
	end);
	return row;
end

-- A colour: its swatch, the presets, and the colour picker if the client has one. `key` is the
-- setting ("line" or "fill") of the selected telegraph.
-- `tbl`: where the colour is kept (a function giving the table; the selected telegraph's settings
-- when left out).
local function Color(panel, label, when, key, tbl)
	local row = Row(panel, label, when);
	local swatch = row:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(swatch, SOLID);
	swatch:SetWidth(18);
	swatch:SetHeight(18);
	swatch:SetPoint("LEFT", row, "LEFT", CX, 0);
	local function SetRGB(r, g, b)
		local s = tbl and tbl() or AST.Settings(selected);
		local c = s[key];
		c[1], c[2], c[3] = r, g, b;
		if ( not tbl ) then
			s.hand = s.hand or {};
			s.hand[key] = true;
		end
		Refresh();
	end
	local x = CX + 26;
	for i = 1, table.getn(PRESETS) do
		local pc = PRESETS[i];
		local b = CreateFrame("Button", nil, row);
		b:SetWidth(14);
		b:SetHeight(14);
		b:SetPoint("LEFT", row, "LEFT", x, 0);
		local t = b:CreateTexture(nil, "OVERLAY");
		AST.SetPiece(t, SOLID);
		t:SetVertexColor(pc[1], pc[2], pc[3], 1);
		t:SetAllPoints(b);
		b:SetScript("OnClick", function() SetRGB(pc[1], pc[2], pc[3]); end);
		x = x + 17;
	end
	if ( ColorPickerFrame ) then
		local pick = Button(row, "Pick", 40, 18, function()
			local c = (tbl and tbl() or AST.Settings(selected))[key];
			local before = { r = c[1], g = c[2], b = c[3] };
			ColorPickerFrame.hasOpacity = nil;
			ColorPickerFrame.previousValues = before;
			ColorPickerFrame.func = function()
				SetRGB(ColorPickerFrame:GetColorRGB());
			end;
			ColorPickerFrame.cancelFunc = function()
				SetRGB(before.r, before.g, before.b);
			end;
			ColorPickerFrame:SetColorRGB(c[1], c[2], c[3]);
			if ( ShowUIPanel ) then
				ShowUIPanel(ColorPickerFrame);
			else
				ColorPickerFrame:Show();
			end
		end);
		pick:SetPoint("LEFT", row, "LEFT", x + 4, 0);
	end
	table.insert(panel.refreshers, function()
		local c = (tbl and tbl() or AST.Settings(selected))[key];
		swatch:SetVertexColor(c[1], c[2], c[3], 1);
	end);
	return row;
end

-- A text that keeps itself up to date (`get` four times a second), `h` tall for more lines.
local function Text(panel, label, when, get, h)
	local row = Row(panel, label, when, h);
	local text = Label(row, "");
	text:SetPoint("TOPLEFT", row, "TOPLEFT", CX, -4);
	text:SetPoint("RIGHT", row, "RIGHT", 0, 0);
	text:SetJustifyH("LEFT");
	text:SetJustifyV("TOP");
	if ( h ) then
		text:SetHeight(h - 4);
	end
	table.insert(panel.live, function() text:SetText(L(get())); end);
	return row;
end

---------------------------------------------------------------------------------------------
-- The tabs down the left side

local function Tab(id, icon, text)
	local b = CreateFrame("Button", nil, ui.nav);
	b:SetWidth(NAV_W - 12);
	b:SetHeight(28);
	b:SetBackdrop(FLAT);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetTexture(icon);
	b.icon:SetWidth(20);
	b.icon:SetHeight(20);
	b.icon:SetPoint("LEFT", b, "LEFT", 7, 0);
	b.text = Label(b, text, "GameFontHighlight");
	b.text:SetPoint("LEFT", b, "LEFT", 33, 0);
	b.tag = Label(b, "");
	b.tag:SetTextColor(0.55, 0.55, 0.6);
	b.tag:SetPoint("RIGHT", b, "RIGHT", -8, 0);
	-- the chosen tab's mark, joining it to its page
	b.bar = b:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(b.bar, SOLID);
	b.bar:SetVertexColor(0.75, 0.55, 1, 1);
	b.bar:SetWidth(3);
	b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -3);
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 3);
	b.page = id;
	b:SetScript("OnClick", function() ShowPage(id); end);
	b:SetScript("OnEnter", function()
		if ( page ~= id ) then
			b:SetBackdropColor(1, 1, 1, 0.08);
		end
	end);
	b:SetScript("OnLeave", function()
		if ( page ~= id ) then
			b:SetBackdropColor(0, 0, 0, 0);
		end
	end);
	table.insert(ui.tabs, b);
	return b;
end

-- Your class first, then the others by name.
local function ClassOrder()
	local _, _, myClass = AST.State();
	local list = {};
	for class in pairs(AST.registry) do
		if ( class ~= "common" and class ~= "lab" and class ~= myClass ) then
			table.insert(list, class);
		end
	end
	table.sort(list);
	if ( myClass and AST.registry[myClass] ) then
		table.insert(list, 1, myClass);
	end
	return list;
end

local function BuildNav()
	ui.nav = Box(win);
	ui.nav:SetWidth(NAV_W);
	ui.nav:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -52);
	ui.nav:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, 10);
	ui.tabs = {};
	Tab("general", ICONS.general, "General");
	Tab("all", ICONS.addon, "All telegraphs");
	Tab("bars", ICONS.hero, "Bars");
	Tab("common", ICONS.common, "Any class");
	Tab("lab", "Interface\\Icons\\INV_Misc_Spyglass_02", "Lab");
	ui.classHead = Label(ui.nav, "Classes", "GameFontNormalSmall", true);
	for class, r in pairs(AST.registry) do
		if ( class ~= "common" and class ~= "lab" ) then
			local b = Tab(class, r.icon or ICONS.class, Cap(class));
			local c = ClassColor(class);
			b.text:SetTextColor(c[1], c[2], c[3]);
		end
	end
	local version = GetAddOnMetadata and GetAddOnMetadata("AzerothSurvivorsTelegraphs", "Version");
	local v = Label(ui.nav, "");
	v:SetTextColor(0.45, 0.45, 0.5);
	v:SetPoint("BOTTOM", ui.nav, "BOTTOM", 0, 8);
	-- the tabs in order, the chosen one marked; your class tagged "you"
	table.insert(refreshers, function()
		local _, _, myClass = AST.State();
		local byPage = {};
		for i = 1, table.getn(ui.tabs) do
			local b = ui.tabs[i];
			byPage[b.page] = b;
			if ( b.page == page ) then
				b:SetBackdropColor(0.75, 0.55, 1, 0.18);
				b:SetBackdropBorderColor(0.75, 0.55, 1, 0.6);
				b.bar:Show();
			else
				b:SetBackdropColor(0, 0, 0, 0);
				b:SetBackdropBorderColor(0, 0, 0, 0);
				b.bar:Hide();
			end
			b.tag:SetText(b.page == myClass and L("you") or "");
		end
		v:SetText(version and string.format(L("Version %s"), version) or "");
		-- General, the classes under their heading, then Any class
		local y = -6;
		byPage.general:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y);
		byPage.all:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y - 30);
		byPage.bars:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y - 60);
		ui.classHead:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 12, y - 100);
		y = y - 116;
		local classes = ClassOrder();
		for i = 1, table.getn(classes) do
			local b = byPage[classes[i]];
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y);
			y = y - 30;
		end
		byPage.common:ClearAllPoints();
		byPage.common:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y - 10);
		-- the Lab, apart from the rest: hidden unless /ast lab tab shows it (its experiments are
		-- for trying out, not for everyone)
		if ( byPage.lab ) then
			local db = AST.State();
			if ( db.labTab ) then
				byPage.lab:ClearAllPoints();
				byPage.lab:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y - 56);
				byPage.lab.text:SetTextColor(0.75, 0.55, 1);
				byPage.lab:Show();
			else
				byPage.lab:Hide();
				if ( page == "lab" ) then
					ShowPage("general");
				end
			end
		end
	end);
end

---------------------------------------------------------------------------------------------
-- A telegraph page: its heading, its list, the chosen telegraph's settings

local function Select(def)
	local db = AST.State();
	if ( selected ~= def ) then
		ui.panel.offset = 0;
	end
	selected = def;
	db.ui.sel[page] = def and def.id;
	if ( def ) then
		Layout(ui.panel);
	end
	Refresh();
end

local function Heading()
	local h = CreateFrame("Frame", nil, ui.list);
	h.height = 18;
	h:SetHeight(h.height);
	h:SetWidth(LIST_W - 16);
	h.text = Label(h, "", "GameFontNormalSmall");
	h.text:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 4, 3);
	return h;
end

-- A telegraph in the list: its colour, its name, and a dot to turn it on or off (red off; green
-- on, and your hero has it now; amber on, waiting for your hero to have it).
local function Entry()
	local e = CreateFrame("Button", nil, ui.list);
	e.height = 22;
	e:SetHeight(20);
	e:SetWidth(LIST_W - 16);
	e:SetBackdrop(FLAT);
	e.chip = e:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(e.chip, SOLID);
	e.chip:SetWidth(3);
	e.chip:SetHeight(12);
	e.chip:SetPoint("LEFT", e, "LEFT", 5, 0);
	e.text = Label(e, "");
	e.text:SetPoint("LEFT", e, "LEFT", 14, 0);
	e.text:SetWidth(LIST_W - 56);
	e.text:SetJustifyH("LEFT");
	-- a row left over from a longer page has no telegraph (and is hidden)
	e:SetScript("OnClick", function() if ( e.def ) then Select(e.def); end end);
	e:SetScript("OnEnter", function() e:SetBackdropBorderColor(1, 0.82, 0, 1); end);
	e:SetScript("OnLeave", function() SetActive(e, e.def == selected); end);
	e.dot = CreateFrame("Button", nil, e);
	e.dot:SetWidth(16);
	e.dot:SetHeight(16);
	e.dot:SetPoint("RIGHT", e, "RIGHT", -4, 0);
	e.dot.mark = e.dot:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(e.dot.mark, AST.round);
	e.dot.mark:SetWidth(9);
	e.dot.mark:SetHeight(9);
	e.dot.mark:SetPoint("CENTER", e.dot, "CENTER", 0, 0);
	e.dot:SetScript("OnClick", function()
		if ( not e.def ) then
			return;
		end
		local s = AST.Settings(e.def);
		s.enabled = not s.enabled;
		s.hand = s.hand or {};
		s.hand.enabled = true;
		Refresh();
	end);
	e.dot:SetScript("OnEnter", function()
		if ( not e.def ) then
			return;
		end
		GameTooltip:SetOwner(e.dot, "ANCHOR_RIGHT");
		local ready, why, onOther = Readiness(e.def);
		if ( not AST.Settings(e.def).enabled ) then
			GameTooltip:SetText(L("Off"), 1, 0.35, 0.35);
			GameTooltip:AddLine(L("Click to turn it on."), 0.8, 0.8, 0.8);
		elseif ( ready ) then
			GameTooltip:SetText(L("On, and your hero has it"), 0.4, 1, 0.5);
			GameTooltip:AddLine(L("Click to turn it off."), 0.8, 0.8, 0.8);
		else
			GameTooltip:SetText(L("On, waiting"), 1, 0.72, 0.2);
			GameTooltip:AddLine(why, 1, 1, 1);
			GameTooltip:AddLine(onOther and L("Click to turn it off.")
				or L("It shows once your hero has it. Click to turn it off."), 0.8, 0.8, 0.8);
		end
		GameTooltip:Show();
	end);
	e.dot:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return e;
end

-- The list's rows from the top, scrolled by ui.offset; those outside it hidden.
local function LayoutList()
	local y = -6 + ui.offset;
	local total = 0;
	for i = 1, table.getn(ui.items) do
		total = total + ui.items[i].height;
	end
	ui.listH = total;
	-- a list longer than shows: a line under it says so, with room made for it
	local room = BODY_H - 34;
	if ( total + 6 > room ) then
		room = room - 14;
	end
	ui.listRoom = room;
	for i = 1, table.getn(ui.items) do
		local item = ui.items[i];
		if ( y <= -5 and y - item.height >= -room ) then
			item:ClearAllPoints();
			item:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 8, y);
			item:Show();
		else
			item:Hide();
		end
		y = y - item.height;
	end
	if ( ui.listMore ) then
		local most = total + 6 - room;
		if ( most > 1 ) then
			ui.listMore:SetText(ui.offset < most - 1 and L("Scroll for more") or L("Scroll up for more"));
			ui.listMore:Show();
		else
			ui.listMore:Hide();
		end
	end
end

-- Fills the list with the page's telegraphs, under their kinds' headings.
local function Populate()
	local defs = PageDefs(page);
	local nE, nH = 0, 0;
	ui.items = {};
	for k = 1, table.getn(KINDS) do
		local first = true;
		for i = 1, table.getn(defs) do
			if ( Kind(defs[i]) == KINDS[k] and not defs[i].hidden ) then
				if ( first ) then
					nH = nH + 1;
					ui.heads[nH] = ui.heads[nH] or Heading();
					ui.heads[nH].text:SetText(Upper(L(KINDS[k])));
					table.insert(ui.items, ui.heads[nH]);
					first = false;
				end
				nE = nE + 1;
				ui.entries[nE] = ui.entries[nE] or Entry();
				ui.entries[nE].def = defs[i];
				ui.entries[nE].text:SetText(Named(defs[i]));
				table.insert(ui.items, ui.entries[nE]);
			end
		end
	end
	for i = nE + 1, table.getn(ui.entries) do
		ui.entries[i].def = nil;
		ui.entries[i]:Hide();
	end
	for i = nH + 1, table.getn(ui.heads) do
		ui.heads[i]:Hide();
	end
	ui.offset = 0;
	LayoutList();
end

local function BuildList()
	ui.list = Box(win);
	ui.list:SetWidth(LIST_W);
	ui.list:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -TOP);
	ui.list:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", NAV_W + 18, 10);
	ui.entries, ui.heads, ui.items, ui.offset = {}, {}, {}, 0;
	-- a ring of your own on this page, as many as you like
	ui.addRing = Button(ui.list, "Add a ring", LIST_W - 16, 22, function()
		local def = AST.AddRing(page);
		if ( def ) then
			AST.State().ui.sel[page] = def.id;
			ShowPage(page);
		end
	end);
	ui.addRing:SetPoint("BOTTOM", ui.list, "BOTTOM", 0, 8);
	ui.listMore = Label(ui.list, "");
	ui.listMore:SetTextColor(0.5, 0.5, 0.58);
	ui.listMore:SetPoint("BOTTOMRIGHT", ui.list, "BOTTOMRIGHT", -10, 33);
	-- a long list scrolls with the mouse wheel
	ui.list:EnableMouseWheel(true);
	ui.list:SetScript("OnMouseWheel", function()
		local most = math.max(0, (ui.listH or 0) + 6 - (ui.listRoom or (BODY_H - 34)));
		ui.offset = math.max(0, math.min(most, ui.offset - (arg1 or 0) * 22));
		LayoutList();
	end);
	-- (repainted four times a second too, as what your hero has changes)
	ui.paint = function()
		for i = 1, table.getn(ui.entries) do
			local e = ui.entries[i];
			if ( e.def ) then
				local s = AST.Settings(e.def);
				SetActive(e, e.def == selected);
				e.chip:SetVertexColor(s.line[1], s.line[2], s.line[3], 1);
				if ( Skipped(e.def) ) then
					e.text:SetTextColor(0.45, 0.45, 0.5);
				elseif ( s.enabled ) then
					e.text:SetTextColor(1, 1, 1);
				else
					e.text:SetTextColor(0.55, 0.55, 0.6);
				end
				if ( not s.enabled ) then
					e.dot.mark:SetVertexColor(0.9, 0.25, 0.25, 1);
				elseif ( Readiness(e.def) ) then
					e.dot.mark:SetVertexColor(0.4, 1, 0.5, 1);
				else
					e.dot.mark:SetVertexColor(1, 0.72, 0.2, 1);
				end
			end
		end
	end;
	table.insert(refreshers, ui.paint);
end

-- The selected telegraph's size, and where it comes from, for the lines under its name.
local function StatusLines()
	local d = selected;
	local _, _, myClass = AST.State();
	if ( d.shape == "lab" ) then
		-- a Lab experiment: what it changes, and an error that stopped it
		local err = AST.lab and AST.lab.errors[d.id];
		return d.applies or "", err and ("Stopped: " .. err) or "Test plays a demo of it around you.", err ~= nil;
	end
	if ( page ~= "common" and page ~= myClass ) then
		return string.format(L("Shown when you play %s. You're playing %s."), Title(page), myClass and Title(myClass) or L("another class")), "", true;
	elseif ( Skipped(d) ) then
		return L("Priest Telegraphs draws this one while it runs."), L("Turn one of the two addons off at the AddOns screen."), true;
	end
	local i = AST.info[d.id] or {};
	-- where its size comes from: "Holy Nova's size" is another telegraph's
	local from = tostring(i.source);
	local _, _, other = string.find(from, "^(.+)'s size$");
	from = other and string.format(L("%s's size"), L(other)) or L(from);
	local size = L("Size: not measured yet");
	if ( i.size and d.shape == "cone" ) then
		size = string.format(L("Size: %.1f yd long, %d degrees wide (%s)"), i.size, 2 * d.halfAngle, from);
	elseif ( i.size ) then
		size = string.format(L("Size: %.1f yd radius (%s)"), i.size, from);
	end
	local source = "";
	local main = MainOff(d);
	if ( main ) then
		source = string.format(L("Shows only while %s is on."), L(main.name));
	elseif ( d.spellKey and not d.match ) then
		if ( i.known ) then
			source = string.format(L("In your spells: cooldown %.1f of %.1f sec"), i.left or 0, i.max or 0);
		else
			source = L("Not in your spells this run");
		end
	elseif ( d.match ) then
		if ( i.has and i.how == "seen" ) then
			source = L("Your hero has it: seen going off this run");
		elseif ( i.has ) then
			source = string.format(L("Your hero has it (%s)"), L(tostring(i.how)));
		else
			source = string.format(L("Not on your hero: needs %s"), L(d.needName or d.name));
		end
		if ( i.has and d.buffSpells ) then
			source = source .. (AST.shield.up and L(", shield up") or L(", no shield now"));
		elseif ( i.has and d.shape == "enemy" ) then
			source = source .. string.format(L(", went off %d times"), AST.fired[d.id] or 0);
		elseif ( i.has and d.clock ) then
			source = source .. (i.clockLeft and string.format(L(", next in %d sec"), math.ceil(i.clockLeft))
				or L(", timed from the first one it sees"));
		end
	elseif ( d.shape == "downed" ) then
		source = string.format(L("%d teammates down near you"), i.count or 0);
	end
	return size, source;
end

-- What a telegraph is, when its class file doesn't say; an experimental one says so.
local function Describe(d)
	if ( d.experimental ) then
		return L("Experimental, off to start with: the spot it marks can be off.") .. " " .. L(d.desc or "");
	elseif ( d.descFmt ) then
		return string.format(L(d.descFmt), L(d.of));
	elseif ( d.desc ) then
		return L(d.desc);
	elseif ( d.shape == "cone" ) then
		return L("A cone in front of you.");
	elseif ( d.shape == "enemy" ) then
		return L("Where it goes off on enemies.");
	elseif ( d.shape == "downed" ) then
		return L("Around downed teammates.");
	end
	return L("A ring around you.");
end

local function ModeChoices(d)
	local out = {};
	for i = 1, table.getn(d.modes or {}) do
		local m = AST.modes[d.modes[i]];
		if ( m ) then
			table.insert(out, { d.modes[i], m[1], m[2] });
		end
	end
	return out;
end

local function Pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end
-- A telegraph that can show more than one at a time (its "Most at once"): enemy effects, a ground
-- spell's spots, teammates down, a guardian's rings.
local function Many(d)
	return d.shape == "enemy" or d.shape == "ground" or d.shape == "downed" or d.shape == "world";
end
local function Px(v) return string.format(L("%g px"), v); end
local function Yd(v) return string.format(L("%g yd"), v); end

---------------------------------------------------------------------------------------------
-- Changes to many telegraphs at once (the All telegraphs page, "Copy look to"). Each is written
-- into every telegraph it reaches, so afterwards any one of them can be set differently on its own
-- page; and a setting changed on a telegraph's own page (marked set by hand) is left alone while
-- the All page says to keep those.

-- What a telegraph's look is: copied from one to others by "Copy look to".
local LOOK = { "style", "line", "fill", "width", "glow", "strip", "size", "spacing", "fillStyle", "fillSpacing",
	"lineOn", "fillOn", "areaOn", "frontOn", "pulseOn" };

-- The telegraphs a change reaches: your class's and Any class' ("mine"), every class's ("all"),
-- your own rings ("rings"), or one page's (its name). Never the Lab's.
local function Reach(scope)
	local _, _, myClass = AST.State();
	local out = {};
	for p, r in pairs(AST.registry) do
		local take = p ~= "lab";
		if ( scope == "mine" ) then
			take = take and ( p == myClass or p == "common" );
		elseif ( scope ~= "all" and scope ~= "rings" ) then
			take = p == scope;
		end
		for i = 1, ( take and table.getn(r.defs) or 0 ) do
			local d = r.defs[i];
			if ( not d.hidden and ( scope ~= "rings" or d.custom or d.id == "ring" ) ) then
				table.insert(out, d);
			end
		end
	end
	return out;
end

-- Whether a setting of a telegraph was set by hand and is to be kept.
local function Kept(s, key)
	return AST.State().ui.bulkLeave ~= false and s.hand ~= nil and s.hand[key] == true;
end

-- Puts fn(def, settings) to every telegraph in `defs` (fn returns false where it doesn't apply),
-- leaving those whose `key` was set by hand; says what it did.
local function Bulk(defs, key, fn)
	local n, kept = 0, 0;
	for i = 1, table.getn(defs) do
		local s = AST.Settings(defs[i]);
		if ( Kept(s, key) ) then
			kept = kept + 1;
		elseif ( fn(defs[i], s) ~= false ) then
			n = n + 1;
		end
	end
	ui.said = string.format(L("Changed %d telegraphs."), n)
		.. ( kept > 0 and ( " " .. string.format(L("Kept %d you set by hand."), kept) ) or "" );
	ui.saidAt = GetTime();
	Refresh();
end

-- A row of buttons that act (rather than show a setting): { text, onClick } each.
local function Actions(panel, label, when, list)
	local row = Row(panel, label, when);
	local x = CX;
	for i = 1, table.getn(list) do
		local act = list[i];
		-- wide enough for its text even where the text can't be measured (about 6.5 units a letter)
		local w = math.max(40, string.len(L(act[1])) * 6.5 + 18);
		local b = Button(row, act[1], w, 18, act[2]);
		b:SetPoint("LEFT", row, "LEFT", x, 0);
		x = x + math.max(w, b:GetWidth() or 0) + 4;
	end
	return row;
end

-- The selected telegraph's look onto every telegraph on this page ("page") or every class ("all"),
-- key by key: one set by hand there is kept (while the All page says so).
local function CopyLook(scope)
	local from = AST.Settings(selected);
	local defs = Reach(scope == "page" and page or "all");
	local n = 0;
	for i = 1, table.getn(defs) do
		if ( defs[i] ~= selected ) then
			local s = AST.Settings(defs[i]);
			for k = 1, table.getn(LOOK) do
				local key = LOOK[k];
				local v = from[key];
				if ( type(v) == "table" ) then
					-- a colour: its hue and its opacity are kept apart
					local c = s[key];
					if ( not Kept(s, key) ) then
						c[1], c[2], c[3] = v[1], v[2], v[3];
					end
					if ( not Kept(s, key .. "A") ) then
						c[4] = v[4];
					end
				elseif ( not Kept(s, key) ) then
					s[key] = v;
				end
			end
			n = n + 1;
		end
	end
	ui.said = string.format(L("Copied this look to %d telegraphs."), n);
	ui.saidAt = GetTime();
	Refresh();
end

-- The settings rows, the ones that don't fit what the telegraph is or how it is drawn hidden. A
-- setting changed here is marked as set by hand (s.hand[key]): the All telegraphs page leaves it.
-- A choice from a list too long for a row of buttons: < and > step through it, and the name
-- between them opens the whole list. list(): { { value, text }, ... }; get(): the value now.
local pickMenu;
local function Pick(panel, label, when, list, get, set)
	local row = Row(panel, label, when);
	local function Step(by)
		local l, at = list(), 1;
		for i = 1, table.getn(l) do
			if ( l[i][1] == get() ) then
				at = i;
			end
		end
		if ( l[1] ) then
			at = at + by;
			if ( at < 1 ) then
				at = table.getn(l);
			elseif ( at > table.getn(l) ) then
				at = 1;
			end
			set(l[at][1]);
			Refresh();
		end
	end
	local prev = Button(row, "<", 20, 18, function() Step(-1); end);
	prev:SetPoint("LEFT", row, "LEFT", CX, 0);
	local name;
	name = Button(row, "", 220, 18, function()
		local m = pickMenu;
		if ( not m ) then
			m = CreateFrame("Frame", "ASTPickMenu", win);
			m:SetBackdrop(FLAT);
			m:SetBackdropColor(0.08, 0.08, 0.11, 0.98);
			m:SetBackdropBorderColor(0.75, 0.55, 1, 1);
			m:SetFrameLevel((win:GetFrameLevel() or 0) + 30);
			m:EnableMouse(true);
			m.buttons = {};
			pickMenu = m;
		end
		if ( m:IsShown() and m.owner == row ) then
			m:Hide();
			return;
		end
		m.owner = row;
		local l = list();
		local per = 14;
		local cols = math.max(1, math.ceil(table.getn(l) / per));
		local rows = math.min(per, table.getn(l));
		for i = 1, math.max(table.getn(l), table.getn(m.buttons)) do
			local entry = l[i];
			local b = m.buttons[i];
			if ( entry and not b ) then
				b = Button(m, "", 200, 18, function() end);
				m.buttons[i] = b;
			end
			if ( entry ) then
				local value = entry[1];
				b.text:SetText(entry[2]);
				b:SetScript("OnClick", function()
					set(value);
					m:Hide();
					Refresh();
				end);
				local col, at = math.floor((i - 1) / per), i - 1 - per * math.floor((i - 1) / per);
				b:ClearAllPoints();
				b:SetPoint("TOPLEFT", m, "TOPLEFT", 8 + col * 204, -8 - at * 20);
				SetActive(b, value == get());
				b:Show();
			elseif ( b ) then
				b:Hide();
			end
		end
		m:SetWidth(16 + cols * 204 - 4);
		m:SetHeight(16 + rows * 20 - 2);
		m:ClearAllPoints();
		-- below the name, or above it where below would leave the window
		local bottom, winBottom = name:GetBottom(), win:GetBottom();
		if ( bottom and winBottom and bottom - (16 + rows * 20) < winBottom ) then
			m:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 0, 2);
		else
			m:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2);
		end
		m:Show();
	end);
	name:SetPoint("LEFT", prev, "RIGHT", 4, 0);
	name.text:SetWidth(212);
	local nxt = Button(row, ">", 20, 18, function() Step(1); end);
	nxt:SetPoint("LEFT", name, "RIGHT", 4, 0);
	table.insert(panel.refreshers, function()
		local l, text = list(), nil;
		for i = 1, table.getn(l) do
			if ( l[i][1] == get() ) then
				text = l[i][2];
			end
		end
		name.text:SetText(text or ( l[1] and l[1][2] ) or L("None"));
	end);
	row:SetScript("OnHide", function()
		if ( pickMenu and pickMenu.owner == row ) then
			pickMenu:Hide();
		end
	end);
	return row;
end

-- The minimap's range ring (Guardians.lua): its rows alone. Its settings are its telegraph's own,
-- with defaults of their own (AST.guard.MR()).
local function RangeRows(panel)
	local G = AST.guard;
	local function MR() return G.MR(); end
	local function Get(key) return function() return MR()[key]; end; end
	local function Put(key) return function(v) MR()[key] = v; end; end
	local function Ring(d) return d.ownRows == "mmrange"; end
	local function Warns(d) return Ring(d) and MR().mmNear > 0; end
	local function Dotted(d) return Ring(d) and MR().mmStyle == "dotted"; end
	local function Filled(d) return Ring(d) and MR().mmFill; end
	local function Lairs(d) return Ring(d) and MR().mmEmpty; end
	local function Half(v) return math.floor(v * 2 + 0.5) / 2; end
	-- a class's skills, each with its range (yours now; another class's before its Area), after
	-- "Longest" (the longest of the skills you have, as it changes)
	local function Skills(class)
		local _, _, myClass = AST.State();
		local out, list = {}, G.Skills(class);
		local far = ( class == myClass ) and G.Longest(class);
		table.insert(out, { "longest", far and string.format(L("Longest (%s)"), Yd(Half(far))) or L("Longest") });
		for i = 1, table.getn(list) do
			local d = list[i];
			local yd = ( class == myClass ) and AST.RangeOf(d) or G.BaseOf(d);
			local text = Named(d);
			if ( type(yd) == "number" and yd > 0 ) then
				text = text .. " (" .. Yd(Half(yd)) .. ")";
			end
			table.insert(out, { d.id, text });
		end
		return out;
	end
	panel.tag = "mmrange";
	Section(panel, "Range");
	Text(panel, "Now", Ring, function()
		local R, def = G.RangeNow();
		if ( MR().mmOverride > 0 ) then
			return string.format(L("Your own range: %s"), Yd(R));
		end
		local _, _, myClass = AST.State();
		local longest = myClass and MR().mmSkills[myClass] == "longest";
		if ( longest and not def ) then
			return L("Longest: none of your skills yet");
		elseif ( not def ) then
			return L("Your class has no range to show");
		elseif ( not R ) then
			return string.format(L("%s: not known yet"), Named(def));
		end
		return ( longest and ( L("Longest") .. ": " ) or "" ) .. Named(def) .. ": " .. Yd(Half(R));
	end);
	Stepper(panel, "Your own range", Ring, Get("mmOverride"), Put("mmOverride"), 1, 0, 100, function(v)
		return v > 0 and Yd(v) or L("Off: the skill's");
	end, true);
	Section(panel, "Skill for each class");
	for i = 1, table.getn(G.CLASSES) do
		local class = G.CLASSES[i];
		Pick(panel, Title(class), Ring, function() return Skills(class); end,
			function()
				if ( MR().mmSkills[class] == "longest" ) then
					return "longest";
				end
				local d = G.SkillOf(class);
				return d and d.id;
			end,
			function(v) MR().mmSkills[class] = v; end);
	end
	Section(panel, "Lights up for");
	Check(panel, "Empty lairs", Ring, Get("mmEmpty"), Put("mmEmpty"), "Where a guardian will appear");
	Stepper(panel, "Filling within", Lairs, Get("mmSoon"), Put("mmSoon"), 5, 0, 180, function(v)
		return v > 0 and string.format(L("%d sec"), v) or L("Any time");
	end);
	Check(panel, "Sleeping guardians", Ring, Get("mmAsleep"), Put("mmAsleep"), "Up and waiting at their lair");
	Check(panel, "Guardians chasing you", Ring, Get("mmAwake"), Put("mmAwake"));
	Check(panel, "Bosses", Ring, Get("mmBosses"), Put("mmBosses"));
	Stepper(panel, "Early warning", Ring, Get("mmNear"), Put("mmNear"), 1, 0, 50, function(v)
		return v > 0 and string.format(L("%g yd before"), v) or L("Off");
	end);
	Color(panel, "Warning colour", Warns, "mmNearC", MR);
	Check(panel, "Only near a lair", Ring, Get("mmOnlyNear"), Put("mmOnlyNear"),
		string.format(L("Hidden until one is within %d yd of the ring"), G.NEAR));
	Section(panel, "Look");
	Choice(panel, "Line", Ring, { { "solid", "Solid", 50 }, { "dotted", "Dotted", 50 } }, Get("mmStyle"), Put("mmStyle"));
	Stepper(panel, "Width", Ring, Get("mmWidth"), Put("mmWidth"), 0.5, 1, 6, Px);
	Stepper(panel, "Dot spacing", Dotted, Get("mmGap"), Put("mmGap"), 1, 3, 20, Px);
	Color(panel, "Colour", Ring, "mmLine", MR);
	Stepper(panel, "Opacity", Ring, function() return MR().mmLine[4]; end, function(v) MR().mmLine[4] = v; end,
		0.05, 0.1, 1, Pct);
	Color(panel, "In range", Ring, "mmHot", MR);
	Stepper(panel, "In range opacity", Ring, function() return MR().mmHot[4]; end, function(v) MR().mmHot[4] = v; end,
		0.05, 0.1, 1, Pct);
	Check(panel, "Pulse in range", Ring, Get("mmPulse"), Put("mmPulse"));
	Check(panel, "Thicker in range", Ring, Get("mmGrow"), Put("mmGrow"));
	Check(panel, "Mark what's in range", Ring, Get("mmMark"), Put("mmMark"), "A ring round its pin");
	Check(panel, "Fill", Ring, Get("mmFill"), Put("mmFill"), "A faint disc inside the ring");
	Stepper(panel, "Fill opacity", Filled, Get("mmFillA"), Put("mmFillA"), 0.05, 0.05, 0.6, Pct);
	Check(panel, "Show the range", Ring, Get("mmText"), Put("mmText"), "Its yards over the ring");
	panel.tag = nil;
end

local function SettingRows(panel)
	local function S() return AST.Settings(selected); end
	local function Mark(key)
		local s = S();
		s.hand = s.hand or {};
		s.hand[key] = true;
	end
	local function Get(key) return function() return S()[key]; end; end
	local function Put(key) return function(v) S()[key] = v; Mark(key); end; end
	local function Dotty() return S().style == "dots"; end
	local function Drawn() return S().style == "smooth"; end
	local function Filling() return S().mode == "cooldown"; end
	local function Sized(d) return d.sizePattern ~= nil or d.radius ~= nil or d.radii ~= nil or d.sizeOf ~= nil; end
	local function Round(d) return d.shape == "circle" or d.shape == "cone"; end
	-- a fill that fills in: a cooldown's, a spot's time, a revive
	local function Progress(d) return ( Round(d) and S().mode == "cooldown" ) or d.shape == "ground" or d.shape == "downed"; end

	Section(panel, "Behaviour");
	Choice(panel, "When", function(d) return d.modes ~= nil; end, ModeChoices, Get("mode"), Put("mode"));
	Stepper(panel, "Flash length", function()
			local m = S().mode;
			return m == "cast" or m == "event" or m == "shield" or m == "proc";
		end,
		Get("flash"), Put("flash"), 0.1, 0.1, 5, function(v) return string.format(L("%.1f sec"), v); end, true);
	-- fewer at once (a pack dying together, many spots, many guardians), for a calmer screen or a
	-- slower computer: every telegraph that can show more than one
	Stepper(panel, "Most at once", function(d) return Many(d); end, Get("most"), Put("most"), 1, 0, 40,
		function(v) return v <= 0 and L("no limit") or string.format(L("%d rings"), v); end);
	-- the time it shows, each on its own: a cooldown filling in, a spot's time running out, and a ring
	-- that moves with you up for good
	Check(panel, "Cooldown fill", function(d) return Round(d) and S().mode == "cooldown"; end,
		Get("cdFill"), Put("cdFill"), "Fills as the cooldown runs");
	Check(panel, "Duration fill", function(d) return d.shape == "ground"; end, Get("durFill"), Put("durFill"),
		"Fills as its time runs out");
	Check(panel, "Uptime look", function(d) return d.follows ~= nil; end, Get("uptime"), Put("uptime"),
		"Comets while it never runs out");

	-- each part on its own: off is gone entirely (a fill off needs no opacity of 0)
	Section(panel, "Parts");
	Check(panel, "Outline", nil, Get("lineOn"), Put("lineOn"), "The ring's edge");
	Check(panel, "Glow", function() return not Dotty(); end, Get("glow"), Put("glow"), "Soft light along the edge");
	Check(panel, "Fill", nil, Get("fillOn"), Put("fillOn"), "The area itself, and what fills it in");
	Check(panel, "Background area", Progress, Get("areaOn"), Put("areaOn"), "The faint area still to fill");
	Check(panel, "Front line", Progress, Get("frontOn"), Put("frontOn"), "The bright line the fill has reached");
	Check(panel, "Cast pulse", function(d) return Round(d) or d.follows ~= nil; end, Get("pulseOn"), Put("pulseOn"),
		"The flash and shockwave of a cast");
	-- a guardian's rings: warming to red as you near the edge, and a line of text under you
	Section(panel, "Warning");
	local function World(d) return d.shape == "world"; end
	Stepper(panel, "Warn from", World, Get("warnAt"), Put("warnAt"), 1, 0, 40,
		function(v) return v <= 0 and L("off") or string.format(L("%g yd before its edge"), v); end, true);
	Check(panel, "Warning text", function(d) return World(d) and S().warnAt > 0; end, Get("warnText"), Put("warnText"),
		"How far is left, under your hero");
	-- depth helpers: rings round you and cones read better from low down
	Section(panel, "Depth");
	Check(panel, "Edge wall", Round, Get("wallOn"), Put("wallOn"), "A see-through wall standing on the edge");
	Stepper(panel, "Wall height", function(d) return Round(d) and S().wallOn; end, Get("wallHeight"), Put("wallHeight"),
		0.25, 0.25, 5, Yd, true);
	Check(panel, "Mark enemies", Round, Get("marks"), Put("marks"), "A mark under every enemy inside it");
	Check(panel, "Range bands", Round, Get("bands"), Put("bands"), "Faint arcs at set distances inside it");
	Stepper(panel, "Band every", function(d) return Round(d) and S().bands; end, Get("bandEvery"), Put("bandEvery"),
		1, 1, 50, Yd, true);
	Check(panel, "Band numbers", function(d) return Round(d) and S().bands; end, Get("bandNumbers"), Put("bandNumbers"),
		"Each band's distance at its side");

	Section(panel, "Size");
	Stepper(panel, "Size override", Sized, Get("length"), Put("length"), 0.5, 0, 100,
		function(v) return v <= 0 and L("off (automatic)") or Yd(v); end, true);
	Stepper(panel, "Radius", function(d) return not Sized(d); end, Get("radius"), Put("radius"), 0.5, 0.5, 100, Yd, true);

	Section(panel, "Look");
	Choice(panel, "Style", nil, { { "texture", "Texture", 70 }, { "smooth", "Drawn", 60 }, { "dots", "Dots", 50 } },
		Get("style"), Put("style"));
	Color(panel, "Outline colour", nil, "line");
	Stepper(panel, "Outline opacity", nil, function() return S().line[4]; end,
		function(v) S().line[4] = v; Mark("lineA"); end, 0.05, 0, 1, Pct);
	Stepper(panel, "Outline width", function() return not Dotty(); end, Get("width"), Put("width"), 1, 1, 12, Px);
	Color(panel, "Fill colour", nil, "fill");
	Stepper(panel, "Fill opacity", nil, function() return S().fill[4]; end,
		function(v) S().fill[4] = v; Mark("fillA"); end, 0.05, 0, 1, Pct);
	Stepper(panel, "Fill detail", Drawn, Get("strip"), Put("strip"), 1, 1, 8,
		function(v) return string.format(L("%g px strips"), v); end);
	Stepper(panel, "Dot size", Dotty, Get("size"), Put("size"), 1, 1, 16, Px);
	Stepper(panel, "Dot spacing", Dotty, Get("spacing"), Put("spacing"), 1, 3, 40, Px);
	Choice(panel, "Fill style", function() return Dotty() and Filling(); end,
		{ { "solid", "Solid", 70 }, { "front", "Front line only", 110 } }, Get("fillStyle"), Put("fillStyle"));
	Stepper(panel, "Fill spacing", function() return Dotty() and Filling() and S().fillStyle == "solid"; end,
		Get("fillSpacing"), Put("fillSpacing"), 1, 4, 60, Px);
	-- the minimap's pins (Guardians.lua): its rows alone
	panel.tag = "pins";
	local function Pins(d) return d.shape == "pins"; end
	Section(panel, "Minimap");
	Check(panel, "Guardians", Pins, Get("pinGuardians"), Put("pinGuardians"), "Asleep white, chasing you red");
	Check(panel, "Lair timers", Pins, Get("pinTimers"), Put("pinTimers"), "An empty lair, and when it fills");
	Check(panel, "Bosses", Pins, Get("pinBosses"), Put("pinBosses"), "Each boss alive");
	Check(panel, "Caches", Pins, Get("pinCaches"), Put("pinCaches"), "Each cache not yet opened");
	Check(panel, "Past the edge", Pins, Get("pinEdge"), Put("pinEdge"), "Kept on the rim, pointing their way");
	Stepper(panel, "Pin size", Pins, Get("pinSize"), Put("pinSize"), 1, 6, 32, Px);
	panel.tag = nil;
	RangeRows(panel);
	-- the mode and style change which rows show
	table.insert(panel.refreshers, function() Layout(panel); end);
end

local function BuildPanel()
	local panel = Box(win);
	ui.panel = panel;
	panel:SetPoint("TOPLEFT", ui.list, "TOPRIGHT", 8, 0);
	panel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10);
	panel.rows, panel.refreshers, panel.live, panel.top = {}, {}, {}, -96;

	-- its name, on/off, what it is and how it stands
	ui.name = Label(panel, "", "GameFontNormalLarge");
	ui.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12);
	ui.onoff = Button(panel, "", 64, 20, function()
		local s = AST.Settings(selected);
		s.enabled = not s.enabled;
		s.hand = s.hand or {};
		s.hand.enabled = true;
		Refresh();
	end);
	ui.onoff:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -10);
	ui.desc = Label(panel, "");
	ui.desc:SetTextColor(0.75, 0.75, 0.8);
	ui.desc:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -36);
	ui.desc:SetPoint("RIGHT", panel, "RIGHT", -14, 0);
	ui.desc:SetJustifyH("LEFT");
	ui.desc:SetHeight(26);
	ui.desc:SetJustifyV("TOP");
	ui.status1 = Label(panel, "");
	ui.status1:SetTextColor(0.55, 0.8, 1);
	ui.status1:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -64);
	ui.status2 = Label(panel, "");
	ui.status2:SetTextColor(0.55, 0.8, 1);
	ui.status2:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -78);
	table.insert(panel.refreshers, function()
		local s = AST.Settings(selected);
		ui.name:SetText(Named(selected));
		ui.desc:SetText(Describe(selected));
		ui.onoff.text:SetText(s.enabled and L("On") or L("Off"));
		if ( s.enabled ) then
			ui.onoff:SetBackdropColor(0.12, 0.4, 0.18, 0.95);
			ui.onoff:SetBackdropBorderColor(0.35, 0.9, 0.45, 1);
		else
			SetActive(ui.onoff, false);
		end
	end);
	table.insert(panel.live, function()
		-- notes on why it won't show are amber, the rest blue
		local a, b, warn = StatusLines();
		ui.status1:SetText(a);
		ui.status2:SetText(b);
		if ( warn ) then
			ui.status1:SetTextColor(1, 0.6, 0.2);
			ui.status2:SetTextColor(1, 0.6, 0.2);
		else
			ui.status1:SetTextColor(0.55, 0.8, 1);
			ui.status2:SetTextColor(0.55, 0.8, 1);
		end
	end);

	SettingRows(panel);
	Scrolls(panel, -(H - TOP - 10 - 42), 38);

	-- Test hides this window while it plays, as the window sits over your hero.
	local reopenAt;
	local reopener = CreateFrame("Frame");
	reopener:SetScript("OnUpdate", function()
		if ( reopenAt and GetTime() >= reopenAt ) then
			reopenAt = nil;
			win:Show();
		end
	end);
	local test = Button(panel, "Test", 60, 22, function()
		AST.preview[selected.id] = GetTime() + 3;
		reopenAt = GetTime() + 3.2;
		win:Hide();
	end);
	test:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10);
	local reset = Button(panel, "Reset", 60, 22, function()
		AST.ResetSettings(selected);
		Refresh();
	end);
	reset:SetPoint("LEFT", test, "RIGHT", 6, 0);
	-- this one's look onto others: a small menu above the button
	local menu = CreateFrame("Frame", nil, panel);
	menu:SetBackdrop(FLAT);
	menu:SetBackdropColor(0.08, 0.08, 0.11, 0.98);
	menu:SetBackdropBorderColor(0.75, 0.55, 1, 1);
	menu:SetWidth(232);
	menu:SetHeight(82);
	menu:SetFrameLevel((panel:GetFrameLevel() or 0) + 20);
	menu:EnableMouse(true);
	menu:Hide();
	local copy = Button(panel, "Copy look to...", 120, 22, function()
		if ( menu:IsShown() ) then
			menu:Hide();
		else
			menu:Show();
		end
	end);
	copy:SetPoint("LEFT", reset, "RIGHT", 6, 0);
	menu:SetPoint("BOTTOMLEFT", copy, "TOPLEFT", 0, 4);
	local note = Label(menu, "Style, colours, sizes and parts:");
	note:SetTextColor(0.7, 0.7, 0.75);
	note:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8);
	local toPage = Button(menu, "Every telegraph on this page", 212, 20, function() menu:Hide(); CopyLook("page"); end);
	toPage:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -26);
	local toAll = Button(menu, "Every telegraph, every class", 212, 20, function() menu:Hide(); CopyLook("all"); end);
	toAll:SetPoint("TOPLEFT", toPage, "BOTTOMLEFT", 0, -4);
	-- what a copy did, for a few seconds
	local said = Label(panel, "");
	said:SetTextColor(0.4, 1, 0.5);
	said:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 38);
	table.insert(panel.live, function()
		said:SetText(( ui.said and ui.saidAt and GetTime() - ui.saidAt < 5 ) and ui.said or "");
	end);
	-- one of your own rings: it can go
	local remove = Button(panel, "Remove ring", 90, 22, function()
		if ( selected and selected.custom ) then
			AST.RemoveRing(selected);
			ShowPage(page);
		end
	end);
	remove:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 10);
	table.insert(panel.refreshers, function()
		if ( selected.custom ) then
			remove:Show();
		else
			remove:Hide();
		end
		-- (an experiment, or one with rows of its own: nothing to copy)
		if ( selected.shape == "lab" or selected.ownRows ) then
			copy:Hide();
			menu:Hide();
		else
			copy:Show();
		end
	end);
end

---------------------------------------------------------------------------------------------
-- The General page

local function BuildGeneral()
	local g = Box(win);
	ui.general = g;
	g:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -TOP);
	g:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10);
	g.rows, g.refreshers, g.live, g.top = {}, {}, {}, -4;
	local function DB() return (AST.State()); end

	Section(g, "Minimap");
	Check(g, "Minimap button", nil, function() return not DB().minimapHidden; end,
		function(v) AST.ShowMinimapButton(v); end, "Left-click opens this window, right-click hides every telegraph.");

	Section(g, "Talents");
	Check(g, "Ask the meter", nil, function() return not DB().meterOff; end,
		function(v) DB().meterOff = (not v) or nil; end,
		"Gets your talents from the damage meter, so talent telegraphs show at once.");
	Text(g, "The meter has", nil, function() return AST.meter.status; end);
	Text(g, "Your talents", nil, function()
		local list = AST.meter.list;
		return table.getn(list) > 0 and table.concat(list, ", ") or L("none read yet");
	end, 44);

	Section(g, "Cones");
	Check(g, "Mirror cones", nil, function() return DB().mirror; end, function(v) DB().mirror = v or nil; end,
		"Only if cones point the wrong way.");
	Stepper(g, "Turn cones", nil, function() return DB().rotate or 0; end, function(v) DB().rotate = v; end,
		5, -180, 180, function(v) return string.format(L("%g degrees"), v); end);

	Section(g, "Drawing");
	Text(g, "Now", nil, function()
		local calls, quads, problem = AST.Stats();
		return problem or string.format(L("%d pieces on screen"), quads);
	end);
	-- the Lab's FPS counter (Lab.lua; off to start with), here so it needn't be looked for in the Lab
	local function Fps()
		local _, _, _, _, byId = AST.State();
		return byId and byId.lab_fps;
	end
	Check(g, "FPS counter", function() return Fps() ~= nil; end, function() return Fps() ~= nil and AST.Settings(Fps()).enabled == true; end,
		function(v)
			if ( Fps() ) then
				AST.Settings(Fps()).enabled = v;
			end
		end, "Frame rate and what the telegraphs take of it, in a bar you can drag.");

	-- everything as it came, asked first
	Section(g, "Start over");
	Actions(g, "Defaults", nil, { { "Reset everything to defaults", function()
		Confirm(L("Every telegraph on every page, and the settings on this page, go back to their defaults. Your own rings stay, with their settings reset too. This can't be undone."),
			"Reset everything", function()
				ResetEverything();
				Refresh();
			end);
	end } });

	Section(g, "Commands");
	Text(g, "/ast", nil, function() return L("opens this window"); end);
	Text(g, "/ast ring 10", nil, function() return L("a 10 yd custom ring around you (/ast ring turns it on or off)"); end);
	Text(g, "/ast debug", nil, function() return L("what the addon reads, for when a telegraph doesn't show"); end);
	Text(g, "/ast meter", nil, function() return L("your talents as the meter lists them"); end);
	Text(g, "/ast share", nil, function() return L("import or export telegraph setups"); end);
	Text(g, "/ast showcase", nil, function() return L("all your telegraphs at once, turning round you, for a video (again to stop)"); end);
	Text(g, "/ast lab", function() return DB().labTab; end, function() return L("the Lab's commands (fps, textest)"); end);
	Scrolls(g, -(H - TOP - 10 - 10), 6);
	Layout(g);
	table.insert(g.refreshers, function() Layout(g); end);
end

---------------------------------------------------------------------------------------------
-- The All telegraphs page: one change to many telegraphs at a time. Each is written into every
-- telegraph it reaches; afterwards each one's own page sets it differently, and a setting changed
-- there stays (unless "Keep my own" is off).

-- A colour to give many telegraphs: its swatch, the presets, the colour picker, and Apply.
local function BulkColor(panel, label, key, apply)
	local row = Row(panel, label, nil);
	local function C()
		local b = AST.State().ui.bulk;
		b[key] = b[key] or { 1, 1, 1 };
		return b[key];
	end
	local swatch = row:CreateTexture(nil, "OVERLAY");
	AST.SetPiece(swatch, SOLID);
	swatch:SetWidth(18);
	swatch:SetHeight(18);
	swatch:SetPoint("LEFT", row, "LEFT", CX, 0);
	local function SetRGB(r, g, b)
		local c = C();
		c[1], c[2], c[3] = r, g, b;
		Refresh();
	end
	local x = CX + 26;
	for i = 1, table.getn(PRESETS) do
		local pc = PRESETS[i];
		local b = CreateFrame("Button", nil, row);
		b:SetWidth(14);
		b:SetHeight(14);
		b:SetPoint("LEFT", row, "LEFT", x, 0);
		local t = b:CreateTexture(nil, "OVERLAY");
		AST.SetPiece(t, SOLID);
		t:SetVertexColor(pc[1], pc[2], pc[3], 1);
		t:SetAllPoints(b);
		b:SetScript("OnClick", function() SetRGB(pc[1], pc[2], pc[3]); end);
		x = x + 17;
	end
	if ( ColorPickerFrame ) then
		local pick = Button(row, "Pick", 40, 18, function()
			local c = C();
			local before = { r = c[1], g = c[2], b = c[3] };
			ColorPickerFrame.hasOpacity = nil;
			ColorPickerFrame.previousValues = before;
			ColorPickerFrame.func = function()
				SetRGB(ColorPickerFrame:GetColorRGB());
			end;
			ColorPickerFrame.cancelFunc = function()
				SetRGB(before.r, before.g, before.b);
			end;
			ColorPickerFrame:SetColorRGB(c[1], c[2], c[3]);
			if ( ShowUIPanel ) then
				ShowUIPanel(ColorPickerFrame);
			else
				ColorPickerFrame:Show();
			end
		end);
		pick:SetPoint("LEFT", row, "LEFT", x + 4, 0);
		x = x + 48;
	end
	local go = Button(row, "Apply", 50, 18, function() apply(C()); end);
	go:SetPoint("LEFT", row, "LEFT", x + 6, 0);
	table.insert(panel.refreshers, function()
		local c = C();
		swatch:SetVertexColor(c[1], c[2], c[3], 1);
	end);
	return row;
end

local function BuildAll()
	local a = Box(win);
	ui.all = a;
	a:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -TOP);
	a:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10);
	a.rows, a.refreshers, a.live, a.top = {}, {}, {}, -4;
	local function DB() return (AST.State()); end
	DB().ui.bulk = DB().ui.bulk or {};
	local function Scope() return DB().ui.bulkScope or "mine"; end
	-- fn(def, settings) on every telegraph the page reaches (false: not that one)
	local function Each(key, fn) Bulk(Reach(Scope()), key, fn); end
	local function Set(key, v) return function() Each(key, function(d, s) s[key] = v; end); end; end
	local function Sized(d) return d.sizePattern ~= nil or d.radius ~= nil or d.radii ~= nil or d.sizeOf ~= nil; end

	Section(a, "Which telegraphs");
	Choice(a, "Change", nil, { { "mine", "Your class + Any class", 150 }, { "all", "Every class", 90 }, { "rings", "Your own rings", 100 } },
		Scope, function(v) DB().ui.bulkScope = v; end);
	Check(a, "Keep my own", nil, function() return DB().ui.bulkLeave ~= false; end, function(v) DB().ui.bulkLeave = v; end,
		"Leave what I changed on a telegraph's own page");
	Actions(a, "Set by hand", nil, { { "Forget which ones I set by hand", function()
		Bulk(Reach(Scope()), "", function(d, s) s.hand = nil; end);
	end } });
	Text(a, "Done", nil, function() return ui.said or L("Nothing changed yet."); end);

	Section(a, "Quick changes");
	Actions(a, "Every one", nil, { { "Turn on", Set("enabled", true) }, { "Turn off", Set("enabled", false) } });
	-- a mode only where the telegraph has it
	local function Mode(m)
		return function()
			Each("mode", function(d, s)
				for i = 1, table.getn(d.modes or {}) do
					if ( d.modes[i] == m ) then
						s.mode = m;
						return true;
					end
				end
				return false;
			end);
		end;
	end
	Actions(a, "When", nil, { { "Briefly on cast", Mode("cast") }, { "Always + cooldown fill", Mode("cooldown") },
		{ "When it goes off", Mode("proc") } });
	Actions(a, "Style", nil, { { "Texture", Set("style", "texture") }, { "Drawn", Set("style", "smooth") },
		{ "Dots", Set("style", "dots") } });

	-- each part on or off everywhere
	Section(a, "Parts");
	local PARTS = { { "Outline", "lineOn" }, { "Glow", "glow" }, { "Fill", "fillOn" }, { "Background area", "areaOn" },
		{ "Front line", "frontOn" }, { "Cast pulse", "pulseOn" }, { "Cooldown fill", "cdFill" },
		{ "Duration fill", "durFill" }, { "Uptime look", "uptime" }, { "Edge wall", "wallOn" }, { "Mark enemies", "marks" },
		{ "Range bands", "bands" }, { "Band numbers", "bandNumbers" } };
	for i = 1, table.getn(PARTS) do
		local part = PARTS[i];
		Actions(a, part[1], nil, { { "On", Set(part[2], true) }, { "Off", Set(part[2], false) } });
	end

	-- a number for every one: set it, then Apply
	Section(a, "Numbers");
	local function Number(label, key, step, lo, hi, fmt, start, apply)
		local row = Stepper(a, label, nil, function()
				local b = DB().ui.bulk;
				if ( b[key] == nil ) then
					b[key] = start;
				end
				return b[key];
			end,
			function(v) DB().ui.bulk[key] = v; end, step, lo, hi, fmt, true);
		local go = Button(row, "Apply", 50, 18, function()
			local v = DB().ui.bulk[key] or start;
			Each(key, function(d, s) return apply(d, s, v); end);
		end);
		go:SetPoint("LEFT", row, "LEFT", CX + 160, 0);
	end
	local function Plain(key) return function(d, s, v) s[key] = v; end; end
	Number("Outline width", "width", 1, 1, 12, Px, 3, Plain("width"));
	Number("Outline opacity", "lineA", 0.05, 0, 1, Pct, 1, function(d, s, v) s.line[4] = v; end);
	Number("Fill opacity", "fillA", 0.05, 0, 1, Pct, 0.3, function(d, s, v) s.fill[4] = v; end);
	Number("Flash length", "flash", 0.1, 0.1, 5, function(v) return string.format(L("%.1f sec"), v); end, 0.6, Plain("flash"));
	Number("Fill detail", "strip", 1, 1, 8, function(v) return string.format(L("%g px strips"), v); end, 3, Plain("strip"));
	Number("Dot size", "size", 1, 1, 16, Px, 5, Plain("size"));
	Number("Dot spacing", "spacing", 1, 3, 40, Px, 9, Plain("spacing"));
	Number("Size override", "length", 0.5, 0, 100, function(v) return v <= 0 and L("off (automatic)") or Yd(v); end, 0,
		function(d, s, v) if ( not Sized(d) ) then return false; end s.length = v; end);
	Number("Ring radius", "radius", 0.5, 0.5, 100, Yd, 8,
		function(d, s, v) if ( Sized(d) ) then return false; end s.radius = v; end);
	Number("Wall height", "wallHeight", 0.25, 0.25, 5, Yd, 1, Plain("wallHeight"));
	Number("Band every", "bandEvery", 1, 1, 50, Yd, 5, Plain("bandEvery"));
	Number("Most at once", "most", 1, 0, 40, function(v) return v <= 0 and L("no limit") or string.format(L("%d rings"), v); end, 0,
		function(d, s, v) if ( not Many(d) ) then return false; end s.most = v; end);

	Section(a, "Colours");
	BulkColor(a, "Outline colour", "line", function(c)
		Each("line", function(d, s) s.line[1], s.line[2], s.line[3] = c[1], c[2], c[3]; end);
	end);
	BulkColor(a, "Fill colour", "fill", function(c)
		Each("fill", function(d, s) s.fill[1], s.fill[2], s.fill[3] = c[1], c[2], c[3]; end);
	end);
	-- back to each one's own colours (their opacity stays)
	local function Own(key)
		return function(d, s)
			local c = ( d.defaults and d.defaults[key] ) or AST.common[key];
			s[key][1], s[key][2], s[key][3] = c[1], c[2], c[3];
		end;
	end
	Actions(a, "Own colours", nil, { { "Each one's own outline colour", function() Each("line", Own("line")); end },
		{ "Each one's own fill colour", function() Each("fill", Own("fill")); end } });

	-- the ones it reaches back as they came, asked first (everything: the General page)
	Section(a, "Start over");
	Actions(a, "Defaults", nil, { { "Reset every one to its defaults", function()
		local defs = Reach(Scope());
		Confirm(string.format(L("The %d telegraphs chosen above go back to their defaults, the settings you changed on their own pages too. This can't be undone."),
			table.getn(defs)), "Reset them", function()
				for i = 1, table.getn(defs) do
					AST.ResetSettings(defs[i]);
				end
				ui.said, ui.saidAt = string.format(L("Reset %d telegraphs to their defaults."), table.getn(defs)), GetTime();
				Refresh();
			end);
	end } });

	Scrolls(a, -(H - TOP - 10 - 10), 6);
	table.insert(a.refreshers, function() Layout(a); end);
end


---------------------------------------------------------------------------------------------
-- The window

---------------------------------------------------------------------------------------------
-- The Hero bar page (HeroBar.lua): every part of the bar, and the game's frames it can hide.

-- The hero bar's icons, class by class (Hero bar page): pick a class and a group, and everything
-- that has been on its bar is listed, each shown or not.
local function HeroPicks(h)
	local B = AST.bar;
	local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" };
	local GROUPS = { { "skills", "Skills", 56 }, { "jewelry", "Jewelry", 64 }, { "buffs", "Buffs", 50 } };
	local ROWS = 64;
	local function Class()
		local _, _, my = AST.State();
		return ui.barClass or my or "warrior";
	end
	local function Group() return ui.barGroup or "skills"; end
	-- everything the class's group can hold (the catalog's, then what else has been on its bar)
	local function Items() return B.Choices(Class(), Group()); end
	local function Off(it) return it.e ~= nil and it.e.off == true; end
	local function All(off)
		local items = Items();
		for i = 1, table.getn(items) do
			B.SetChoice(Class(), Group(), items[i], off);
		end
		-- every box shows it at once
		Refresh();
	end
	Section(h, "Which icons");
	Choice(h, "Of", nil, GROUPS, Group, function(v) ui.barGroup = v; end);
	-- (a class's own skills; buffs and jewelry are chosen once for every class)
	Pick(h, "Class", function() return Group() == "skills"; end, function()
		local out = {};
		for i = 1, table.getn(CLASSES) do
			table.insert(out, { CLASSES[i], Title(CLASSES[i]) });
		end
		return out;
	end, Class, function(v) ui.barClass = v; end);
	Text(h, "", nil, function()
		local items, on = Items(), 0;
		for i = 1, table.getn(items) do
			if ( not Off(items[i]) ) then
				on = on + 1;
			end
		end
		if ( table.getn(items) == 0 ) then
			return L("Nothing yet: what shows on your bar is listed here.");
		end
		return string.format(L("%d of %d shown"), on, table.getn(items));
	end);
	Actions(h, "All of them", nil, { { "Show all", function() All(nil); end }, { "Hide all", function() All(true); end } });
	for i = 1, ROWS do
		-- Lua 5.0 has one `i` for the whole loop, so each row keeps its own copy
		local index = i;
		local row = Row(h, "", function() return Items()[index] ~= nil; end);
		local b = Button(row, "", 16, 16, function()
			local it = Items()[index];
			if ( it ) then
				B.SetChoice(Class(), Group(), it, not Off(it));
				Refresh();
			end
		end);
		b:SetPoint("LEFT", row, "LEFT", CX, 0);
		local mark = b:CreateTexture(nil, "OVERLAY");
		AST.SetPiece(mark, SOLID);
		mark:SetVertexColor(0.75, 0.55, 1, 1);
		mark:SetWidth(8);
		mark:SetHeight(8);
		mark:SetPoint("CENTER", b, "CENTER", 0, 0);
		local icon = row:CreateTexture(nil, "ARTWORK");
		icon:SetWidth(16);
		icon:SetHeight(16);
		icon:SetPoint("LEFT", row, "LEFT", CX + 24, 0);
		local name = Label(row, "");
		name:SetPoint("LEFT", row, "LEFT", CX + 46, 0);
		table.insert(h.refreshers, function()
			local it = Items()[index];
			if ( not it ) then
				return;
			end
			local off = Off(it);
			if ( off ) then
				mark:Hide();
			else
				mark:Show();
			end
			icon:SetTexture(it.icon);
			icon:SetVertexColor(1, 1, 1, off and 0.35 or 1);
			name:SetText(it.name);
			name:SetTextColor(off and 0.5 or 0.9, off and 0.5 or 0.9, off and 0.55 or 0.9);
		end);
	end
	-- something new on the bar while this is open: listed at once
	local seen = B.seenV;
	table.insert(h.live, function()
		if ( B.seenV ~= seen ) then
			seen = B.seenV;
			Refresh();
		end
	end);
end

-- The Bars page: the hero bar's settings or the target bar's, one at a time, chosen by a row of two
-- tabs over each one's own (the user, 2026-11-26: "combine hero and target bars into one Bars tab -
-- then have hero and target bars as tabs inside with theire repective sub tabs").
local function BarSwitch(h)
	local list = { { "hero", "Hero bar", 90 }, { "target", "Target bar", 96 } };
	local buttons, tx = {}, 12;
	for i = 1, 2 do
		local id = list[i][1];
		local b = Button(h, list[i][2], list[i][3], 22, function()
			ui.barsTab = id;
			ShowPage("bars");
		end);
		b:SetPoint("TOPLEFT", h, "TOPLEFT", tx, -8);
		tx = tx + math.max(list[i][3], b:GetWidth() or 0) + 4;
		buttons[id] = b;
	end
	table.insert(h.refreshers, function()
		for id, b in pairs(buttons) do
			SetActive(b, id == ( ui.barsTab or "hero" ));
		end
	end);
	-- a line between them and the bar's own tabs
	local r = Rule(h, 0.15);
	r:SetPoint("TOPLEFT", h, "TOPLEFT", 12, -35);
	r:SetPoint("TOPRIGHT", h, "TOPRIGHT", -12, -35);
end

local function BuildHero()
	local h = Box(win);
	ui.hero = h;
	h:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -TOP);
	h:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10);
	h.rows, h.refreshers, h.live, h.top = {}, {}, {}, -72;
	local B = AST.bar;
	BarSwitch(h);
	-- its parts on tabs along its top (the user, 2026-11-25: the page was long); the last one shown
	-- is kept for the session
	local SUBS = { { "bar", "Bar", 60 }, { "health", "Health & mana", 116 }, { "shields", "Shields", 72 }, { "icons", "Icons", 60 },
		{ "frames", "Game frames", 104 } };
	h.sub = ui.heroTab or "bar";
	local tabs, tx = {}, 12;
	for i = 1, table.getn(SUBS) do
		local id = SUBS[i][1];
		local b = Button(h, SUBS[i][2], SUBS[i][3], 22, function()
			h.sub, ui.heroTab, h.offset = id, id, 0;
			Refresh();
		end);
		b:SetPoint("TOPLEFT", h, "TOPLEFT", tx, -42);
		tx = tx + math.max(SUBS[i][3], b:GetWidth() or 0) + 4;
		tabs[id] = b;
	end
	table.insert(h.refreshers, function()
		for id, b in pairs(tabs) do
			SetActive(b, id == h.sub);
		end
	end);
	local function S() return B.S(); end
	local function Get(key) return function() return S()[key]; end; end
	local function Set(key) return function(v) S()[key] = v; end; end
	local function Is(key, v) return function() return S()[key] == v; end; end
	local function Yes(key) return function() return S()[key]; end; end
	local function Times(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end
	local function Count(v) return tostring(v); end
	local function NotNone() return S().text ~= "none"; end

	h.subTag = "bar";
	Section(h, "Hero bar");
	Check(h, "Show it", nil, Get("on"), Set("on"), "Your health, shields, mana and icons, where you want them.");
	Check(h, "Locked", nil, Get("locked"), Set("locked"), "Unlock it to drag it; right-click it to lock it again.");
	Choice(h, "Place", nil, { { "screen", "Where you put it", 120 }, { "hero", "Above your hero", 120 },
		{ "under", "Under your hero", 120 } }, Get("anchor"), Set("anchor"));
	Stepper(h, "Height above you", Is("anchor", "hero"), Get("above"), Set("above"), 0.2, 0, 8, Yd, true);
	Stepper(h, "Gap under you", Is("anchor", "under"), Get("below"), Set("below"), 1, 0, 200, Px, true);
	Choice(h, "Look", nil, { { "subdued", "Subdued", 80 }, { "sleek", "Sleek", 70 }, { "bold", "Bold", 60 } }, Get("look"),
		function(v) B.ApplyLook(v); end);
	Actions(h, "Position", nil, { { "Reset position", function()
		local d, s = B.Defaults(), S();
		s.anchor, s.point, s.rel, s.x, s.y = "screen", d.point, d.rel, d.x, d.y;
	end } });
	-- the demo (shown even while it's off; your settings stay as they are); again to stop it
	local try = Row(h, "Try it");
	local test = Button(try, "Stop test", 80, 18, function() B.Test(); end);
	test:SetPoint("LEFT", try, "LEFT", CX, 0);
	table.insert(h.live, function() test.text:SetText(L(B.Testing() and "Stop test" or "Test")); end);

	Section(h, "Size");
	Stepper(h, "Width", nil, Get("width"), Set("width"), 10, 60, 700, Px, true);
	Stepper(h, "Height", nil, Get("height"), Set("height"), 1, 3, 60, Px, true);
	Stepper(h, "Scale", nil, Get("scale"), Set("scale"), 0.05, 0.5, 3, Times);
	Stepper(h, "Opacity", nil, Get("alpha"), Set("alpha"), 0.05, 0.1, 1, Pct);
	Check(h, "Fade when full", nil, Get("fadeFull"), Set("fadeFull"), "Fainter while your health is full and you have no shield.");
	Stepper(h, "Faded to", Yes("fadeFull"), Get("fadeAlpha"), Set("fadeAlpha"), 0.05, 0, 1, Pct);

	h.subTag = "health";
	Section(h, "Health");
	Choice(h, "Colour", nil, { { "health", "By health", 80 }, { "class", "Class", 60 }, { "custom", "Your own", 80 } },
		Get("healthColor"), Set("healthColor"));
	Color(h, "Your colour", Is("healthColor", "custom"), "healthRGB", S);
	Choice(h, "Bar", nil, { { "shaded", "Shaded", 70 }, { "flat", "Flat", 60 } }, Get("texture"), Set("texture"));
	Choice(h, "Numbers", nil, { { "none", "None", 50 }, { "percent", "%", 36 }, { "current", "Health", 60 },
		{ "both", "Health / max", 90 }, { "full", "All", 40 } }, Get("text"), Set("text"));
	Check(h, "Shield in the numbers", NotNone, Get("textShield"), Set("textShield"),
		"Health + shield: with Health / max, (health + shield) / max.");
	Choice(h, "Numbers at", NotNone, { { "center", "Middle", 60 }, { "left", "Left", 50 }, { "right", "Right", 50 },
		{ "above", "Above", 56 } }, Get("textPos"), Set("textPos"));
	Stepper(h, "Number size", NotNone, Get("textSize"), Set("textSize"), 1, 7, 24, Px);
	Stepper(h, "Background", nil, Get("bgAlpha"), Set("bgAlpha"), 0.05, 0, 1, Pct);
	Check(h, "Border", nil, Get("border"), Set("border"), "A thin dark line round it, red and pulsing at low health.");
	Check(h, "Gloss", nil, Get("gloss"), Set("gloss"), "Light along its top.");
	Check(h, "Light sweep", nil, Get("sheen"), Set("sheen"), "A soft light runs across it now and then.");
	Check(h, "Smooth", nil, Get("smooth"), Set("smooth"), "It slides to new values instead of jumping.");
	Check(h, "Damage trail", nil, Get("trail"), Set("trail"), "What a hit took lingers a moment, then drains away.");
	Stepper(h, "Warn below", nil, Get("lowAt"), Set("lowAt"), 5, 0, 80, function(v)
		return v > 0 and string.format("%d%%", v) or L("Off");
	end);

	Section(h, "Mana");
	Check(h, "Show mana", nil, Get("power"), Set("power"), "Or rage, or energy: a thin bar under your health.");
	Stepper(h, "Mana height", Yes("power"), Get("powerHeight"), Set("powerHeight"), 1, 1, 20, Px);

	h.subTag = "shields";
	Section(h, "Shields");
	Check(h, "Show shields", nil, Get("shield"), Set("shield"), "Laid over your health: past 100% another layer goes over the first.");
	Choice(h, "Shows", Yes("shield"), { { "amount", "How much", 80 }, { "marker", "That you have one", 130 } },
		Get("shieldStyle"), Set("shieldStyle"));
	Stepper(h, "Mark size", function() return S().shield and S().shieldStyle == "marker"; end, Get("shieldMark"), Set("shieldMark"),
		5, 5, 100, function(v) return string.format(L("%d%% of the bar"), v); end);
	Choice(h, "Shield look", Yes("shield"), { { "energy", "Energy", 70 }, { "flat", "Flat", 60 } }, Get("shieldLook"), Set("shieldLook"));
	Color(h, "First layer", Yes("shield"), "shield1", S);
	Color(h, "Second layer", function() return S().shield and S().shieldStyle ~= "marker"; end, "shield2", S);
	Color(h, "Third layer", function() return S().shield and S().shieldStyle ~= "marker"; end, "shield3", S);
	Stepper(h, "Shield opacity", Yes("shield"), Get("shieldAlpha"), Set("shieldAlpha"), 0.05, 0.1, 1, Pct);
	Check(h, "Shield number", Yes("shield"), Get("shieldText"), Set("shieldText"), "How much it holds, at the bar's end.");
	Check(h, "Hits and breaks", Yes("shield"), Get("shieldFx"), Set("shieldFx"), "A flicker when it's hit, a flash when it breaks.");

	h.subTag = "icons";
	Section(h, "Icons");
	Check(h, "Skills", nil, Get("skills"), Set("skills"), "Your spells on action bar 1 to 6.");
	Check(h, "Jewelry", nil, Get("jewelry"), Set("jewelry"), "What you wear, with its own clock where it has one.");
	Check(h, "Buffs", nil, Get("buffs"), Set("buffs"), "What's on you, with the time left.");
	Stepper(h, "Most buffs", Yes("buffs"), Get("buffsMax"), Set("buffsMax"), 1, 1, 24, Count);
	Choice(h, "Side", nil, { { "below", "Below", 60 }, { "above", "Above", 60 } }, Get("iconSide"), Set("iconSide"));
	Choice(h, "Rows", nil, { { "each", "A row each", 90 }, { "one", "All in one", 90 } }, Get("iconRows"), Set("iconRows"));
	Choice(h, "Line up", nil, { { "left", "Left", 50 }, { "center", "Middle", 60 }, { "right", "Right", 50 } },
		Get("iconAlign"), Set("iconAlign"));
	Stepper(h, "Icon size", nil, Get("iconSize"), Set("iconSize"), 1, 10, 64, Px, true);
	Stepper(h, "Gap", nil, Get("iconGap"), Set("iconGap"), 1, 0, 20, Px);
	Check(h, "Cooldowns", nil, Get("cooldowns"), Set("cooldowns"), "When each comes back, on its icon. Off: just what you have.");
	Check(h, "Cooldown shade", Yes("cooldowns"), Get("sweep"), Set("sweep"), "Dark over what's left of a cooldown.");
	Check(h, "Seconds left", Yes("cooldowns"), Get("timers"), Set("timers"));
	Check(h, "Glow when ready", Yes("cooldowns"), Get("glow"), Set("glow"));
	Check(h, "Grey while waiting", Yes("cooldowns"), Get("grey"), Set("grey"), "A skill on cooldown in grey.");
	HeroPicks(h);

	h.subTag = "frames";
	Section(h, "Game frames");
	Check(h, "Hide your frame", nil, Get("hidePlayer"), function(v) S().hidePlayer = v; B.Park(); end,
		"The game's player frame.");
	-- the skill and jewelry icons under your frame: the game draws them itself, so they're its own
	-- "Show Build" setting (its Interface page has it too), switched here
	-- (not while Survivor UI keeps the game's row away itself, for its Build list: its to show then,
	-- and unticking here would bring the game's row back beside its list)
	local function SuiBuild()
		local d = IsAddOnLoaded and IsAddOnLoaded("SurvivorUI") and SurvivorUIDB;
		return d and ( ( d.buildList ~= false and not d.gameBuildToo ) or d.noGameBuild ) and true or false;
	end
	local function HasBuild() return type(AZS_SetHudShown) == "function" and type(AZS_IsHudShown) == "function" and not SuiBuild(); end
	Check(h, "Hide your skill icons", HasBuild, function() return HasBuild() and not AZS_IsHudShown("build"); end,
		function(v)
			-- (kept as ours too, put on again each session: SurvivorUI turns the game's back on as it closes)
			S().hideBuild = v or nil;
			if ( HasBuild() ) then
				AZS_SetHudShown("build", not v);
			end
		end, "The game's skill and jewelry icons under your frame (its Show Build setting).");
	Check(h, "Hide your buffs", nil, Get("hideBuffs"), function(v) S().hideBuffs = v; B.Park(); end,
		"The game's buff icons by the minimap (the hero bar can show them instead).");
	Check(h, "Hide enemy frame", nil, Get("hideTarget"), function(v) S().hideTarget = v; B.Park(); end,
		"The frame of the enemy you target.");
	Text(h, "/ast what", nil, function() return L("names the frame under the mouse, and what these hide"); end);

	h.subTag = "bar";
	Section(h, "Start over");
	Actions(h, "Hero bar", nil, { { "Reset the hero bar", function()
		Confirm(L("Every hero bar setting goes back to its default, its place too. This can't be undone."),
			"Reset", function() B.Reset(); Refresh(); end);
	end } });
	Text(h, "/ast bar", nil, function() return L("shows or hides it (lock, unlock, test, reset, shield)"); end);
	h.subTag = nil;
	Scrolls(h, -(H - TOP - 10 - 10), 6);
	Layout(h);
	table.insert(h.refreshers, function() Layout(h); end);
end

-- The target bar's page (TargetBar.lua): its parts on tabs along its top, as the hero bar's (the
-- user, 2026-11-26: "similalrly styled ... with its own customization ... completly customizable").
local function BuildTarget()
	local h = Box(win);
	ui.target = h;
	h:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -TOP);
	h:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10);
	h.rows, h.refreshers, h.live, h.top = {}, {}, {}, -72;
	local T = AST.tbar;
	BarSwitch(h);
	local SUBS = { { "frame", "Bar", 60 }, { "health", "Health & mana", 116 }, { "text", "Name & numbers", 124 },
		{ "auras", "Debuffs & buffs", 124 } };
	h.sub = ui.targetTab or "frame";
	local tabs, tx = {}, 12;
	for i = 1, table.getn(SUBS) do
		local id = SUBS[i][1];
		local b = Button(h, SUBS[i][2], SUBS[i][3], 22, function()
			h.sub, ui.targetTab, h.offset = id, id, 0;
			Refresh();
		end);
		b:SetPoint("TOPLEFT", h, "TOPLEFT", tx, -42);
		tx = tx + math.max(SUBS[i][3], b:GetWidth() or 0) + 4;
		tabs[id] = b;
	end
	table.insert(h.refreshers, function()
		for id, b in pairs(tabs) do
			SetActive(b, id == h.sub);
		end
	end);
	local function S() return T.S(); end
	local function Get(key) return function() return S()[key]; end; end
	local function Set(key) return function(v) S()[key] = v; end; end
	local function Is(key, v) return function() return S()[key] == v; end; end
	local function Yes(key) return function() return S()[key]; end; end
	local function Times(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end
	local function Count(v) return tostring(v); end
	local function NotNone() return S().text ~= "none"; end
	local function ByKind() return S().healthColor == "kind"; end
	local SIDES = { { "above", "Above", 60 }, { "below", "Below", 60 } };
	local ALIGN = { { "left", "Left", 50 }, { "center", "Middle", 60 }, { "right", "Right", 50 } };

	h.subTag = "frame";
	Section(h, "Target bar");
	Check(h, "Show it", nil, Get("on"), Set("on"), "The enemy you target: its health, name, debuffs and buffs.");
	Check(h, "Locked", nil, Get("locked"), Set("locked"), "Unlock it to drag it; right-click it to lock it again.");
	Choice(h, "Place", nil, { { "screen", "Where you put it", 120 }, { "bar", "By the hero bar", 120 } }, Get("anchor"), Set("anchor"));
	Choice(h, "Side", Is("anchor", "bar"), { { "right", "Right", 54 }, { "left", "Left", 50 }, { "above", "Above", 56 },
		{ "below", "Below", 56 } }, Get("side"), Set("side"));
	Stepper(h, "Gap", Is("anchor", "bar"), Get("gap"), Set("gap"), 1, 0, 200, Px, true);
	Text(h, "", function() return S().anchor == "bar" and not ( AST.bar and AST.bar.S() and AST.bar.S().on ); end,
		function() return L("The hero bar is off: it stays where you put it until the bar is on."); end);
	Choice(h, "Look", nil, { { "subdued", "Subdued", 80 }, { "sleek", "Sleek", 70 }, { "bold", "Bold", 60 } }, Get("look"),
		function(v) T.ApplyLook(v); end);
	Actions(h, "Position", nil, { { "Reset position", function()
		local d, s = T.Defaults(), S();
		s.anchor, s.point, s.rel, s.x, s.y = "screen", d.point, d.rel, d.x, d.y;
	end } });
	-- the demo (shown even while it's off; your settings stay as they are); again to stop it
	local try = Row(h, "Try it");
	local test = Button(try, "Stop test", 80, 18, function() T.Test(); end);
	test:SetPoint("LEFT", try, "LEFT", CX, 0);
	table.insert(h.live, function() test.text:SetText(L(T.Testing() and "Stop test" or "Test")); end);

	Section(h, "Size");
	Stepper(h, "Width", nil, Get("width"), Set("width"), 10, 60, 700, Px, true);
	Stepper(h, "Height", nil, Get("height"), Set("height"), 1, 3, 60, Px, true);
	Stepper(h, "Scale", nil, Get("scale"), Set("scale"), 0.05, 0.5, 3, Times);
	Stepper(h, "Opacity", nil, Get("alpha"), Set("alpha"), 0.05, 0.1, 1, Pct);

	Section(h, "Game frames");
	Check(h, "Hide enemy frame", nil, function() return AST.bar.S().hideTarget; end,
		function(v) AST.bar.S().hideTarget = v; AST.bar.Park(); end, "The frame of the enemy you target.");

	Section(h, "Start over");
	Actions(h, "Target bar", nil, { { "Reset the target bar", function()
		Confirm(L("Every target bar setting goes back to its default, its place too. This can't be undone."),
			"Reset", function() T.Reset(); Refresh(); end);
	end } });
	Text(h, "/ast target", nil, function() return L("shows or hides it (lock, unlock, test, reset)"); end);

	h.subTag = "health";
	Section(h, "Health");
	Choice(h, "Colour", nil, { { "kind", "By kind", 70 }, { "health", "By health", 80 }, { "custom", "Your own", 80 } },
		Get("healthColor"), Set("healthColor"));
	Color(h, "Your colour", Is("healthColor", "custom"), "healthRGB", S);
	Color(h, "Enemies", ByKind, "kindNormal", S);
	Color(h, "Elites", ByKind, "kindElite", S);
	Color(h, "Guardians", ByKind, "kindGuardian", S);
	Color(h, "Bosses", ByKind, "kindBoss", S);
	Color(h, "Friends", ByKind, "kindFriend", S);
	Choice(h, "Bar", nil, { { "shaded", "Shaded", 70 }, { "flat", "Flat", 60 } }, Get("texture"), Set("texture"));
	Stepper(h, "Background", nil, Get("bgAlpha"), Set("bgAlpha"), 0.05, 0, 1, Pct);
	Check(h, "Border", nil, Get("border"), Set("border"), "A thin dark line round it, in the execute colour while in range.");
	Check(h, "Gloss", nil, Get("gloss"), Set("gloss"), "Light along its top.");
	Check(h, "Light sweep", nil, Get("sheen"), Set("sheen"), "A soft light runs across it now and then.");
	Check(h, "Smooth", nil, Get("smooth"), Set("smooth"), "It slides to new values instead of jumping.");
	Check(h, "Damage trail", nil, Get("trail"), Set("trail"), "What a hit took lingers a moment, then drains away.");

	Section(h, "Execute range");
	Stepper(h, "Execute below", nil, Get("execAt"), Set("execAt"), 1, 0, 90, function(v)
		return v > 0 and string.format("%d%%", v) or L("Off");
	end);
	Color(h, "Execute colour", function() return S().execAt > 0; end, "execRGB", S);

	Section(h, "Mana");
	Check(h, "Show mana", nil, Get("power"), Set("power"), "Or rage, or energy: a thin bar under its health.");
	Stepper(h, "Mana height", Yes("power"), Get("powerHeight"), Set("powerHeight"), 1, 1, 20, Px);

	h.subTag = "text";
	Section(h, "Health");
	Choice(h, "Numbers", nil, { { "none", "None", 50 }, { "percent", "%", 36 }, { "current", "Health", 60 },
		{ "both", "Health / max", 90 }, { "full", "All", 40 } }, Get("text"), Set("text"));
	Choice(h, "Numbers at", NotNone, { { "center", "Middle", 60 }, { "left", "Left", 50 }, { "right", "Right", 50 } },
		Get("textPos"), Set("textPos"));
	Stepper(h, "Number size", NotNone, Get("textSize"), Set("textSize"), 1, 7, 24, Px);
	Section(h, "Name");
	Check(h, "Show name", nil, Get("name"), Set("name"), "Its name, and what it is: an elite, a guardian or a boss.");
	Choice(h, "Name at", Yes("name"), { { "above", "Above", 60 }, { "inside", "Inside", 60 }, { "below", "Below", 60 } },
		Get("namePos"), Set("namePos"));
	Stepper(h, "Name size", Yes("name"), Get("nameSize"), Set("nameSize"), 1, 7, 24, Px);
	Choice(h, "Name colour", Yes("name"), { { "kind", "By kind", 70 }, { "white", "White", 60 } }, Get("nameColor"), Set("nameColor"));
	Check(h, "Its kind", Yes("name"), Get("kindTag"), Set("kindTag"), "Elite, Guardian or Boss after its name.");
	Check(h, "Its target", nil, Get("tot"), Set("tot"), "Whom it's after, at the right of its name.");

	h.subTag = "auras";
	Section(h, "Debuffs");
	Check(h, "Show debuffs", nil, Get("debuffs"), Set("debuffs"), "What's on it, yours and your team's.");
	Stepper(h, "Most debuffs", Yes("debuffs"), Get("debuffsMax"), Set("debuffsMax"), 1, 1, 40, Count);
	Stepper(h, "Icon size", Yes("debuffs"), Get("debuffSize"), Set("debuffSize"), 1, 8, 64, Px, true);
	Choice(h, "Side", Yes("debuffs"), SIDES, Get("debuffSide"), Set("debuffSide"));
	Choice(h, "Line up", Yes("debuffs"), ALIGN, Get("debuffAlign"), Set("debuffAlign"));
	Section(h, "Buffs");
	Check(h, "Show buffs", nil, Get("buffs"), Set("buffs"), "What helps it, when it has any.");
	Stepper(h, "Most buffs", Yes("buffs"), Get("buffsMax"), Set("buffsMax"), 1, 1, 32, Count);
	Stepper(h, "Icon size", Yes("buffs"), Get("buffSize"), Set("buffSize"), 1, 8, 64, Px, true);
	Choice(h, "Side", Yes("buffs"), SIDES, Get("buffSide"), Set("buffSide"));
	Choice(h, "Line up", Yes("buffs"), ALIGN, Get("buffAlign"), Set("buffAlign"));
	Section(h, "Both");
	Stepper(h, "Per row", nil, Get("perRow"), Set("perRow"), 1, 1, 40, Count);
	Stepper(h, "Gap", nil, Get("auraGap"), Set("auraGap"), 1, 0, 20, Px);
	Check(h, "Stacks", nil, Get("stacks"), Set("stacks"), "How many, on the icon.");
	Check(h, "Seconds left", nil, Get("timers"), Set("timers"), "Where the game tells it: a guardian's and a boss's.");
	Check(h, "Time shade", nil, Get("shade"), Set("shade"), "Dark over the time that's gone.");
	Check(h, "Colour by type", nil, Get("typeColor"), Set("typeColor"),
		"A debuff's edge by what takes it off: magic, curse, disease, poison.");
	Check(h, "Tooltips", nil, Get("tips"), Set("tips"), "What it is when you point at it.");
	h.subTag = nil;
	Scrolls(h, -(H - TOP - 10 - 10), 6);
	Layout(h);
	table.insert(h.refreshers, function() Layout(h); end);
end


local function BuildHeader()
	local icon = win:CreateTexture(nil, "ARTWORK");
	icon:SetTexture(ICONS.addon);
	icon:SetWidth(28);
	icon:SetHeight(28);
	icon:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -12);
	local title = Label(win, "Azeroth Survivors Telegraphs", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", win, "TOPLEFT", 50, -13);
	local sub = Label(win, "");
	sub:SetTextColor(0.6, 0.6, 0.65);
	sub:SetPoint("TOPLEFT", win, "TOPLEFT", 50, -31);
	local close = Button(win, "x", 22, 22, function() win:Hide(); end);
	close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -12);
	-- every telegraph off and on again, as the minimap button's right-click
	local hideAll = Button(win, "", 96, 22, function()
		local db = AST.State();
		db.hidden = not db.hidden;
		Refresh();
	end);
	hideAll:SetPoint("RIGHT", close, "LEFT", -6, 0);
	-- telegraph setups out and in
	local shareButton = Button(win, "Import / Export", 96, 22, function() AST.OpenShare(); end);
	shareButton:SetPoint("RIGHT", hideAll, "LEFT", -6, 0);
	-- the showcase (Showcase.lua): all your telegraphs at once, turning round you, for a video
	local showcase = Button(win, "Stop showcase", 96, 22, function()
		if ( AST.showcase ) then
			AST.showcase.Toggle();
		end
	end);
	showcase:SetPoint("RIGHT", shareButton, "LEFT", -6, 0);
	showcase:SetScript("OnEnter", function()
		showcase:SetBackdropBorderColor(1, 0.82, 0, 1);
		GameTooltip:SetOwner(showcase, "ANCHOR_BOTTOM");
		GameTooltip:SetText(L("Shows all your telegraphs at once as one big telegraph turning round you, each with its whole look, until you stop it."));
		GameTooltip:Show();
	end);
	showcase:SetScript("OnLeave", function()
		showcase:SetBackdropBorderColor(0.4, 0.4, 0.5, 1);
		GameTooltip:Hide();
	end);
	local rule = Rule(win, 0.15);
	rule:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -46);
	rule:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -46);

	-- the page's own heading, above its list
	ui.pageIcon = win:CreateTexture(nil, "ARTWORK");
	ui.pageIcon:SetWidth(32);
	ui.pageIcon:SetHeight(32);
	ui.pageIcon:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 18, -58);
	ui.pageTitle = Label(win, "", "GameFontNormalLarge");
	ui.pageTitle:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 58, -58);
	ui.pageSub = Label(win, "");
	ui.pageSub:SetTextColor(0.7, 0.7, 0.75);
	ui.pageSub:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 58, -77);
	ui.pageNote = Label(win, "");
	ui.pageNote:SetTextColor(1, 0.6, 0.2);
	ui.pageNote:SetPoint("TOPLEFT", win, "TOPLEFT", NAV_W + 58, -92);

	table.insert(refreshers, function()
		local db, _, myClass = AST.State();
		hideAll.text:SetText(db.hidden and L("Show all") or L("Hide all"));
		showcase.text:SetText(( AST.showcase and AST.showcase.on ) and L("Stop showcase") or L("Showcase"));
		if ( AST.showcase and AST.showcase.on ) then
			showcase:SetBackdropColor(0.3, 0.18, 0.45, 0.95);
		else
			showcase:SetBackdropColor(0.12, 0.12, 0.16, 0.95);
		end
		local text = myClass and string.format(L("Playing %s"), Title(myClass)) or L("Your class isn't known yet");
		if ( db.hidden ) then
			sub:SetText(string.format(L("%s. Every telegraph is hidden: Show all brings them back."), text));
			sub:SetTextColor(1, 0.6, 0.2);
		else
			sub:SetText(text);
			sub:SetTextColor(0.6, 0.6, 0.65);
		end
	end);
end

local function Build()
	local db = AST.State();
	db.ui = db.ui or {};
	db.ui.sel = db.ui.sel or {};
	win = CreateFrame("Frame", "ASTOptions", UIParent);
	win:SetWidth(W);
	win:SetHeight(H);
	win:SetFrameStrata("DIALOG");
	win:SetBackdrop(BACKDROP);
	win:SetBackdropColor(0.05, 0.05, 0.07, 0.96);
	win:SetBackdropBorderColor(0.5, 0.5, 0.6, 1);
	win:EnableMouse(true);
	win:SetMovable(true);
	win:RegisterForDrag("LeftButton");
	win:SetScript("OnDragStart", function() win:StartMoving(); end);
	win:SetScript("OnDragStop", function()
		win:StopMovingOrSizing();
		local point, _, rel, x, y = win:GetPoint();
		AST.State().pos = { point = point, rel = rel, x = x, y = y };
	end);
	if ( db.pos and db.pos.point ) then
		win:SetPoint(db.pos.point, UIParent, db.pos.rel or db.pos.point, db.pos.x, db.pos.y);
	else
		win:SetPoint("CENTER", UIParent, "CENTER", 0, 30);
	end
	if ( UISpecialFrames ) then
		table.insert(UISpecialFrames, "ASTOptions");
	end
	win:SetScript("OnShow", function() AST.OptionsShown(true); end);
	win:SetScript("OnHide", function() AST.OptionsShown(false); end);
	AST.OnTop("ASTOptions", true);
	BuildHeader();
	BuildNav();
	BuildList();
	BuildPanel();
	BuildGeneral();
	BuildAll();
	BuildHero();
	BuildTarget();
	-- the texts that change on their own, four times a second
	local acc = 0;
	win:SetScript("OnUpdate", function()
		acc = acc + (arg1 or 0);
		if ( acc < 0.25 ) then
			return;
		end
		acc = 0;
		-- the game's language changed: every text in the new one
		if ( AST_Language() ~= ui.lang ) then
			ui.lang = AST_Language();
			Retranslate();
			if ( page ) then
				ShowPage(page);
			end
		end
		local live = ( page == "general" and ui.general.live ) or ( page == "all" and ui.all.live )
			or ( page == "bars" and ( ui.barsTab == "target" and ui.target.live or ui.hero.live ) ) or (selected and ui.panel.live) or {};
		for i = 1, table.getn(live) do
			live[i]();
		end
		if ( page ~= "general" and page ~= "all" and page ~= "bars" and ui.paint ) then
			ui.paint();
		end
	end);
	ui.lang = AST_Language();
end

-- Shows page `p`: General, or a page of telegraphs with the one chosen there last selected.
ShowPage = function(p)
	local db, _, myClass = AST.State();
	-- (the hero bar's and the target bar's pages are one now, Bars: either of the old names opens it
	-- on that bar)
	if ( p == "hero" or p == "target" ) then
		ui.barsTab, p = p, "bars";
	end
	page = p;
	db.ui.page = p;
	if ( p == "general" or p == "all" or p == "bars" ) then
		ui.list:Hide();
		ui.panel:Hide();
		ui.hero:Hide();
		ui.target:Hide();
		if ( p == "bars" and ui.barsTab == "target" ) then
			ui.general:Hide();
			ui.all:Hide();
			ui.target:Show();
			ui.target.offset = 0;
			ui.pageIcon:SetTexture(ICONS.target);
			ui.pageTitle:SetText(L("Target bar"));
			ui.pageSub:SetText(L("The enemy you target: its health, name, debuffs and buffs on a bar of their own."));
		elseif ( p == "bars" ) then
			ui.general:Hide();
			ui.all:Hide();
			ui.hero:Show();
			ui.hero.offset = 0;
			ui.pageIcon:SetTexture(ICONS.hero);
			ui.pageTitle:SetText(L("Hero bar"));
			ui.pageSub:SetText(L("Your health, shields, mana and icons on a bar of their own."));
		elseif ( p == "general" ) then
			ui.all:Hide();
			ui.general:Show();
			ui.pageIcon:SetTexture(ICONS.general);
			ui.pageTitle:SetText(L("General"));
			ui.pageSub:SetText(L("Settings for the addon as a whole."));
		else
			ui.general:Hide();
			ui.all:Show();
			ui.all.offset = 0;
			ui.pageIcon:SetTexture(ICONS.addon);
			ui.pageTitle:SetText(L("All telegraphs"));
			ui.pageSub:SetText(L("Change many at once; then set any one differently on its own page."));
		end
		ui.pageTitle:SetTextColor(1, 0.82, 0);
		ui.pageNote:SetText("");
		selected = nil;
	else
		ui.general:Hide();
		ui.all:Hide();
		ui.hero:Hide();
		ui.target:Hide();
		ui.list:Show();
		ui.panel:Show();
		local r = AST.registry[p] or {};
		local defs = PageDefs(p);
		local c = ( p == "common" and { 1, 0.82, 0 } ) or ( p == "lab" and { 0.75, 0.55, 1 } ) or ClassColor(p);
		ui.pageIcon:SetTexture(p == "common" and ICONS.common or (r.icon or ICONS.class));
		ui.pageTitle:SetText(( p == "common" and L("Any class") ) or ( p == "lab" and "Lab" ) or Title(p));
		ui.pageTitle:SetTextColor(c[1], c[2], c[3]);
		local sub = r.blurb and L(r.blurb) or string.format(L("%d telegraphs."), table.getn(defs));
		if ( p ~= "common" and p == myClass ) then
			sub = sub .. " " .. L("You're playing this class.");
		elseif ( p ~= "common" and p ~= "lab" ) then
			sub = sub .. " " .. string.format(L("They show when you play %s."), Title(p));
		end
		ui.pageSub:SetText(sub);
		local skipped = 0;
		for i = 1, table.getn(defs) do
			if ( (p == "common" or p == myClass) and Skipped(defs[i]) ) then
				skipped = skipped + 1;
			end
		end
		ui.pageNote:SetText(skipped > 0 and string.format(
			L("Priest Telegraphs is running and draws %d of these. Turn one of the two off at the AddOns screen."), skipped) or "");
		Populate();
		local want = db.ui.sel[p];
		selected = defs[1];
		for i = 1, table.getn(defs) do
			if ( defs[i].id == want ) then
				selected = defs[i];
			end
		end
		if ( selected ) then
			Layout(ui.panel);
		end
	end
	Refresh();
	local live = ( p == "general" and ui.general.live ) or ( p == "all" and ui.all.live )
		or ( p == "bars" and ( ui.barsTab == "target" and ui.target.live or ui.hero.live ) ) or (selected and ui.panel.live) or {};
	for i = 1, table.getn(live) do
		live[i]();
	end
end

---------------------------------------------------------------------------------------------
-- Import / Export: telegraph setups as a line of text (Share.lua)

local share;            -- its window, made the first time it opens

-- "Paladin 12, Any class 6": the pages a line holds, how many telegraphs of each
local function SharePages(res)
	local list, out = AST.SharePages(res), {};
	for i = 1, table.getn(list) do
		local p = list[i][1];
		table.insert(out, (p == "common" and L("Any class") or Title(p)) .. " " .. list[i][2]);
	end
	return table.concat(out, ", ");
end

local function BuildShare()
	share = CreateFrame("Frame", "ASTShare", UIParent);
	share:SetWidth(540);
	share:SetHeight(360);
	share:SetFrameStrata("FULLSCREEN_DIALOG");
	share:SetBackdrop(BACKDROP);
	share:SetBackdropColor(0.05, 0.05, 0.07, 0.97);
	share:SetBackdropBorderColor(0.5, 0.5, 0.6, 1);
	share:SetPoint("CENTER", UIParent, "CENTER", 0, 40);
	share:EnableMouse(true);
	share:SetMovable(true);
	share:RegisterForDrag("LeftButton");
	share:SetScript("OnDragStart", function() share:StartMoving(); end);
	share:SetScript("OnDragStop", function() share:StopMovingOrSizing(); end);
	if ( UISpecialFrames ) then
		table.insert(UISpecialFrames, "ASTShare");
	end
	AST.OnTop("ASTShare", true);
	local title = Label(share, "Import / Export", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", share, "TOPLEFT", 16, -14);
	local close = Button(share, "x", 22, 22, function() share:Hide(); end);
	close:SetPoint("TOPRIGHT", share, "TOPRIGHT", -10, -10);
	local help = Label(share, "Export makes a line to share. To use someone else's, paste it in the box (Ctrl+V) and press Import: only the telegraphs it holds change, so lines can be mixed.");
	help:SetTextColor(0.7, 0.7, 0.75);
	help:SetPoint("TOPLEFT", share, "TOPLEFT", 16, -40);
	help:SetPoint("RIGHT", share, "RIGHT", -16, 0);
	help:SetJustifyH("LEFT");
	help:SetJustifyV("TOP");
	help:SetHeight(28);

	-- the box, in a dark field that scrolls; a click anywhere in the field types in it
	local field = Box(share);
	field:SetPoint("TOPLEFT", share, "TOPLEFT", 14, -104);
	field:SetPoint("BOTTOMRIGHT", share, "BOTTOMRIGHT", -14, 72);
	local made, scroll = pcall(CreateFrame, "ScrollFrame", "ASTShareScroll", field, "UIPanelScrollFrameTemplate");
	if ( not made ) then
		scroll = CreateFrame("ScrollFrame", "ASTShareScroll", field);
	end
	scroll:SetPoint("TOPLEFT", field, "TOPLEFT", 8, -8);
	scroll:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", -28, 8);
	local box = CreateFrame("EditBox", "ASTShareBox", scroll);
	box:SetMultiLine(true);
	box:SetAutoFocus(false);
	box:SetMaxLetters(0);
	box:SetFontObject(GameFontHighlightSmall);
	box:SetWidth(470);
	box:SetHeight(180);
	box:SetScript("OnEscapePressed", function() box:ClearFocus(); end);
	scroll:SetScrollChild(box);
	field:EnableMouse(true);
	field:SetScript("OnMouseDown", function() box:SetFocus(); end);

	local status = Label(share, "");
	status:SetPoint("BOTTOMLEFT", share, "BOTTOMLEFT", 16, 46);
	status:SetPoint("RIGHT", share, "RIGHT", -16, 0);
	status:SetJustifyH("LEFT");
	local function Say(text, r, g, b)
		status:SetText(text);
		status:SetTextColor(r or 0.55, g or 0.8, b or 1);
	end
	-- what a line holds, or why it can't be used
	local function Holds(res, done)
		local left = res.unknown > 0 and (" " .. string.format(L("%d from another version of the addon are left out."), res.unknown)) or "";
		if ( res.err == "cut" ) then
			Say(L("This line is cut short: copy all of it again."), 1, 0.6, 0.2);
		elseif ( res.err ) then
			Say(L("Not a telegraph line: copy it again from its start (AST1:...)."), 1, 0.6, 0.2);
		elseif ( done ) then
			Say(string.format(L("Imported %d telegraphs (%s)."), res.count, SharePages(res)) .. left, 0.4, 1, 0.5);
		else
			Say(string.format(L("Holds %d telegraphs (%s). Import replaces their settings."), res.count, SharePages(res)) .. left);
		end
	end

	local own;   -- the line just exported, which needs no reading back
	local function Export(scope)
		local line, n = AST.Export(scope);
		own = line;
		box:SetText(line);
		box:HighlightText();
		box:SetFocus();
		Say(string.format(L("%d telegraphs (%s). Press Ctrl+C to copy it."), n, SharePages(AST.Import(line))));
	end
	box:SetScript("OnTextChanged", function()
		if ( scroll.UpdateScrollChildRect ) then
			scroll:UpdateScrollChildRect();
		end
		local text = box:GetText() or "";
		if ( text == own ) then
			return;
		end
		own = nil;
		if ( string.gsub(text, "%s", "") == "" ) then
			Say("");
		else
			Holds(AST.Import(text));
		end
	end);

	local all = Button(share, "Export every class", 120, 22, function() Export("all"); end);
	all:SetPoint("TOPLEFT", share, "TOPLEFT", 14, -72);
	share.this = Button(share, "", 120, 22, function() Export(page); end);
	share.this:SetPoint("LEFT", all, "RIGHT", 6, 0);
	local import = Button(share, "Import", 90, 22, function()
		local res = AST.Import(box:GetText(), true);
		Holds(res, true);
		if ( not res.err ) then
			Refresh();
		end
	end);
	import:SetPoint("BOTTOMLEFT", share, "BOTTOMLEFT", 14, 14);
	local clear = Button(share, "Clear", 70, 22, function()
		box:SetText("");
		box:SetFocus();
	end);
	clear:SetPoint("LEFT", import, "RIGHT", 6, 0);
end

-- Opens Import / Export, its second export button for the page shown (none on General).
function AST.OpenShare()
	if ( not share ) then
		BuildShare();
	end
	local b = share.this;
	if ( page and page ~= "general" and AST.registry[page] ) then
		b.text:SetText(string.format(L("Export %s"), page == "common" and L("Any class") or Title(page)));
		b:SetWidth(math.max(120, (b.text.GetStringWidth and b.text:GetStringWidth() or 0) + 16));
		b:Show();
	else
		b:Hide();
	end
	share:Show();
end

-- The page to open on: your class's, else (your class not known yet) the last one shown, else
-- Any class.
local function StartPage()
	local db, _, myClass = AST.State();
	local p = db.ui.page;
	if ( myClass and AST.registry[myClass] ) then
		return myClass;
	elseif ( p == "general" or ( p and AST.registry[p] ) ) then
		return p;
	end
	return "common";
end

function AST.ToggleOptions()
	local _, _, myClass = AST.State();
	if ( not myClass ) then
		AST.SetupClass();
	end
	if ( not win ) then
		Build();
		win:Show();
		-- a new frame is shown from the start, so its OnShow didn't come
		AST.OptionsShown(true);
		ShowPage(StartPage());
	elseif ( win:IsShown() ) then
		win:Hide();
	else
		-- a question left open when the window closed isn't asked again
		if ( ui.confirm ) then
			ui.confirm:Hide();
		end
		win:Show();
		-- the page you had open, while this game runs (only a new game starts on your class)
		ShowPage(page or StartPage());
	end
end

-- After a change from outside the window (the minimap button, a slash command).
function AST.RefreshOptions()
	if ( win ) then
		Refresh();
	end
end

-- A run with a hero of another class: the window turns to that class's page.
function AST.ClassChanged(class)
	if ( not win ) then
		return;
	end
	local db = AST.State();
	if ( AST.registry[class] ) then
		db.ui.page = class;
	end
	if ( win:IsShown() ) then
		ShowPage(db.ui.page or StartPage());
	end
end

---------------------------------------------------------------------------------------------
-- Over the game's own screens: the window and Import / Export are kept over the level-up and
-- jewelry cards (AZS_SetOnTopOfScreens), so the telegraphs can be set up while choosing.

-- Keeps the frame called `name` over the game's screens (or not), where the game can.
function AST.OnTop(name, on)
	if ( type(AZS_SetOnTopOfScreens) == "function" ) then
		pcall(AZS_SetOnTopOfScreens, name, on);
	end
end

-- While the window is open, the tooltip and the colour picker it uses are kept over them too. The
-- game keeps one flag a name, shared by every addon (SurvivorUI keeps the tooltip over the cards for
-- its own pieces): only one the window raised itself is put back under as it closes.
AST.raised = {};
function AST.OptionsShown(shown)
	local names = { "GameTooltip", "ColorPickerFrame" };
	for i = 1, 2 do
		local name = names[i];
		if ( shown ) then
			local up = false;
			if ( type(AZS_IsOnTopOfScreens) == "function" ) then
				local ok, on = pcall(AZS_IsOnTopOfScreens, name);
				up = ok and on and true or false;
			end
			if ( not AST.raised[name] and not up ) then
				AST.OnTop(name, true);
				AST.raised[name] = true;
			end
		elseif ( AST.raised[name] ) then
			AST.raised[name] = nil;
			AST.OnTop(name, false);
		end
	end
end
