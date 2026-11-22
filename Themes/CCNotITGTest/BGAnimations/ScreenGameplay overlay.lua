-- CC harness: periodically log what the modfile is doing.
local function report(tag)
	local s = ""
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local ps = GAMESTATE:GetPlayerState(pn)
		s = s .. ToEnumShortString(pn) .. "=[" .. ps:GetPlayerOptionsString("ModsLevel_Current") .. "] "
	end
	Trace("CCTEST " .. tag .. ": notitg=" .. tostring(CCIsNotITGSong and CCIsNotITGSong()) ..
		" xero=" .. tostring(xero ~= nil) .. " hooks=" .. tostring(CCFrameHooks and #CCFrameHooks) .. " le=" .. tostring(CCLuaEffectRuns) .. "/" .. tostring(CCLuaEffectSkips) ..
		" applies=" .. tostring(CCApplyCount) .. " last=" .. tostring(CCLastApply):sub(1,200) .. " beat=" .. string.format("%.1f", GAMESTATE:GetSongBeat()) .. " mods " .. s:sub(1, 300))
end
return Def.ActorFrame{
	OnCommand=function(self) self:sleep(8):queuecommand("R1") end,
	R1Command=function(self) report("t8"); self:sleep(10):queuecommand("R2") end,
	R2Command=function(self) report("t18")
		local ok, a, b = pcall(SaveScreenshot, PLAYER_1, false, false, "cctest_", "")
		Trace("CCTEST shot: " .. tostring(ok) .. " " .. tostring(a) .. " " .. tostring(b))
	end,
}
