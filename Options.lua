-- The options window. Its pages are tabs down the left side: General (what isn't one
-- telegraph's), one per class that has telegraphs, yours first, and Amulets (the telegraphs any
-- hero can use). A telegraph page lists its telegraphs by kind, with the chosen one's settings
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
local KINDS = { "Spells", "Talents", "Amulets", "Sets", "Other", "Experimental" };
local ICONS = {
	general = "Interface\\Icons\\INV_Misc_Gear_01",
	common = "Interface\\Icons\\INV_Misc_Gem_01",
	class = "Interface\\Icons\\INV_Misc_QuestionMark",
	addon = "Interface\\Icons\\Spell_Holy_HolyNova",
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
	if ( page ~= "common" and page ~= myClass ) then
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
	t:SetTexture(SOLID);
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
	row.when = when;
	table.insert(panel.rows, row);
	return row;
end

-- A heading over the rows after it, hidden when they all are.
local function Section(panel, title)
	local row = CreateFrame("Frame", nil, panel);
	row.height, row.section = 26, true;
	row:SetHeight(row.height);
	local text = Label(row, title, "GameFontNormalSmall", true);
	text:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 6);
	local rule = Rule(row, 0.15);
	rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2);
	rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2);
	table.insert(panel.rows, row);
	return row;
end

-- Places a panel's rows from panel.top down.
local function Layout(panel)
	local rows, shown = panel.rows, {};
	for i = 1, table.getn(rows) do
		shown[i] = rows[i].section or not rows[i].when or rows[i].when(selected);
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
	local y = panel.top;
	for i = 1, table.getn(rows) do
		local row = rows[i];
		if ( shown[i] ) then
			row:ClearAllPoints();
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y);
			row:SetPoint("RIGHT", panel, "RIGHT", -14, 0);
			row:Show();
			y = y - row.height - 2;
		else
			row:Hide();
		end
	end
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
	mark:SetTexture(SOLID);
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
	for i = 1, 3 do
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
		for i = 1, 3 do
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

-- A number with - and + (shift: five steps), the mouse wheel over the row too.
local function Stepper(panel, label, when, get, set, step, lo, hi, fmt)
	local row = Row(panel, label, when);
	local value = Label(row, "");
	local function Nudge(n)
		if ( IsShiftKeyDown and IsShiftKeyDown() ) then
			n = n * 5;
		end
		local v = math.floor((get() + n * step) / step + 0.5) * step;
		set(math.max(lo, math.min(hi, v)));
		Refresh();
	end
	local minus = Button(row, "-", 20, 18, function() Nudge(-1); end);
	minus:SetPoint("LEFT", row, "LEFT", CX, 0);
	value:SetPoint("LEFT", row, "LEFT", CX + 24, 0);
	value:SetWidth(104);
	local plus = Button(row, "+", 20, 18, function() Nudge(1); end);
	plus:SetPoint("LEFT", row, "LEFT", CX + 132, 0);
	row:EnableMouseWheel(true);
	row:SetScript("OnMouseWheel", function()
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
local function Color(panel, label, when, key)
	local row = Row(panel, label, when);
	local swatch = row:CreateTexture(nil, "OVERLAY");
	swatch:SetTexture(SOLID);
	swatch:SetWidth(18);
	swatch:SetHeight(18);
	swatch:SetPoint("LEFT", row, "LEFT", CX, 0);
	local function SetRGB(r, g, b)
		local c = AST.Settings(selected)[key];
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
		t:SetTexture(SOLID);
		t:SetVertexColor(pc[1], pc[2], pc[3], 1);
		t:SetAllPoints(b);
		b:SetScript("OnClick", function() SetRGB(pc[1], pc[2], pc[3]); end);
		x = x + 17;
	end
	if ( ColorPickerFrame ) then
		local pick = Button(row, "Pick", 40, 18, function()
			local c = AST.Settings(selected)[key];
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
		local c = AST.Settings(selected)[key];
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
	b.bar:SetTexture(SOLID);
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
		if ( class ~= "common" and class ~= myClass ) then
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
	Tab("common", ICONS.common, "Amulets");
	ui.classHead = Label(ui.nav, "Classes", "GameFontNormalSmall", true);
	for class, r in pairs(AST.registry) do
		if ( class ~= "common" ) then
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
		-- General, the classes under their heading, then Amulets
		local y = -6;
		byPage.general:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y);
		ui.classHead:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 12, y - 40);
		y = y - 56;
		local classes = ClassOrder();
		for i = 1, table.getn(classes) do
			local b = byPage[classes[i]];
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y);
			y = y - 30;
		end
		byPage.common:ClearAllPoints();
		byPage.common:SetPoint("TOPLEFT", ui.nav, "TOPLEFT", 6, y - 10);
	end);
end

---------------------------------------------------------------------------------------------
-- A telegraph page: its heading, its list, the chosen telegraph's settings

