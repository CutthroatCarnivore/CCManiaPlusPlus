local t = Def.ActorFrame {
	-- CC fork: drives NotITG-style per-frame hooks (tween expressions, luaeffect)
	InitCommand = function(self)
		self:SetUpdateFunction(function(_, dt)
			if CCRunFrameHooks then CCRunFrameHooks(dt) end
		end)
	end,
};
return t;
