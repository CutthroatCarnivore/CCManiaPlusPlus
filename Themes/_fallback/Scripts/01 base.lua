-- Override Lua's loadfile to use lua.ReadFile.
-- CC fork: NotITG-compatible path handling. Modfiles pass paths like
-- "./songs/pack/song/x.lua" (lowercase, Windows-style) or paths relative to
-- the song folder; missing files report Lua's standard "cannot read".
local function cc_candidates(file)
	local out = { file }
	local f = file:gsub("\\", "/"):gsub("/+", "/")
	f = f:gsub("^%./", "")
	if f:lower():sub(1, 6) == "songs/" then
		out[#out + 1] = "/Songs/" .. f:sub(7)
	end
	if f:sub(1, 1) ~= "/" and GAMESTATE and GAMESTATE.GetCurrentSong then
		local song = GAMESTATE:GetCurrentSong()
		if song then out[#out + 1] = song:GetSongDir() .. f end
	end
	return out
end

function loadfile(file)
	local data
	for _, cand in ipairs(cc_candidates(file)) do
		data = lua.ReadFile(cand)
		if data then file = cand break end
	end
	if not data then
		return nil, ("cannot read " .. file)
	end

	local chunk, err = load(
		function()
			local ret = data
			data = nil
			return ret
		end,
		"@" .. file
	);

	if not chunk then return nil, err end

	-- Set the environment, like loadfile does.
	setfenv(chunk, getfenv(2))
	return chunk
end

-- Override Lua's dofile to use our loadfile.
function dofile(file)
	if not file then
		error( "dofile(nil) unsupported", 2 )
	end
	local chunk, err = loadfile(file)
	if not chunk then
		error(err, 2)
	end
        return chunk()
end

-- Like ipairs(), but returns only values.
function ivalues(t)
	local n = 0
	return function()
		n = n + 1
		return t[n];
	end
end

Var = lua.GetThreadVariable

-- (c) 2006 Glenn Maynard
-- All rights reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, and/or sell copies of the Software, and to permit persons to
-- whom the Software is furnished to do so, provided that the above
-- copyright notice(s) and this permission notice appear in all copies of
-- the Software and that both the above copyright notice(s) and this
-- permission notice appear in supporting documentation.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
-- THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS
-- INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT
-- OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
-- OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
-- OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
-- PERFORMANCE OF THIS SOFTWARE.