local function Select(def)
	local db = AST.State();
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
	e.chip:SetTexture(SOLID);
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
	e.dot.mark:SetTexture(AST.round);
	e.dot.mark:SetWidth(9);
	e.dot.mark:SetHeight(9);
	e.dot.mark:SetPoint("CENTER", e.dot, "CENTER", 0, 0);
	e.dot:SetScript("OnClick", function()
		if ( not e.def ) then
			return;
		end
		local s = AST.Settings(e.def);
		s.enabled = not s.enabled;
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
		local item = ui.items[i];
		if ( y <= 0 and y - item.height >= -(BODY_H - 6) ) then
			item:ClearAllPoints();
			item:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 8, y);
			item:Show();
		else
			item:Hide();
		end
		y = y - item.height;
		total = total + item.height;
	end
	ui.listH = total;
end

-- Fills the list with the page's telegraphs, under their kinds' headings.
local function Populate()
	local defs = PageDefs(page);
	local nE, nH = 0, 0;
	ui.items = {};
	for k = 1, table.getn(KINDS) do
		local first = true;
		for i = 1, table.getn(defs) do
			if ( Kind(defs[i]) == KINDS[k] ) then
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
				ui.entries[nE].text:SetText(L(defs[i].name));
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
	-- a long list scrolls with the mouse wheel
	ui.list:EnableMouseWheel(true);
	ui.list:SetScript("OnMouseWheel", function()
		local most = math.max(0, (ui.listH or 0) - (BODY_H - 12));
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
local function Px(v) return string.format(L("%g px"), v); end
local function Yd(v) return string.format(L("%g yd"), v); end

-- The settings rows, the ones that don't fit what the telegraph is or how it is drawn hidden.
local function SettingRows(panel)
	local function S() return AST.Settings(selected); end
	local function Dotty() return S().style == "dots"; end
	local function Filling() return S().mode == "cooldown"; end
	local function Sized(d) return d.sizePattern ~= nil or d.radius ~= nil or d.radii ~= nil or d.sizeOf ~= nil; end

	Section(panel, "Behaviour");
	Choice(panel, "When", function(d) return d.modes ~= nil; end, ModeChoices,
		function() return S().mode; end, function(v) S().mode = v; end);
	Stepper(panel, "Flash length", function()
			local m = S().mode;
			return m == "cast" or m == "event" or m == "shield" or m == "proc";
		end,
		function() return S().flash; end, function(v) S().flash = v; end, 0.1, 0.1, 5,
		function(v) return string.format(L("%.1f sec"), v); end);
	-- fewer rings when a pack dies at once, for slower computers
	Stepper(panel, "Most at once", function(d) return d.shape == "enemy"; end,
		function() return S().most; end, function(v) S().most = v; end, 1, 0, 40,
		function(v) return v <= 0 and L("no limit") or string.format(L("%d rings"), v); end);

	Section(panel, "Size");
	Stepper(panel, "Size override", Sized,
		function() return S().length; end, function(v) S().length = v; end, 0.5, 0, 100,
		function(v) return v <= 0 and L("off (automatic)") or Yd(v); end);
	Stepper(panel, "Radius", function(d) return not Sized(d); end,
		function() return S().radius; end, function(v) S().radius = v; end, 0.5, 0.5, 100, Yd);

	Section(panel, "Appearance");
	Choice(panel, "Style", nil, { { "smooth", "Smooth", 80 }, { "dots", "Dots", 60 } },
		function() return S().style; end, function(v) S().style = v; end);
	Color(panel, "Outline colour", nil, "line");
	Stepper(panel, "Outline opacity", nil, function() return S().line[4]; end, function(v) S().line[4] = v; end,
		0.05, 0, 1, Pct);
	Color(panel, "Fill colour", nil, "fill");
	Stepper(panel, "Fill opacity", nil, function() return S().fill[4]; end, function(v) S().fill[4] = v; end,
		0.05, 0, 1, Pct);
	Stepper(panel, "Outline width", function() return not Dotty(); end, function() return S().width; end,
		function(v) S().width = v; end, 1, 1, 12, Px);
	Check(panel, "Glow", function() return not Dotty(); end, function() return S().glow; end,
		function(v) S().glow = v; end);
	Stepper(panel, "Fill detail", function() return not Dotty(); end, function() return S().strip; end,
		function(v) S().strip = v; end, 1, 1, 8, function(v) return string.format(L("%g px strips"), v); end);
	Stepper(panel, "Dot size", Dotty, function() return S().size; end, function(v) S().size = v; end, 1, 1, 16, Px);
	Stepper(panel, "Dot spacing", Dotty, function() return S().spacing; end, function(v) S().spacing = v; end,
		1, 3, 40, Px);
	Choice(panel, "Fill style", function() return Dotty() and Filling(); end,
		{ { "solid", "Solid", 70 }, { "front", "Front line only", 110 } },
		function() return S().fillStyle; end, function(v) S().fillStyle = v; end);
	Stepper(panel, "Fill spacing", function() return Dotty() and Filling() and S().fillStyle == "solid"; end,
		function() return S().fillSpacing; end, function(v) S().fillSpacing = v; end, 1, 4, 60, Px);
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
		ui.name:SetText(L(selected.name));
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

	-- Test hides this window while it plays, as the window sits over your hero.
	local reopenAt;
	local reopener = CreateFrame("Frame");
	reopener:SetScript("OnUpdate", function()
		if ( reopenAt and GetTime() >= reopenAt ) then
			reopenAt = nil;
			win:Show();
		end
	end);
	local test = Button(panel, "Test", 80, 22, function()
		AST.preview[selected.id] = GetTime() + 3;
		reopenAt = GetTime() + 3.2;
		win:Hide();
	end);
	test:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10);
	local reset = Button(panel, "Reset to defaults", 120, 22, function()
		AST.ResetSettings(selected);
		Refresh();
	end);
	reset:SetPoint("LEFT", test, "RIGHT", 6, 0);
	local hint = Label(panel, "Test shows it for 3 seconds.");
	hint:SetTextColor(0.5, 0.5, 0.55);
	hint:SetPoint("LEFT", reset, "RIGHT", 10, 0);
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

	Section(g, "Commands");
	Text(g, "/ast", nil, function() return L("opens this window"); end);
	Text(g, "/ast ring 10", nil, function() return L("a 10 yd custom ring around you (/ast ring turns it on or off)"); end);
	Text(g, "/ast debug", nil, function() return L("what the addon reads, for when a telegraph doesn't show"); end);
	Text(g, "/ast meter", nil, function() return L("your talents as the meter lists them"); end);
	Text(g, "/ast share", nil, function() return L("import or export telegraph setups"); end);
	Layout(g);
