-- Azeroth Survivors Telegraphs: which language the game is set to, and the words for it.
-- Each language's file (Locales\<code>.lua) holds the game's words in it (spell, talent and amulet
-- names, the tooltip and amulet texts the addon reads its numbers from, as the game shows them)
-- and a translation of the addon's own text. English needs none.

AST_LOCALE = {};

-- The game's language codes (Options > Language in the game).
local CODES = { en = true, pl = true, cs = true, de = true, pt = true, es = true, fr = true, ro = true,
	tr = true, ru = true, uk = true, zh = true, ja = true, ko = true };
local lang, checkedAt = "en", nil;
local cache = {};   -- code -> English pattern or rule -> what to look for in that language

-- The language the game is set to: its azsLanguage setting (the game's meter reads the same),
-- looked at again at most once a second, so a change in the game's options shows at once.
function AST_Language()
	local now = GetTime and GetTime() or 0;
	if ( checkedAt and now - checkedAt < 1 and now >= checkedAt ) then
		return lang;
	end
	checkedAt = now;
	local code;
	if ( GetCVar ) then
		local ok, v = pcall(GetCVar, "azsLanguage");
		code = ok and v or nil;
	end
	if ( not CODES[code or ""] and type(AZS_MLang) == "function" ) then
		local ok, v = pcall(AZS_MLang);
		code = ok and v or nil;
	end
	lang = CODES[code or ""] and code or "en";
	return lang;
end

local function Part(name)
	local t = AST_LOCALE[AST_Language()];
	return t and t[name];
end

-- The addon's own text in the game's language (English when it has no translation); a game
-- name (a spell, a talent, a class) as the game shows it.
function AST_L(s)
	local t, n = Part("ui"), Part("names");
	return (t and s and t[s]) or (n and s and n[s]) or s;
end

-- A spell's, talent's or amulet's name as the game shows it in its language.
function AST_GameName(s)
	local t = Part("names");
	return (t and s and t[s]) or s;
end

-- A name the game showed (normalized) as the addon's English key for it.
function AST_Alias(n)
	local t = Part("alias");
	return (t and n and t[n]) or n;
end

-- What a tooltip or amulet text pattern reads as in the game's language: its forms there, then
-- the English one.
function AST_Patterns(p)
	local code = AST_Language();
	local c = cache[code];
	if ( not c ) then
		c = {};
		cache[code] = c;
	end
	local list = c[p];
	if ( not list ) then
		list = {};
		local t = AST_LOCALE[code] and AST_LOCALE[code].patterns;
		local own = t and t[p];
		for i = 1, table.getn(own or {}) do
			table.insert(list, own[i]);
		end
		table.insert(list, p);
		c[p] = list;
	end
	return list;
end

-- An amulet rule (the text on an item that gives a key) as it reads in the game's language.
function AST_GearRule(r)
	local t = Part("gear");
	return (t and t[r]) or r;
end

-- A number as the game prints it: "9.5", or "9,5".
function AST_Number(v)
	return v and tonumber((string.gsub(v, ",", "."))) or nil;
end
