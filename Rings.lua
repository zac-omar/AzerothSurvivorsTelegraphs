-- Azeroth Survivors Telegraphs: rings of your own, as many as you like, on any class's page (shown
-- while you play that class) or on Any class (shown always). Each is a telegraph like the others,
-- its settings kept by its id; which there are is kept in ASTelegraphsDB.rings, { id, page, n }
-- each (n: its number on its page, for its name).

-- A new ring's colour: one after another from these, so rings side by side tell apart.
local COLORS = { { 1, 0.25, 0.25 }, { 1, 0.82, 0.2 }, { 0.3, 0.85, 1 }, { 0.4, 1, 0.45 }, { 0.75, 0.5, 1 }, { 1, 1, 1 } };

local function RingDef(entry)
	local k = entry.n - 1;
	local c = COLORS[k - math.floor(k / table.getn(COLORS)) * table.getn(COLORS) + 1];
	return {
		id = entry.id, name = "Custom ring", custom = entry.n, shape = "circle", kind = "Other",
		desc = "A ring of any size around you, for whatever you want to keep an eye on.",
		defaults = { mode = "always", radius = 10, line = { c[1], c[2], c[3], 1 }, fill = { c[1], c[2], c[3], 0 } },
	};
end

local function List()
	local db = AST.State();
	db.rings = db.rings or {};
	return db.rings, db;
end

-- The saved rings into their pages (Core calls this once the settings have loaded).
function AST.LoadRings()
	local rings = List();
	for i = 1, table.getn(rings) do
		local e = rings[i];
		if ( type(e) == "table" and e.id and AST.registry[e.page] ) then
			AST_Register(e.page, { RingDef(e) });
		end
	end
end

-- Whether a telegraph id is one of these (as a share line has it).
function AST.IsRingId(id)
	return string.find(id or "", "^cring[0-9]+$") ~= nil;
end

-- A new ring on page `page` ("common" or a class): its telegraph, on and drawn at once.
function AST.AddRing(page)
	local rings, db = List();
	if ( not AST.registry[page] ) then
		return nil;
	end
	-- its number on the page: after the others there (Any class has the first custom ring already)
	local n = page == "common" and 1 or 0;
	for i = 1, table.getn(rings) do
		if ( rings[i].page == page and rings[i].n > n ) then
			n = rings[i].n;
		end
	end
	-- an id no telegraph has
	local taken = {};
	for _, r in pairs(AST.registry) do
		for i = 1, table.getn(r.defs) do
			taken[r.defs[i].id] = true;
		end
	end
	local id;
	repeat
		db.ringNext = (db.ringNext or 0) + 1;
		id = "cring" .. db.ringNext;
	until ( not taken[id] and not db.t[id] )
	local entry = { id = id, page = page, n = n + 1 };
	table.insert(rings, entry);
	local def = RingDef(entry);
	AST_Register(page, { def });
	AST.SetupClass();
	return def;
end

-- Takes ring `def` away, its settings too.
function AST.RemoveRing(def)
	local rings, db = List();
	local r = AST.registry[def.group];
	for i = table.getn(r and r.defs or {}), 1, -1 do
		if ( r.defs[i] == def ) then
			table.remove(r.defs, i);
		end
	end
	for i = table.getn(rings), 1, -1 do
		if ( rings[i].id == def.id ) then
			table.remove(rings, i);
		end
	end
	db.t[def.id] = nil;
	AST.SetupClass();
end
