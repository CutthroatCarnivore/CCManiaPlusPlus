-- Reads Save/cc_test_song.txt ("Group/Song Folder"), sets up autoplay gameplay, jumps in.
local function readfile(p)
  local f = RageFileUtil.CreateRageFile()
  if not f:Open(p, 1) then f:destroy() return nil end
  local s = f:Read(); f:Close(); f:destroy(); return s
end
return Def.ActorFrame{
  OnCommand=function(self) self:sleep(1):queuecommand("Go") end,
  GoCommand=function(self)
    CCMARK = 42
    Trace("CCTEST os=" .. tostring(os) .. " clock=" .. tostring(os and os.clock and os.clock()) .. " typeclock=" .. type(os and os.clock) .. " getn=" .. tostring(table.getn))
    local want = (readfile("Save/cc_test_song.txt") or ""):gsub("%s+$","")
    local song
    for _, s in ipairs(SONGMAN:GetAllSongs()) do
      local d = s:GetSongDir()
      if d:find(want, 1, true) then song = s break end
    end
    if not song then Trace("CCTEST: song not found: "..want) return end
    Trace("CCTEST: found "..song:GetSongDir())
    GAMESTATE:JoinPlayer(PLAYER_1)
    GAMESTATE:SetCurrentPlayMode("PlayMode_Regular")
    GAMESTATE:SetCurrentStyle("single")
    GAMESTATE:SetCurrentSong(song)
    local steps = song:GetStepsByStepsType("StepsType_Dance_Single")
    local pick = steps[#steps]
    for _, st in ipairs(steps) do if st:GetDifficulty() == "Difficulty_Hard" then pick = st end end
    GAMESTATE:SetCurrentSteps(PLAYER_1, pick)
    Trace("CCTEST: steps "..tostring(pick and pick:GetDifficulty()))
    local skin = (lua.ReadFile("/Save/cc_test_noteskin.txt") or "cutthroat-carnivore-inferno-cycle"):gsub("%s+$", "")
    if NOTESKIN:DoesNoteSkinExist(skin) then
      GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptions("ModsLevel_Preferred"):NoteSkin(skin)
      GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptions("ModsLevel_Stage"):NoteSkin(skin)
      GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptions("ModsLevel_Song"):NoteSkin(skin)
    end
    Trace("CCTEST: noteskin "..skin.." exists="..tostring(NOTESKIN:DoesNoteSkinExist(skin)))
    SCREENMAN:SetNewScreen("ScreenGameplay")
  end
}
