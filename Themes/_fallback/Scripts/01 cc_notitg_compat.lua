-- CC fork: NotITG compatibility layer (Phase 1).
-- Real implementations where ITGmania already has an equivalent; logged no-op
-- stubs for NotITG-only engine features until Phase 2/3 adds them in C++.

FUCK_EXE = true            -- NotITG's "running in NotITG" flag
CC_NOTITG_COMPAT = 1

-- Lua 5.0 leftovers not covered by ITGmania's Lua 5.1 compat flags
if not table.getn then table.getn = function(t) return #t end end
if not table.setn then table.setn = function() end end
if not string.gfind then string.gfind = string.gmatch end
if not math.mod then math.mod = math.fmod end

local seen = {}
local function note(cls, name)
	local k = cls .. ":" .. name
	if not seen[k] then
		seen[k] = true
		Trace("CC-NOTITG-STUB: " .. k)
	end
end

-- Null object: any method call returns itself, so chained calls don't crash.
CCNull = setmetatable({}, {
	__index = function(t) return function() return t end end,
	__tostring = function() return "CCNull" end,
})

local function stub_for(cls, name)
	return function(self, ...)
		note(cls, name)
		if name:find("^Is") or name:find("^Has") then return false end
		if name:find("^Get") then return CCNull end
		return self
	end
end

local function install_fallback(clsname)
	local cls = _G[clsname]
	if type(cls) ~= "table" then return end
	local gm = (debug and debug.getmetatable) or getmetatable
	local mt = gm(cls)
	if type(mt) ~= "table" then
		if mt ~= nil then Trace("CC-NOTITG: can't hook " .. clsname); return end
		mt = {}; setmetatable(cls, mt)
	end
	if mt.__index ~= nil then return end -- derived class; root handles it
	mt.__index = function(_, name)
		if type(name) == "string" and CCNotITGNames and CCNotITGNames[name] then
			return stub_for(clsname, name)
		end
		return nil
	end
end

for _, c in ipairs({ "Actor", "GameState", "PlayerState", "ScreenManager",
	"SongManager", "PrefsManager", "ThemeManager", "Song", "Steps",
	"NoteSkinManager", "MessageManager", "RageDisplay", "RageTexture",
	"PlayerOptions", "SongOptions", "StatsManager", "Profile", "ProfileManager",
	"CharacterManager", "UnlockManager", "AnnouncerManager", "InputFilter" }) do
	install_fallback(c)
end

-- Real mappings -----------------------------------------------------------
if GameState then
	-- NotITG: GAMESTATE:ApplyModifiers("*1 50 drunk", pn)  (pn optional)
	GameState.ApplyModifiers = function(self, mods, pn)
		if not mods or mods == "" then return end
		if pn == nil then
			for _, p in ipairs(GAMESTATE:GetEnabledPlayers()) do
				self:ApplyGameCommand("mod," .. mods, p)
			end
		else
			if type(pn) == "number" then pn = PlayerNumber[pn + 1] end
			self:ApplyGameCommand("mod," .. mods, pn)
		end
	end
	GameState.GetVersionDate = function() return "20241010" end
	GameState.GetVersion = function() return "v4.9.1" end
end

if Actor then
	-- Shader stub: modfiles call self:GetShader():uniform1f(...) etc.
	Actor.GetShader = function(self) note("Actor", "GetShader"); return CCNull end
	Actor.SetShader = function(self) note("Actor", "SetShader"); return self end
	Actor.ClearShader = function(self) return self end
end

if Player then
	Player.IsAwake = function() return true end
	Player.SetAwake = function(self) return self end
end

-- Per-frame hooks (driven from ScreenSystemLayer aux.lua) ------------------
CCFrameHooks = {}
function CCAddFrameHook(fn, duration, owner)
	table.insert(CCFrameHooks, { fn = fn, left = duration or math.huge, owner = owner })
end
function CCKillFrameHooks(owner)
	for _, h in ipairs(CCFrameHooks) do if h.owner == owner then h.dead = true end end
end
function CCRunFrameHooks(dt)
	for i = #CCFrameHooks, 1, -1 do
		local h = CCFrameHooks[i]
		if h.dead then
			table.remove(CCFrameHooks, i)
		else
			local ok, err = pcall(h.fn, dt)
			h.left = h.left - dt
			if not ok then Trace("CC-NOTITG hook error: " .. tostring(err)) end
			if not ok or h.left <= 0 then table.remove(CCFrameHooks, i) end
		end
	end
end

if Actor then
	-- NotITG/OpenITG: tween(time, "luaExpression()") evaluates the expression
	-- every frame for `time` seconds (modfiles use it as their update loop).
	local orig_tween = Actor.tween
	Actor.tween = function(self, t, tt, ...)
		if type(tt) == "string" and tt:find("%(") then
			local f = loadstring("return " .. tt)
			if f then
				CCAddFrameHook(function() f() end, t, self)
				return self:sleep(t)
			end
		end
		return orig_tween(self, t, tt, ...)
	end
	-- NotITG: luaeffect("Name") runs NameCommand every frame until stopeffect.
	Actor.luaeffect = function(self, cmdname)
		CCAddFrameHook(function() self:playcommand(cmdname) end, math.huge, self)
		return self
	end
	local orig_stopeffect = Actor.stopeffect
	Actor.stopeffect = function(self, ...)
		CCKillFrameHooks(self)
		return orig_stopeffect(self, ...)
	end
end
