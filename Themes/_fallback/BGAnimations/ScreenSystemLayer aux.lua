local t = Def.ActorFrame {
	-- CC fork: drives NotITG-style per-frame hooks (tween expressions, luaeffect)
	InitCommand = function(self)
		if CCMakeScreenmanCallable then CCMakeScreenmanCallable() end
		self:SetUpdateFunction(function(_, dt)
			if CCWatchdogArm then CCWatchdogArm() end
			if CCRunFrameHooks then CCRunFrameHooks(dt) end
		end)
	end,
};
return t;
