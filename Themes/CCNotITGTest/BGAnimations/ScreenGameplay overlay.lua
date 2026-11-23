-- CC harness: log modfile state, heartbeat, and trigger a mid-song screenshot (~40% of the song).
local function report(tag)
	local s = ""
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local ps = GAMESTATE:GetPlayerState(pn)
		s = s .. ToEnumShortString(pn) .. "=[" .. ps:GetPlayerOptionsString("ModsLevel_Current") .. "] "
	end
	Trace("CCTEST " .. tag .. ": notitg=" .. tostring(CCIsNotITGSong and CCIsNotITGSong()) ..
		" hooks=" .. tostring(CCFrameHooks and #CCFrameHooks) ..
		" applies=" .. tostring(CCApplyCount) .. " beat=" .. string.format("%.1f", GAMESTATE:GetSongBeat()) .. " mods " .. s:sub(1, 200))
end
local J = {}
local H = {}
local function expected()
	local ok, a, b, c = pcall(function()
		local st = GAMESTATE:GetCurrentSteps(PLAYER_1)
		local rv = st:GetRadarValues(PLAYER_1)
		return rv:GetValue("RadarCategory_TapsAndHolds"), rv:GetValue("RadarCategory_Holds"), rv:GetValue("RadarCategory_Rolls")
	end)
	if ok then return a, b, c end
	return -1, -1, -1
end
local function judged(tag)
	local parts = {}
	for k, v in pairs(J) do parts[#parts+1] = k:gsub("TapNoteScore_", "") .. "=" .. v end
	table.sort(parts)
	local hp = {}
	for k, v in pairs(H) do hp[#hp+1] = k:gsub("HoldNoteScore_", "") .. "=" .. v end
	table.sort(hp)
	local t, h, r = expected()
	Trace("CCTEST JUDGED " .. tag .. ": " .. table.concat(parts, " ") .. " | holds " .. table.concat(hp, " ") .. " | expected taps=" .. tostring(t) .. " holds=" .. tostring(h) .. " rolls=" .. tostring(r))
end
local shot_at = 20
do
	local song = GAMESTATE:GetCurrentSong()
	if song then shot_at = math.max(10, song:GetLastSecond() * 0.4) end
end
local elapsed, shot_done = 0, false
return Def.ActorFrame{
	OnCommand=function(self) Trace("CCTEST gameplay start; shot at " .. string.format("%.1f", shot_at)); self:sleep(5):queuecommand("Tick") end,
	TickCommand=function(self)
		elapsed = elapsed + 5
		do local e = setmetatable({}, {__index=_G, __call=function(s,a) if a then setfenv(a,s); return a end end})
			local f = e(function(self) zzbg = self end); f(7)
			Trace("CCTEST fenvprobe e.zzbg=" .. tostring(rawget(e,"zzbg")) .. " G.zzbg=" .. tostring(rawget(_G,"zzbg"))) end
		do local ks = {} for k in pairs(rawget(_G,"melody") or {}) do ks[#ks+1]=tostring(k) end
			Trace("CCTEST melkeys=" .. table.concat(ks,",") .. " err=" .. tostring(rawget(_G,"melody_error"))) end
		Trace("CCTEST ccmark=" .. tostring(rawget(_G,"CCMARK")))
		Trace("CCTEST bgglobals Bg1=" .. tostring(rawget(_G,"Bg1")) .. " Red_Bg1=" .. tostring(rawget(_G,"Red_Bg1")) .. " TotalColor=" .. tostring(rawget(_G,"TotalColor")))
		Trace("CCTEST melody=" .. tostring(rawget(_G,"melody")) .. " mbg=" .. tostring(rawget(_G,"melody") and rawget(melody,"bg")) .. " gbg=" .. tostring(rawget(_G,"bg")) .. " load=" .. tostring(rawget(_G,"melody_load") and table.concat(melody_load,",")))
		Trace("CCTEST tick " .. elapsed .. " beat=" .. string.format("%.1f", GAMESTATE:GetSongBeat()))
		if elapsed == 10 then report("t10") end
		if elapsed % 30 == 0 then report("hb"); judged("hb") end
		if not shot_done and elapsed >= shot_at then
			shot_done = true
			report("mid")
			pcall(SaveScreenshot, PLAYER_1, false, false, "cctest_", "")
			Trace("CCTEST SHOTNOW")
		end
		self:sleep(5):queuecommand("Tick")
	end,
	JudgmentMessageCommand=function(self, p)
		if p.Player and p.Player ~= PLAYER_1 then return end
		if p.TapNoteScore and p.TapNoteScore ~= "TapNoteScore_None" then J[p.TapNoteScore] = (J[p.TapNoteScore] or 0) + 1 end
		if p.HoldNoteScore and p.HoldNoteScore ~= "HoldNoteScore_None" then H[p.HoldNoteScore] = (H[p.HoldNoteScore] or 0) + 1 end
	end,
	OffCommand=function(self) judged("final") end,
}
