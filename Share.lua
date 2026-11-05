-- Azeroth Survivors Telegraphs: telegraph setups as a line of text to pass around, a page's (one
-- class's, or Amulets') or every page's at once. Importing a line resets each telegraph it
-- holds to its defaults and then gives it the settings the line has for it, so one class's line
-- changes only that class's telegraphs: lines from several people can be mixed.
--
-- A line: "AST1:<telegraphs>", then per page "#<page>", per telegraph ";<id>" and, when it differs
-- from its defaults, ":<setting>=<value>,..."; it ends with "$". A colour is RRGGBBAA in hex, on
-- and off are 1 and 0. Spaces and line breaks in it are ignored, so a wrapped copy still reads.

local VERSION = "AST1";
local ORDER = { "common", "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" };

-- The settings a line can carry, in the order a line has them, and what each may be: a number
-- within the options window's own limits, one of a few words, a colour, on or off.
local KEYS = { "enabled", "mode", "style", "flash", "most", "length", "radius", "line", "fill", "width", "glow",
	"strip", "size", "spacing", "fillStyle", "fillSpacing" };
local SPEC = {
	enabled = { "bool" }, glow = { "bool" }, mode = { "mode" },
	style = { "word", smooth = true, dots = true }, fillStyle = { "word", solid = true, front = true },
	line = { "color" }, fill = { "color" },
	flash = { "num", 0.1, 5 }, most = { "num", 0, 40 }, length = { "num", 0, 100 }, radius = { "num", 0.5, 100 },
	width = { "num", 1, 12 }, strip = { "num", 1, 8 }, size = { "num", 1, 16 }, spacing = { "num", 3, 40 },
	fillSpacing = { "num", 4, 60 },
};

-- A telegraph's own default for a setting (an experimental one starts off).
local function Default(def, k)
	if ( k == "enabled" and def.experimental ) then
		return false;
	elseif ( def.defaults and def.defaults[k] ~= nil ) then
		return def.defaults[k];
	end
	return AST.common[k];
end

local function Encode(k, v)
	local kind = SPEC[k][1];
	if ( kind == "bool" ) then
		return v and "1" or "0";
	elseif ( kind == "color" ) then
		local out = "";
		for i = 1, 4 do
			local c = type(v) == "table" and tonumber(v[i]) or 1;
			out = out .. string.format("%02x", math.floor(math.max(0, math.min(1, c)) * 255 + 0.5));
		end
		return out;
	end
	return tostring(v);
end

-- A setting's value from a line, or nil when it isn't one it can be.
local function Decode(def, k, v)
	local spec = SPEC[k];
	local kind = spec and spec[1];
	if ( kind == "bool" ) then
		if ( v == "1" or v == "0" ) then
			return v == "1";
		end
		return nil;
	elseif ( kind == "color" ) then
		local _, _, r, g, b, a = string.find(v, "^(%x%x)(%x%x)(%x%x)(%x%x)$");
		return r and { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 } or nil;
	elseif ( kind == "num" ) then
		local n = tonumber(v);
		return n and n == n and math.max(spec[2], math.min(spec[3], n)) or nil;
	elseif ( kind == "word" ) then
		return spec[v] and v or nil;
	elseif ( kind == "mode" ) then
		for i = 1, table.getn(def.modes or {}) do
			if ( def.modes[i] == v ) then
				return v;
			end
		end
		return v == Default(def, "mode") and v or nil;
	end
end

-- The pages a line of `scope` holds: one page, or every page ("all").
local function Pages(scope)
	local out, seen = {}, {};
	for i = 1, table.getn(ORDER) do
		local p = ORDER[i];
		if ( AST.registry[p] and ( scope == "all" or scope == p ) ) then
			table.insert(out, p);
			seen[p] = true;
		end
	end
	for p in pairs(AST.registry) do
		if ( not seen[p] and ( scope == "all" or scope == p ) ) then
			table.insert(out, p);
		end
	end
	return out;
end

-- The line for `scope` ("all", "common" or a class), and how many telegraphs it holds.
function AST.Export(scope)
	local parts, n = {}, 0;
	local pages = Pages(scope);
	for i = 1, table.getn(pages) do
		table.insert(parts, "#" .. pages[i]);
		local defs = AST.registry[pages[i]].defs;
		for j = 1, table.getn(defs) do
			local def, fields = defs[j], {};
			local s = AST.Settings(def);
			for k = 1, table.getn(KEYS) do
				local key = KEYS[k];
				local v = Encode(key, s[key]);
				if ( v ~= Encode(key, Default(def, key)) ) then
					table.insert(fields, key .. "=" .. v);
				end
			end
			table.insert(parts, ";" .. def.id .. ( table.getn(fields) > 0 and ( ":" .. table.concat(fields, ",") ) or "" ));
			n = n + 1;
		end
	end
	return VERSION .. ":" .. n .. table.concat(parts) .. "$", n;
end

-- What a line holds, and with `apply` its settings put in place. Returns { count, pages = { page
-- -> how many }, unknown (telegraphs this version doesn't have), err ("bad": not a line, "cut":
-- not all of one) }.
function AST.Import(text, apply)
	local res = { count = 0, pages = {}, unknown = 0 };
	text = string.gsub(text or "", "%s", "");
	local _, _, want, body = string.find(text, "^" .. VERSION .. ":(%d+)(.-)%$$");
	if ( not want ) then
		res.err = string.find(text, "^" .. VERSION .. ":") and "cut" or "bad";
		return res;
	end
	local byId = {};
	for p, r in pairs(AST.registry) do
		for i = 1, table.getn(r.defs) do
			byId[r.defs[i].id] = r.defs[i];
		end
	end
	local entries, seen, pos = {}, 0, 1;
	while ( true ) do
		local s, e, mark, rest = string.find(body, "([#;])([^#;]*)", pos);
		if ( not s ) then
			break;
		end
		pos = e + 1;
		if ( mark == ";" ) then
			seen = seen + 1;
			local _, _, id, fields = string.find(rest, "^([%w_]+):?(.*)$");
			local def = id and byId[id];
			if ( def ) then
				local entry = { def = def, values = {} };
				local fpos = 1;
				while ( true ) do
					local fs, fe, k, v = string.find(fields, "([%w]+)=([^,]*)", fpos);
					if ( not fs ) then
						break;
					end
					fpos = fe + 1;
					local value = SPEC[k] and Decode(def, k, v);
					if ( value ~= nil ) then
						entry.values[k] = value;
					end
				end
				table.insert(entries, entry);
				res.pages[def.group] = (res.pages[def.group] or 0) + 1;
			else
				res.unknown = res.unknown + 1;
			end
		end
	end
	if ( seen ~= tonumber(want) ) then
		res.err = "cut";
		res.pages = {};
		return res;
	end
	res.count = table.getn(entries);
	if ( apply ) then
		for i = 1, table.getn(entries) do
			local s = AST.ResetSettings(entries[i].def);
			for k, v in pairs(entries[i].values) do
				s[k] = v;
			end
		end
	end
	return res;
end

-- The pages a result holds, in the usual order: { page, how many } each.
function AST.SharePages(res)
	local out, all = {}, Pages("all");
	for i = 1, table.getn(all) do
		if ( res.pages[all[i]] ) then
			table.insert(out, { all[i], res.pages[all[i]] });
		end
	end
	return out;
end
