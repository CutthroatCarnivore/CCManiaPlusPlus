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

-- NotITG's print() writes to its log; ITGmania's goes to stdout where nobody sees modfile
-- diagnostics. Route it to the log (capped so a chatty modfile can't flood it).
do
	local n = 0
	print = function(...)
		if n >= 300 then return end
		n = n + 1
		local t = {}
		for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
		Trace("CC-PRINT " .. table.concat(t, " "))
	end
end

-- CC: this build ships without the Lua os library; give modfiles a minimal one.
if not os then
	os = {
		clock = function() return (GetTimeSinceStart and GetTimeSinceStart()) or 0 end,
		time = function() return 0 end,
		date = function() return "" end,
		getenv = function() return nil end,
	}
end

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

CC_OBJECT_GETTER_WORDS = { "Child", "Texture", "Shader", "Screen", "Song", "Steps", "Player",
	"Proxy", "Target", "Wrapper", "Parent", "Actor", "Frame", "Options", "State", "Profile",
	"Manager", "NoteData", "Timing", "Font", "Text", "Model", "Course", "Trail", "Style",
	"Display", "Name", "Path", "Dir", "Group", "Title", "Artist", "Table", "List", "Command",
	"Saved", "Stats", "Score", "Vendor", "Renderer", "Version" }

local function stub_for(cls, name)
	return function(self, ...)
		note(cls, name)
		if name:find("^Is") or name:find("^Has") then return false end
		if name:find("^Get") or name:find("^get") then
			-- Getters for things (children, textures, songs...) get a chainable null object;
			-- every other getter is numeric in NotITG, so return 0 (a table there errors).
			local rest = name:gsub("^[Gg]et", "")
			for _, w in ipairs(CC_OBJECT_GETTER_WORDS) do
				if rest:find(w) then return CCNull end
			end
			return 0
		end
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
-- NotITG Profile:GetSaved(): a Lua table modfiles can keep data in (kept for this session).
if Profile then
	Profile.GetSaved = function(self)
		CC_PROFILE_SAVED = CC_PROFILE_SAVED or {}
		return CC_PROFILE_SAVED
	end
end
-- NotITG Song:GetSpellCards(): the song's spell cards as a list of tables.
-- CC doesn't show spell cards, so a song has none (Unkai iterates this list).
if Song then
	Song.GetSpellCards = function(self) return {} end
end
-- NotITG Actor:GetXMLDir(): folder of the .xml file the modfile is loading from
-- (Unkai's module loader builds its require() paths from it).
if Actor and ActorUtil and ActorUtil.CCCurrentXMLDir then
	Actor.GetXMLDir = function(self) return ActorUtil.CCCurrentXMLDir() end
end
if GameState then
	-- ApplyModifiers is implemented in C++ (GameState.cpp, CC fork).
	GameState.GetVersionDate = function() return "20241010" end
	-- NotITG: file/folder names inside a directory, returned as MULTIPLE values
	GameState.GetFileStructure = function(self, path)
		if not path then return end
		-- a file (not a folder): report it, so "does this file exist" checks pass
		if path:sub(-1) ~= "/" and FILEMAN:DoesFileExist(path)
			and ActorUtil.GetFileType(path) ~= "FileType_Directory" then
			return (path:match("[^/]+$"))
		end
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
		-- NotITG returns a table ({p1, p2}); it also concatenates/prints as P1's skin
		return setmetatable(out, {
			__tostring = function(t) return t[1] end,
			__concat = function(a, b)
				return (type(a) == "table" and a[1] or a) .. (type(b) == "table" and b[1] or b)
			end,
		})
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

-- IsAwake/SetAwake/SetInputPlayer are real now (C++, CC fork: NotITG P3..P8).
if Player then
	if not Player.IsAwake then Player.IsAwake = function() return true end end
	if not Player.SetAwake then Player.SetAwake = function(self) return self end end
end

-- Per-frame hooks (driven from ScreenSystemLayer aux.lua) ------------------
CCFrameHooks = {}
function CCAddFrameHook(fn, duration, owner)
	table.insert(CCFrameHooks, { fn = fn, left = duration or math.huge, owner = owner })
end
function CCKillFrameHooks(owner)
	for _, h in ipairs(CCFrameHooks) do if h.owner == owner then h.dead = true end end
end
-- The hooks run from the screen system layer, which outlives every screen.
-- Modfile hooks belong to the song: drop them all once gameplay hands off
-- to a non-gameplay screen (results, back to song select), so they don't
-- keep running modfile code against destroyed actors.
-- Modfiles share the theme's Lua state. Some replace engine globals (My Leather's
-- actorgen does "Def = {}" because NotITG has no Def), which broke the theme's
-- evaluation screen and the CC Scorecard after the song. Snapshot the engine and
-- theme globals while a non-gameplay screen is up; ScreenGameplay calls
-- CCRestoreGlobals() as it hands off, before the next screen's Lua runs.
local cc_stdlib = { string = true, table = true, math = true, os = true, io = true,
	coroutine = true, debug = true, Def = true }
local cc_gsnap, cc_fsnap
local function cc_restorable_table(k, v)
	return cc_stdlib[k] or getmetatable(v) ~= nil
end
function CCSnapshotGlobals()
	local g, f = {}, {}
	for k, v in pairs(_G) do
		local t = type(v)
		if t == "function" or t == "userdata" then
			g[k] = v
		elseif t == "table" and k ~= "_G" and k ~= "package" and k ~= "_LOADED"
			and cc_restorable_table(k, v) then
			g[k] = v
			local fields = {}
			for fk, fv in pairs(v) do if type(fv) == "function" then fields[fk] = fv end end
			f[k] = fields
		end
	end
	cc_gsnap, cc_fsnap = g, f
end
function CCRestoreGlobals()
	if not cc_gsnap then return 0 end
	local n, names = 0, {}
	for k, v in pairs(cc_gsnap) do
		if rawget(_G, k) ~= v then
			rawset(_G, k, v); n = n + 1
			if #names < 8 then names[#names + 1] = tostring(k) end
		end
	end
	for k, fields in pairs(cc_fsnap) do
		local t = rawget(_G, k)
		if type(t) == "table" then
			for fk, fv in pairs(fields) do
				if rawget(t, fk) ~= fv then
					rawset(t, fk, fv); n = n + 1
					if #names < 8 then names[#names + 1] = tostring(k) .. "." .. tostring(fk) end
				end
			end
		end
	end
	if n > 0 then
		Trace("CC-NOTITG restored " .. n .. " globals a modfile replaced: " .. table.concat(names, ", "))
	end
	return n
end

local cc_top_screen, cc_top_was_gameplay = nil, false
local function CCDropHooksAfterGameplay()
	local top = SCREENMAN and SCREENMAN:GetTopScreen()
	if top == cc_top_screen then return end
	local leaving_gameplay = cc_top_was_gameplay
	cc_top_screen = top
	cc_top_was_gameplay = top ~= nil and top.GetScreenType ~= nil
		and top:GetScreenType() == "ScreenType_Gameplay"
	if top ~= nil and not cc_top_was_gameplay then
		-- back on a theme screen: modfile code is gone, refresh the clean snapshot
		if leaving_gameplay then CCRestoreGlobals() end
		CCSnapshotGlobals()
	end
	if leaving_gameplay and not cc_top_was_gameplay and #CCFrameHooks > 0 then
		Trace("CC-NOTITG dropped " .. #CCFrameHooks .. " frame hooks after gameplay")
		CCFrameHooks = {}
	end
end
function CCWatchdogTrip()
	error("CC watchdog: modfile hook exceeded its instruction budget (infinite loop?)", 2)
end
function CCRunFrameHooks(dt)
	CCDropHooksAfterGameplay()
	for i = #CCFrameHooks, 1, -1 do
		local h = CCFrameHooks[i]
		if h.dead then
			table.remove(CCFrameHooks, i)
		else
			-- watchdog: a modfile hook that runs ~50M Lua instructions in one call (an
			-- infinite loop) is cut off and dropped instead of freezing the game.
			local have_hook = debug and debug.sethook
			if have_hook then debug.sethook(CCWatchdogTrip, "", 50000000) end
			local ok, err = xpcall(function() return h.fn(dt) end,
				function(e) return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback("", 2) or "") end)
			if have_hook then debug.sethook() end
			if not ok and tostring(err):find("CC watchdog", 1, true) then
				h.dead = true
				Trace("CC-WATCHDOG: dropped a runaway modfile hook (" .. (tostring(err):match("^[^\n]*") or "?") .. ")")
			end
			h.left = h.left - dt
			if ok then h.fails = 0
			else
				local stale = tostring(err):find("stale Actor", 1, true)
				if stale then h.dead = true end  -- target actor destroyed by a screen change: drop quietly
				h.fails = (h.fails or 0) + 1
				h.total_fails = (h.total_fails or 0) + 1
				local key = tostring(err):match("^[^\n]*") or "?"
				CCHookErrSeen = CCHookErrSeen or {}
				if not CCHookErrSeen[key] and not stale then
					CCHookErrSeen[key] = true
					Trace("CC-NOTITG hook error: " .. tostring(err))
				end
			end
			-- keep the hook alive through errors; only drop it after 600 straight failing frames
			if (not ok and h.fails >= 600) or h.left <= 0 then
				if not ok then Trace("CC-NOTITG hook disabled after repeated errors") end
				table.remove(CCFrameHooks, i)
			end
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
		-- tween(time, "ease(%f,0,1,1)"): an easing expression with %f = progress
		if type(tt) == "string" and tt:find("%%f") then
			local src = tt
			tt = function(x)
				local f = loadstring("return " .. src:gsub("%%f", string.format("%.6f", x)))
				return f and f() or x
			end
		end
		if type(tt) == "string" and tt:find("%(") then
			local f = loadstring("return " .. tt)
			if f then
				CCAddFrameHook(function() f() end, t, self)
				return self:sleep(t)
			end
		end
		-- NotITG: tween(time, easeFunction) -- fit the ease to a cubic bezier
		-- through samples at 1/3 and 2/3, so ITGmania can tween with it.
		if type(tt) == "function" then
			local ok1, a = pcall(tt, 1/3)
			local ok2, b = pcall(tt, 2/3)
			if ok1 and ok2 and type(a) == "number" and type(b) == "number" then
				local ra, rb = a - 1/27, b - 8/27
				local p1 = (4 * ra - 2 * rb) * 3 / 4
				local p2 = (4 * rb - 2 * ra) * 3 / 4
				return orig_tween(self, t, "TweenType_Bezier", { 0, p1, p2, 1 })
			end
			return self:linear(t)
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
	-- NotITG Actor:xyz(x, y, z)
	if rawget(Actor, "xyz") == nil then
		Actor.xyz = function(self, x, y, z)
			if x then self:x(x) end
			if y then self:y(y) end
			if z then self:z(z) end
			return self
		end
	end
	-- NotITG Actor:cmd("diffuse,1,0,0,1;zoom,2"): run an old-style command string.
	if rawget(Actor, "cmd") == nil then
		Actor.cmd = function(self, s)
			if type(s) ~= "string" then return self end
			for part in s:gmatch("[^;]+") do
				local args = {}
				for a in part:gmatch("[^,]+") do args[#args + 1] = a:match("^%s*(.-)%s*$") end
				local name = table.remove(args, 1)
				if name and name ~= "" then
					local lname = name:lower()
					local f = self[name] or self[lname]
					if type(f) == "function" then
						for i, a in ipairs(args) do
							local n = tonumber(a)
							if n then args[i] = n
							else
								-- expressions like SCREEN_CENTER_X+10
								local g = loadstring("return " .. a)
								local ok, v = false, nil
								if g then ok, v = pcall(g) end
								if ok and v ~= nil then args[i] = v end
							end
						end
						pcall(f, self, unpack(args))
					end
				end
			end
			return self
		end
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
	GameState.GetSongBeatVisible = function(self)
		local pos = self:GetSongPosition()
		if pos and pos.GetSongBeatVisible then return pos:GetSongBeatVisible() end
		return self:GetSongBeat()
	end
	-- NotITG returns the master player as a number (0 = P1); ITGmania themes
	-- need the enum, so only mod-chart code (files under /Songs/) gets the number.
	if GameState.GetMasterPlayerNumber and getfenv and debug and debug.getinfo then
		local cc_gmpn = GameState.GetMasterPlayerNumber
		GameState.GetMasterPlayerNumber = function(self)
			local pn = cc_gmpn(self)
			local info = debug.getinfo(2, "S")
			if CCIsNotITGSong and CCIsNotITGSong() and info and info.source
				and info.source:lower():find("/songs/", 1, true) then
				return pn == PLAYER_2 and 1 or 0
			end
			return pn
		end
	end
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
				mt.__call = function(self, name)
					-- NotITG: frame(n) is the n-th child (1-based); frame('Name') by name
					if type(name) == "number" then
						if self.GetChildAt then return self:GetChildAt(name - 1) end
						return nil
					end
					return self:GetChild(name)
				end
				n = n + 1
			end
		end
	end
	Trace("CC-NOTITG: callable actor classes = " .. n)
end

-- NotITG actor/stat methods that modfiles call (found by running every song)
if Actor then
	if rawget(Actor, "GetHidden") == nil then
		Actor.GetHidden = function(self) return self:GetVisible() and 0 or 1 end
	end
	if rawget(Actor, "SetFPS") == nil then
		Actor.SetFPS = function(self, fps)
			fps = tonumber(fps) or 0
			if fps > 0 and self.SetAllStateDelays then self:SetAllStateDelays(1 / fps) end
			return self
		end
	end
end
-- NotITG Sound layers take lower-case `stop;start` commands.
if Actor then
	if rawget(Actor, "stop") == nil then
		Actor.stop = function(self) if self.Stop then self:Stop() end return self end
	end
	if rawget(Actor, "start") == nil then
		Actor.start = function(self) if self.Play then self:Play() end return self end
	end
end
-- NotITG always has a top screen; hand song scripts a harmless null object while ours is switching.
do
	local getinfo = debug and debug.getinfo
	local function song_caller()
		if not (CCIsNotITGSong and CCIsNotITGSong() and getinfo) then return false end
		local info = getinfo(3, "S")
		return info ~= nil and info.source ~= nil and info.source:lower():find("/songs/", 1, true) ~= nil
	end
	if StatsManager and StatsManager.GetCurStageStats then
		local orig_gcss = StatsManager.GetCurStageStats
		StatsManager.GetCurStageStats = function(self)
			local r = orig_gcss(self)
			if r == nil and song_caller() then return CCNull end
			return r
		end
	end
	if ScreenManager and ScreenManager.GetTopScreen then
		local orig_gts = ScreenManager.GetTopScreen
		ScreenManager.GetTopScreen = function(self)
			local r = orig_gts(self)
			if r == nil and song_caller() then return CCNull end
			return r
		end
	end
end
-- NotITG: THEME:GetPath(EC_SOUNDS, "name") (category constant + element name)
if ThemeManager and rawget(ThemeManager, "GetPath") == nil then
	ThemeManager.GetPath = function(self, cat, name, element)
		name = tostring(name or "")
		local fn = "GetPathS"
		if EC_GRAPHICS ~= nil and cat == EC_GRAPHICS then fn = "GetPathG"
		elseif EC_FONTS ~= nil and cat == EC_FONTS then fn = "GetPathF"
		elseif EC_BGANIMATIONS ~= nil and cat == EC_BGANIMATIONS then fn = "GetPathB" end
		-- 3-argument form: (category, class, element), e.g. (EC_SOUNDS, "Player", "mine")
		local class, el = "", name
		if element ~= nil then class, el = name, tostring(element) end
		local ok, r = pcall(function() return self[fn](self, class, el, true) end)
		if ok and type(r) == "string" then return r end
		return ""
	end
end
if PlayerStageStats and rawget(PlayerStageStats, "SetTapNoteScores") == nil then
	PlayerStageStats.SetTapNoteScores = function(self, tns, n) end
end

-- CC fork: remember which songs ran as NotITG modfiles so themes can keep
-- their scores off GrooveStats/ITL. Songs from additional folders (the NotITG
-- library) always count as NotITG songs.
CCNotITGSongDirs = CCNotITGSongDirs or {}
function CCRecordNotITGSong()
	if CCIsNotITGSong and CCIsNotITGSong() and GAMESTATE then
		local s = GAMESTATE:GetCurrentSong()
		if s then CCNotITGSongDirs[s:GetSongDir()] = true end
	end
end
function CCLastSongIsNotITG()
	local s = GAMESTATE and GAMESTATE:GetCurrentSong()
	if not s then return false end
	local d = s:GetSongDir()
	return CCNotITGSongDirs[d] == true or d:find("^/AdditionalSongs/") ~= nil
end
CCAddFrameHook = CCAddFrameHook
local cc_prev_run = CCRunFrameHooks
function CCRunFrameHooks(dt)
	CCRecordNotITGSong()
	if cc_prev_run then return cc_prev_run(dt) end
end

-- OpenITG/NotITG preference names that ITGmania split into ReadOnly/Writable.
if PrefsManager and PrefsManager.GetPreference then
	local cc_getpref = PrefsManager.GetPreference
	PrefsManager.GetPreference = function(self, name)
		if name == "AdditionalSongFolders" or name == "AdditionalFolders" then
			local ro = cc_getpref(self, name .. "ReadOnly") or ""
			local w = cc_getpref(self, name .. "Writable") or ""
			if ro ~= "" and w ~= "" then return ro .. "," .. w end
			return ro .. w
		end
		return cc_getpref(self, name)
	end
end

-- NotITG GameState:GetCurBPS (ITGmania keeps it on SongPosition).
if GameState and not GameState.GetCurBPS then
	GameState.GetCurBPS = function(self)
		local ok, bps = pcall(function() return self:GetSongPosition():GetCurBPS() end)
		if ok and bps then return bps end
		return self:GetSongBPS() or 1
	end
end
-- NotITG Steps:GetDifficulty returns a 0-based number; only song scripts get it.
if Steps and Steps.GetDifficulty then
	local cc_getdiff = Steps.GetDifficulty
	local cc_diffnum = { Difficulty_Beginner = 0, Difficulty_Easy = 1, Difficulty_Medium = 2,
		Difficulty_Hard = 3, Difficulty_Challenge = 4, Difficulty_Edit = 5 }
	local getinfo = debug and debug.getinfo
	Steps.GetDifficulty = function(self)
		local d = cc_getdiff(self)
		if CCIsNotITGSong and CCIsNotITGSong() and getinfo then
			local info = getinfo(2, "S")
			if info and info.source and info.source:lower():find("/songs/", 1, true) then
				return cc_diffnum[d] or d
			end
		end
		return d
	end
end

-- NotITG Actor:GetEffectX/Y/Z (position including effect offsets).
if Actor then
	Actor.GetEffectX = function(self) return self:GetX() end
	Actor.GetEffectY = function(self) return self:GetY() end
	Actor.GetEffectZ = function(self) return self:GetZ() end
	Actor.GetEffectRotationX = function(self) return self:GetRotationX() end
	Actor.GetEffectRotationY = function(self) return self:GetRotationY() end
	Actor.GetEffectRotationZ = function(self) return self:GetRotationZ() end
	Actor.GetCurrentZoomX = function(self) return self:GetZoomX() end
	Actor.GetCurrentZoomY = function(self) return self:GetZoomY() end
	Actor.GetCurrentZoomZ = function(self) return self:GetZoomZ() end
	Actor.GetCurrentRotationX = function(self) return self:GetRotationX() end
	Actor.GetCurrentRotationY = function(self) return self:GetRotationY() end
	Actor.GetCurrentRotationZ = function(self) return self:GetRotationZ() end
	if not rawget(Actor, "GetHidden") then
		Actor.GetHidden = function(self) return not self:GetVisible() end
	end
	Actor.getrotation = function(self) return self:GetRotationX(), self:GetRotationY(), self:GetRotationZ() end
end

-- NotITG ActorFrame:GetChildren() returns an ordered array, and GetChild()
-- returns one actor even when names repeat. Only song scripts see this.
do
	local getinfo = debug and debug.getinfo
	local function song_caller()
		if not (CCIsNotITGSong and CCIsNotITGSong() and getinfo) then return false end
		local info = getinfo(3, "S")
		return info ~= nil and info.source ~= nil and info.source:lower():find("/songs/", 1, true) ~= nil
	end
	if ActorFrame and ActorFrame.GetChildren and ActorFrame.GetChildAt then
		local cc_getchildren = ActorFrame.GetChildren
		ActorFrame.GetChildren = function(self)
			if not song_caller() then return cc_getchildren(self) end
			local out = {}
			for i = 0, self:GetNumChildren() - 1 do
				local c = self:GetChildAt(i)
				if c then out[#out + 1] = c end
			end
			return out
		end
		local cc_getchild = ActorFrame.GetChild
		ActorFrame.GetChild = function(self, name)
			local r = cc_getchild(self, name)
			if type(r) == "table" and not r.GetName and song_caller() then
				return r[1]
			end
			if r == nil and name == "" and song_caller() and self:GetNumChildren() > 0 then
				return self:GetChildAt(0)
			end
			return r
		end
	end
end

-- NotITG's Lua lets a gsub replacement function return a non-string (it is
-- ignored and the match kept); stock 5.1 errors. Keep the match instead.
do
	local cc_gsub = string.gsub
	string.gsub = function(s, pat, repl, n)
		if type(repl) == "function" then
			local f = repl
			repl = function(...)
				local r = f(...)
				local t = type(r)
				if t == "string" or t == "number" or r == nil or r == false then return r end
				return nil
			end
		end
		return cc_gsub(s, pat, repl, n)
	end
end
-- NotITG GameState:GetX/GetY/GetZ(pn, col, yoffset): arrow-path position. ITGmania
-- has no Lua hook into ArrowEffects yet, so return the neutral path.
if GameState then
	if not GameState.GetZ then GameState.GetZ = function() return 0 end end
	if not GameState.GetX then GameState.GetX = function() return 0 end end
	if not GameState.GetY then GameState.GetY = function(self, pn, col, yoff) return yoff or 0 end end
end

-- OpenITG/NotITG screen-edge names
if SCREEN_LEFT_X == nil and SCREEN_LEFT then SCREEN_LEFT_X = SCREEN_LEFT end
if SCREEN_RIGHT_X == nil and SCREEN_RIGHT then SCREEN_RIGHT_X = SCREEN_RIGHT end
if SCREEN_TOP_Y == nil and SCREEN_TOP then SCREEN_TOP_Y = SCREEN_TOP end
if SCREEN_BOTTOM_Y == nil and SCREEN_BOTTOM then SCREEN_BOTTOM_Y = SCREEN_BOTTOM end

-- NotITG Polygon/line actors: SetLineWidth (ITGmania draws lines at fixed width)
if ActorMultiVertex and not ActorMultiVertex.SetLineWidth then
	ActorMultiVertex.SetLineWidth = function(self) return self end
end

-- NotITG 3D models: line/polygon-mode setters (ITGmania has no wireframe mode)
if Model then
	for _, m in ipairs({ "SetLineWidth", "SetLineColor", "SetPolygonMode" }) do
		if not rawget(Model, m) then Model[m] = function(self) return self end end
	end
end

-- In NotITG an actor is userdata and prints as "<Class> (address)". ITGmania
-- actors are tables, so song scripts that test type()/tostring() see them as
-- that. Only song code gets the NotITG answer.
do
	local cc_type, cc_tostring = type, tostring
	local getmt, getinfo = debug and debug.getmetatable, debug and debug.getinfo
	local function actor_class(v)
		if cc_type(v) ~= "table" or not getmt then return nil end
		local mt = getmt(v)
		local f = mt and rawget(mt, "__type")
		if cc_type(f) ~= "function" then return nil end
		local ok, name = pcall(f)
		return ok and name or nil
	end
	local function song_caller()
		if not (CCIsNotITGSong and CCIsNotITGSong() and getinfo) then return false end
		local info = getinfo(3, "S")
		return info ~= nil and info.source ~= nil and info.source:lower():find("/songs/", 1, true) ~= nil
	end
	type = function(v)
		local t = cc_type(v)
		if t == "table" and CCIsNotITGSong and CCIsNotITGSong() and actor_class(v) and song_caller() then
			return "userdata"
		end
		return t
	end
	tostring = function(v)
		local s = cc_tostring(v)
		local cls = cc_type(v) == "table" and CCIsNotITGSong and CCIsNotITGSong() and actor_class(v)
		if cls and song_caller() then return cls .. " (" .. s:gsub("^table: ", "") .. ")" end
		return s
	end
end

-- CC fork: the sleeping NotITG player (hidden autoplay P2 for 1-player modfiles)
-- is not a real player. Themes must not see it, or they build UI and stats for a
-- player that has no profile or theme data (Simply Love's ScreenGameplay out.lua
-- crashed on it). Modfiles (code under /Songs/) still see it, unchanged.
if GameState and CCSleepingPlayer then
	local getinfo = debug and debug.getinfo
	-- level = stack level of the code that called the GameState method
	local function from_theme(level)
		if not getinfo then return true end
		local info = getinfo(level + 1, "S")
		return not (info and info.source and info.source:lower():find("/songs/", 1, true))
	end
	local function sleeper()
		local n = CCSleepingPlayer()
		return n and PlayerNumber[n] or nil
	end
	local function hidden(pn)
		local s = sleeper()
		return s ~= nil and pn == s and from_theme(3)
	end
	local function filter(name)
		local orig = GameState[name]
		if type(orig) ~= "function" then return end
		GameState[name] = function(self, ...)
			local t = orig(self, ...)
			local s = sleeper()
			if not s or type(t) ~= "table" or not from_theme(2) then return t end
			local r = {}
			for _, p in ipairs(t) do if p ~= s then r[#r + 1] = p end end
			return r
		end
	end
	filter("GetHumanPlayers")
	filter("GetEnabledPlayers")
	for _, name in ipairs({ "IsHumanPlayer", "IsPlayerEnabled", "IsSideJoined" }) do
		local orig = GameState[name]
		if type(orig) == "function" then
			GameState[name] = function(self, pn, ...)
				if hidden(pn) then return false end
				return orig(self, pn, ...)
			end
		end
	end
	for _, name in ipairs({ "GetNumSidesJoined", "GetNumPlayersEnabled" }) do
		local orig = GameState[name]
		if type(orig) == "function" then
			GameState[name] = function(self, ...)
				local n = orig(self, ...)
				if sleeper() and from_theme(2) and type(n) == "number" and n > 1 then return n - 1 end
				return n
			end
		end
	end
end

-- CC: NotITG accepts all-lowercase method names on actors. Alias every
-- CamelCase method that has no lowercase twin, and make getdiffuse return r,g,b,a.
do
	local classes = {"Actor","ActorFrame","ActorFrameTexture","ActorProxy","Sprite","BitmapText","Model","ActorScroller","ActorMultiVertex","Quad","NoteField","Player"}
	for _, cn in ipairs(classes) do
		local c = rawget(_G, cn)
		if type(c) == "table" then
			local add = {}
			for k, v in pairs(c) do
				if type(k) == "string" and type(v) == "function" then
					local lk = string.lower(k)
					if lk ~= k and rawget(c, lk) == nil then add[lk] = v end
				end
			end
			for k, v in pairs(add) do c[k] = v end
		end
	end
	local function wrap(c, name, rgba)
		local f = rawget(c, name)
		if f then c[string.lower(name)] = function(self, ...)
			local t = f(self, ...)
			if type(t) == "table" then return rgba(t) end
			return t
		end end
	end
	if type(Actor) == "table" then
		wrap(Actor, "GetDiffuse", function(t) return t[1], t[2], t[3], t[4] end)
		wrap(Actor, "GetGlow", function(t) return t[1], t[2], t[3], t[4] end)
	end
end

-- CC: OpenITG/NotITG score enums used by modfiles.
do
	local c = {
		TNS_NONE="TapNoteScore_None", TNS_HITMINE="TapNoteScore_HitMine", TNS_AVOIDMINE="TapNoteScore_AvoidMine",
		TNS_MISS="TapNoteScore_Miss", TNS_BOO="TapNoteScore_W5", TNS_GOOD="TapNoteScore_W4",
		TNS_GREAT="TapNoteScore_W3", TNS_PERFECT="TapNoteScore_W2", TNS_MARVELOUS="TapNoteScore_W1",
		HNS_NONE="HoldNoteScore_None", HNS_NG="HoldNoteScore_LetGo", HNS_OK="HoldNoteScore_Held",
	}
	for k, v in pairs(c) do if rawget(_G, k) == nil then rawset(_G, k, v) end end
end

-- CC: NotITG draw-distance metric names map onto ITGmania's.
do
	local TM = rawget(_G, "ThemeManager")
	if type(TM) == "table" and type(TM.GetMetric) == "function" then
		local orig = TM.GetMetric
		local map = { StopDrawingAtPixels = "DrawDistanceBeforeTargetsPixels", StartDrawingAtPixels = "DrawDistanceAfterTargetsPixels" }
		TM.GetMetric = function(self, group, name)
			if group == "Player" and map[name] then name = map[name] end
			return orig(self, group, name)
		end
	end
end

-- CC: NotITG GameState:GetCurBPM() returns the current BPM as a number.
if type(GameState) == "table" and rawget(GameState, "GetCurBPM") == nil then
	GameState.GetCurBPM = function(self)
		local bps = self.GetSongBPS and self:GetSongBPS()
		if type(bps) ~= "number" or bps <= 0 then bps = 2 end
		return bps * 60
	end
end
