-- CC fork debug: if Save/cc_watchdog.txt exists, write a traceback to
-- Save/cc_watchdog_out_N.txt when one luaeffect run exceeds ~20M instructions.
if debug and debug.sethook and (FILEMAN:DoesFileExist("/Save/cc_watchdog.txt") or FILEMAN:DoesFileExist("Save/cc_watchdog.txt")) then Trace("CC-WATCHDOG armed")
	local hits = 0
	local function handler()
		hits = hits + 1
		if hits > 4 then return end
		local f = RageFileUtil.CreateRageFile()
		if f:Open("Save/cc_watchdog_out_" .. hits .. ".txt", 2) then
			f:Write(debug.traceback("", 2) .. "\n")
			f:Close()
		end
		f:destroy()
	end
	local wrote = false
	function CCWatchdogArm()
		if not wrote then
			wrote = true
			local f = RageFileUtil.CreateRageFile()
			local ok = f:Open("Save/cc_watchdog_armed.txt", 2)
			if ok then f:Write("armed\n"); f:Close() end
			f:destroy()
		end
		debug.sethook(handler, "", 20000000)
	end
	function CCWatchdogDisarm() debug.sethook() end
end