end

---------------------------------------------------------------------------------------------
-- The window

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
		local live = page == "general" and ui.general.live or (selected and ui.panel.live) or {};
		for i = 1, table.getn(live) do
			live[i]();
		end
		if ( page ~= "general" and ui.paint ) then
			ui.paint();
		end
	end);
	ui.lang = AST_Language();
end

-- Shows page `p`: General, or a page of telegraphs with the one chosen there last selected.
ShowPage = function(p)
	local db, _, myClass = AST.State();
	page = p;
	db.ui.page = p;
	if ( p == "general" ) then
		ui.list:Hide();
		ui.panel:Hide();
		ui.general:Show();
		ui.pageIcon:SetTexture(ICONS.general);
		ui.pageTitle:SetText(L("General"));
		ui.pageTitle:SetTextColor(1, 0.82, 0);
		ui.pageSub:SetText(L("Settings for the addon as a whole."));
		ui.pageNote:SetText("");
		selected = nil;
	else
		ui.general:Hide();
		ui.list:Show();
		ui.panel:Show();
		local r = AST.registry[p] or {};
		local defs = PageDefs(p);
		local c = p == "common" and { 1, 0.82, 0 } or ClassColor(p);
		ui.pageIcon:SetTexture(p == "common" and ICONS.common or (r.icon or ICONS.class));
		ui.pageTitle:SetText(p == "common" and L("Amulets") or Title(p));
		ui.pageTitle:SetTextColor(c[1], c[2], c[3]);
		local sub = r.blurb and L(r.blurb) or string.format(L("%d telegraphs."), table.getn(defs));
		if ( p ~= "common" and p == myClass ) then
			sub = sub .. " " .. L("You're playing this class.");
		elseif ( p ~= "common" ) then
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
	local live = p == "general" and ui.general.live or (selected and ui.panel.live) or {};
	for i = 1, table.getn(live) do
		live[i]();
	end
end

---------------------------------------------------------------------------------------------
-- Import / Export: telegraph setups as a line of text (Share.lua)

local share;            -- its window, made the first time it opens

-- "Paladin 12, Amulets 4": the pages a line holds, how many telegraphs of each
local function SharePages(res)
	local list, out = AST.SharePages(res), {};
	for i = 1, table.getn(list) do
		local p = list[i][1];
		table.insert(out, (p == "common" and L("Amulets") or Title(p)) .. " " .. list[i][2]);
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
		b.text:SetText(string.format(L("Export %s"), page == "common" and L("Amulets") or Title(page)));
		b:SetWidth(math.max(120, (b.text.GetStringWidth and b.text:GetStringWidth() or 0) + 16));
		b:Show();
	else
		b:Hide();
	end
	share:Show();
end

-- The page to open on: your class's, else (your class not known yet) the last one shown, else
-- Amulets.
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
		win:Show();
		ShowPage(StartPage());
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

-- While the window is open, the tooltip and the colour picker it uses are kept over them too.
function AST.OptionsShown(shown)
	AST.OnTop("GameTooltip", shown);
	AST.OnTop("ColorPickerFrame", shown);
end
