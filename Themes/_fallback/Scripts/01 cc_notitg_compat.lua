-- CC fork: NotITG compatibility layer (Phase 1).
-- Real implementations where ITGmania already has an equivalent; logged no-op
-- stubs for NotITG-only engine features until Phase 2/3 adds them in C++.

FUCK_EXE = true            -- NotITG's "running in NotITG" flag
CC_NOTITG_COMPAT = 1

-- Lua 5.2-style ports do `local _ENV = _ENV`; in 5.1 make that mean globals.
if _ENV == nil then _ENV = _G end

-- Lua 5.0 leftovers not covered by ITGmania's Lua 5.1 compat flags
-- NotITG keeps Lua 5.0-style explicit sizes: table.insert/remove record the
-- size and `#` honors it (the VM side is in lvm.c, CC fork). Only calls made
-- from song modfiles (/Songs/...) are tracked, so theme code is untouched.
do
	local tinsert, tremove = table.insert, table.remove
	local sizes = setmetatable({}, { __mode = "k" })
	if debug and debug.getregistry then debug.getregistry().CCSizes = sizes end
	local getinfo = debug and debug.getinfo
	local notitg = CCIsNotITGSong
	local function from_modfile()
		-- cheap gate first: only while a NotITG modfile song is loaded
		if not (notitg and notitg()) then return false end
		local info = getinfo and getinfo(3, "S")
		local src = info and info.source or ""
		return src:find("/Songs/", 1, true) ~= nil
	end
	local function getn(t) return sizes[t] or #t end
	table.getn = getn
	table.setn = function(t, n) sizes[t] = n end
	table.insert = function(t, a, b)
		if not from_modfile() and sizes[t] == nil then
			if b == nil then return tinsert(t, a) end
			return tinsert(t, a, b)
		end
		local n = getn(t)
		if b == nil then
			t[n + 1] = a
		else
			for i = n, a, -1 do t[i + 1] = t[i] end
			t[a] = b
		end
		sizes[t] = n + 1
	end
	table.remove = function(t, pos)
		if not from_modfile() and sizes[t] == nil then
			if pos == nil then return tremove(t) end
			return tremove(t, pos)
		end
		local n = getn(t)
		if n <= 0 then return nil end
		pos = pos or n
		local v = t[pos]
		for i = pos, n - 1 do t[i] = t[i + 1] end
		t[n] = nil
		sizes[t] = n - 1
		return v
	end
end
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
	-- ApplyModifiers is implemented in C++ (GameState.cpp, CC fork).
	GameState.GetVersionDate = function() return "20241010" end
	-- NotITG: file/folder names inside a directory, returned as MULTIPLE values
	GameState.GetFileStructure = function(self, path)
		if not path then return end
		if path:sub(-1) ~= "/" then path = path .. "/" end
		local out = {}
		for _, f in ipairs(FILEMAN:GetDirListing(path .. "*", false, false) or {}) do
			out[#out + 1] = f
		end
		return unpack(out)
	end
	GameState.GetVersion = function() return "v4.9.1" end
	-- NotITG: noteskin name of each player, as multiple return values
	GameState.GetCurrentNoteSkins = function(self)
		local out = {}
		for i, pn in ipairs({ PLAYER_1, PLAYER_2 }) do
			local ps = self:GetPlayerState(pn)
			local ns = ps and ps:GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or nil
			if ns == nil or ns == "" then ns = "default" end
			out[i] = ns
		end
		return unpack(out)
	end
end

if Actor then
	-- GetShader/SetShader/ClearShader are real now (C++ CCShader, CC fork).
end

-- NotITG Song shortcuts for TimingData lookups
if Song then
	Song.GetElapsedTimeFromBeat = function(self, b) return self:GetTimingData():GetElapsedTimeFromBeat(b) end
	Song.GetBeatFromElapsedTime = function(self, t) return self:GetTimingData():GetBeatFromElapsedTime(t) end
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
	-- NotITG/OpenITG: hidden(0) means SHOW. In Lua 5.1 the number 0 is truthy,
	-- so ITGmania's hidden(0) hid the actor -- breaking proxies, Mirin's update
	-- loop and countless modfiles. Numbers follow C rules here: 0 = false.
	local function cc_hidden(self, v)
		local hide
		if type(v) == "number" then hide = (v ~= 0)
		elseif v == nil then hide = true
		else hide = (v and true or false) end
		return self:visible(not hide)
	end
	-- ITGmania copies base methods into every class table, so patch them all.
	for _, cls in pairs(_G) do
		if type(cls) == "table" and rawget(cls, "hidden") then cls.hidden = cc_hidden end
	end
	Actor.hidden = cc_hidden
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
		-- NotITG doesn't run luaeffect on hidden actors (Mirin hides itself on
		-- error and unhides when an update succeeds).
		CCAddFrameHook(function()
			if self:GetVisible() then
				CCLuaEffectRuns = (CCLuaEffectRuns or 0) + 1
				if CCWatchdogArm then CCWatchdogArm() end
				self:playcommand(cmdname)
			else
				CCLuaEffectSkips = (CCLuaEffectSkips or 0) + 1
			end
		end, math.huge, self)
		return self
	end
	local orig_stopeffect = Actor.stopeffect
	Actor.stopeffect = function(self, ...)
		CCKillFrameHooks(self)
		return orig_stopeffect(self, ...)
	end
