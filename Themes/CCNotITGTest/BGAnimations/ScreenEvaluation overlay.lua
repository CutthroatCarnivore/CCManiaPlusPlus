-- CC harness: log the final score so scoring can be checked.
return Def.ActorFrame{
	OnCommand=function(self)
		local ok, err = pcall(function()
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
			local t = {}
			for _, n in ipairs{"W1","W2","W3","W4","W5","Miss"} do
				t[#t+1] = n .. "=" .. tostring(pss:GetTapNoteScores("TapNoteScore_" .. n))
			end
			Trace(string.format("CCTEST SCORE pct=%.2f holds=%s/%s %s grade=%s", pss:GetPercentDancePoints()*100,
				tostring(pss:GetHoldNoteScores("HoldNoteScore_Held")), tostring(pss:GetRadarPossible():GetValue("RadarCategory_Holds")),
				table.concat(t, " "), tostring(pss:GetGrade())))
		end)
		if not ok then Trace("CCTEST SCORE error: " .. tostring(err)) end
	end
}
