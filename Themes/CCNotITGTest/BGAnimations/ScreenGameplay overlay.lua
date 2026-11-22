-- CC harness: periodically log what the modfile is doing.
local function report(tag)
	local s = ""
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local ps = GAMESTATE:GetPlayerState(pn)
		s = s .. ToEnumShortString(pn) .. "=[" .. ps:GetPlayerOptionsString("ModsLevel_Current") .. "] "
	end
	Trace("CCTEST " .. tag .. ": notitg=" .. tostring(CCIsNotITGSong and CCIsNotITGSong()) ..
		" xero=" .. tostring(xero ~= nil) .. " sleeper=" .. tostring(CCSleepingPlayer and CCSleepingPlayer()) .. " hooks=" .. tostring(CCFrameHooks and #CCFrameHooks) .. " le=" .. tostring(CCLuaEffectRuns) .. "/" .. tostring(CCLuaEffectSkips) ..
		" applies=" .. tostring(CCApplyCount) .. " last=" .. tostring(CCLastApply):sub(1,200) .. " beat=" .. string.format("%.1f", GAMESTATE:GetSongBeat()) .. " mods " .. s:sub(1, 300))
end
return Def.ActorFrame{
	OnCommand=function(self) self:sleep(8):queuecommand("R1") end,
	R1Command=function(self) report("t8")
		if FILEMAN:DoesFileExist("Save/cc_test_showp1.txt") then
			local p1 = SCREENMAN:GetTopScreen():GetChild("PlayerP1")
			if p1 then p1:visible(true); p1:GetChild("NoteField"):visible(true) end
			Trace("CCTEST forced P1 visible: " .. tostring(p1))
		end
		-- list proxies in the foreground
		local fg = SCREENMAN:GetTopScreen():GetChild("SongForeground")
		local n = 0
		local function walk(a, d)
			if d > 12 then return end
			if a.GetTarget then n = n + 1; Trace("CCTEST proxy vis=" .. tostring(a:GetVisible()) .. " target=" .. tostring(a:GetTarget() and a:GetTarget():GetName())) end
			if a.GetNumChildren and a.GetChildAt then
				for i = 0, a:GetNumChildren() - 1 do local c = a:GetChildAt(i); if c then walk(c, d+1) end end
			end
		end
		if fg then walk(fg, 0) end
		Trace("CCTEST proxies=" .. n)
		self:sleep(10):queuecommand("R2") end,
	R2Command=function(self) report("t18")
		local ok, a, b = pcall(SaveScreenshot, PLAYER_1, false, false, "cctest_", "")
		Trace("CCTEST shot: " .. tostring(ok) .. " " .. tostring(a) .. " " .. tostring(b))
	end,
}