end

-- NotITG: SCREENMAN('PlayerP1') == SCREENMAN:GetTopScreen():GetChild('PlayerP1')
-- SCREENMAN doesn't exist yet while theme scripts load, so ScreenSystemLayer
-- aux.lua calls this once the screen system is up.
function CCMakeScreenmanCallable()
	if CCScreenmanCallable then return end
	local gm = (debug and debug.getmetatable) or getmetatable
	local mt = SCREENMAN and gm(SCREENMAN)
	if type(mt) ~= "table" then
		Trace("CC-NOTITG: couldn't make SCREENMAN callable (" .. type(mt) .. ")")
		return
	end
	if mt.__call == nil then
		mt.__call = function(self, name)
			local top = self:GetTopScreen()
			if not top or not name then return nil end
			return top:GetChild(name)
		end
	end
	CCScreenmanCallable = true
end

-- Diagnostics for the test harness: count ApplyModifiers calls.
if GameState and GameState.ApplyModifiers then
	local cpp_apply = GameState.ApplyModifiers
	GameState.ApplyModifiers = function(self, s, pn)
		CCApplyCount = (CCApplyCount or 0) + 1
		CCLastApply = tostring(s) .. " @" .. tostring(pn)
		return cpp_apply(self, s, pn)
	end
end

-- (Relative/NotITG-style loadfile paths are handled in 01 base.lua.)

-- NotITG Actor:xywh(x, y, w, h): position plus size in one call.
if Actor then
	Actor.xywh = function(self, x, y, w, h)
		self:xy(x, y)
		if w and h then self:zoomto(w, h) end
		return self
	end
end

-- NotITG passes player numbers as 0-based numbers (0 = P1 ... 7 = P8).
-- Translate for GAMESTATE player functions; P3..P8 exist only in NotITG songs.
if GameState then
	local function is_notitg() return CCIsNotITGSong and CCIsNotITGSong() or false end
	local function wrap(name, extra_result)
		local orig = GameState[name]
		if type(orig) ~= "function" then return end
		GameState[name] = function(self, pn, ...)
			if type(pn) == "number" then
				if pn >= 2 then
					if extra_result == "bool" then return is_notitg() end
					return nil
				end
				pn = PlayerNumber[pn + 1]
			end
			return orig(self, pn, ...)
		end
	end
	wrap("IsPlayerEnabled", "bool")
	wrap("IsHumanPlayer")
	wrap("IsSideJoined")
	wrap("GetPlayerState")
	wrap("GetCurrentSteps")
	wrap("SetCurrentSteps")
	wrap("GetPlayerDisplayName")
end

-- NotITG timing/system getters that ITGmania lacks.
if GameState then
	GameState.GetSongTime = function(self) return self:GetCurMusicSeconds() end
	GameState.GetSongTimeVisible = function(self) return self:GetCurMusicSeconds() end
	GameState.SetSongEndTime = function(self) return self end
	GameState.FinishSong = function(self) return self end
	GameState.ForceSmoothLines = function(self) return self end
	GameState.IsEditMode = function(self) return false end
end
if RageDisplay then
	RageDisplay.GetVendor = function() return "Apple" end
	RageDisplay.GetRenderer = function() return "OpenGL" end
end

-- NotITG: actors are callable -- frame('Name') == frame:GetChild('Name').
do
	local reg = debug and debug.getregistry and debug.getregistry()
	local n = 0
	if reg then
		for k, mt in pairs(reg) do
			if type(k) == "string" and type(mt) == "table" and rawget(mt, "__index") ~= nil
				and type(_G[k]) == "table" and _G[k].GetChild and rawget(mt, "__call") == nil then
				mt.__call = function(self, name) return self:GetChild(name) end
				n = n + 1
			end
		end
	end
	Trace("CC-NOTITG: callable actor classes = " .. n)
end
