#include "Foreground.h"
#include <cstdlib>

#include <algorithm>
#include <string>

#include "Actor.h"
#include "ActorFrame.h"
#include "ActorUtil.h"
#include "BackgroundUtil.h"
#include "GameState.h"
#include "MessageManager.h"
#include "PrefsManager.h"
#include "RageTextureID.h"
#include "RageTextureManager.h"
#include "RageUtil.h"
#include "Song.h"
#include "PlayerOptions.h"
#include "LuaManager.h"

// CC fork: NotITG (Lua 5.0) for-loop closure rule, see extern lua lparser.c.
#if defined(_MSC_VER)
extern int cc_lua50_forloops;
#else
extern "C" int cc_lua50_forloops;
#endif
static void CCSetLua50Loops(bool b) {
  cc_lua50_forloops = (b && std::getenv("CC_LUA51_LOOPS") == nullptr) ? 1 : 0;
}

Foreground::~Foreground() { Unload(); }

void Foreground::Unload() {
  g_bCCNotITGColumns = false;  // CC fork: back to ITGmania column numbering
  CCSetLua50Loops(false);
  for (unsigned i = 0; i < m_BGAnimations.size(); ++i) {
    delete m_BGAnimations[i].m_bga;
  }
  m_BGAnimations.clear();
  m_SubActors.clear();
  m_fLastMusicSeconds = -9999;
  m_pSong = nullptr;
}

void Foreground::LoadFromSong(const Song* pSong) {
  // Song graphics can get very big; never keep them in memory.
  RageTextureID::TexPolicy OldPolicy = TEXTUREMAN->GetDefaultTexturePolicy();
  TEXTUREMAN->SetDefaultTexturePolicy(RageTextureID::TEX_VOLATILE);

  m_pSong = pSong;
  g_bCCNotITGColumns = false;  // CC fork: set below if this is a NotITG modfile
  CCSetLua50Loops(false);
  for (const BackgroundChange& change : pSong->GetForegroundChanges()) {
    std::string sBGName = change.m_def.m_sFile1,
                sLuaFile = pSong->GetSongDir() + sBGName + "/default.lua",
                sXmlFile = pSong->GetSongDir() + sBGName + "/default.xml";

    LoadedBGA bga;
    // CC fork: when a song ships both, prefer the NotITG default.xml over a
    // default.lua port written for another engine (NotITG parity first).
    if (CC_LEGACY_ACTORS && DoesFileExist(sXmlFile)) {
      g_bCCNotITGColumns = true;
      CCSetLua50Loops(true);
      bga.m_bga = ActorUtil::MakeActor(sXmlFile, this);
    } else if (DoesFileExist(sLuaFile)) {
      bga.m_bga = ActorUtil::MakeActor(sLuaFile, this);
    } else {
      if (EndsWith(sBGName, ".xml") ||
          DoesFileExist(pSong->GetSongDir() + sBGName + "/default.xml")) {
        g_bCCNotITGColumns = true;
        CCSetLua50Loops(true);
      }
      bga.m_bga = ActorUtil::MakeActor(pSong->GetSongDir() + sBGName, this);
    }
    if (bga.m_bga == nullptr) {
      continue;
    }
    bga.m_bga->SetName(sBGName);
    // ActorUtil::MakeActor calls LoadFromNode to load the actor, and
    // LoadFromNode takes care of running the InitCommand, so do not run the
    // InitCommand here. -Kyz
    bga.m_fStartBeat = change.m_fStartBeat;
    bga.m_bFinished = false;

    bga.m_bga->SetVisible(false);

    this->AddChild(bga.m_bga);
    m_BGAnimations.push_back(bga);
  }

  TEXTUREMAN->SetDefaultTexturePolicy(OldPolicy);

  this->SortByDrawOrder();
}

void Foreground::Update(float fDeltaTime) {
  // Calls to Update() should *not* be scaled by music rate unless
  // RateModsAffectFGChanges is enabled. Undo it.
  const float fRate = PREFSMAN->m_bRateModsAffectTweens
                          ? 1.0f
                          : GAMESTATE->m_SongOptions.GetCurrent().m_fMusicRate;

  for (unsigned i = 0; i < m_BGAnimations.size(); ++i) {
    LoadedBGA& bga = m_BGAnimations[i];

    // CC fork: NotITG starts foreground modfiles as soon as gameplay loads,
    // not at their FGCHANGES beat (Mirin must set up before beat 0).
    if ((!g_bCCNotITGColumns || getenv("CC_OLD_START") != nullptr) &&
        GAMESTATE->m_Position.m_fSongBeat < bga.m_fStartBeat) {
      // The animation hasn't started yet.
      continue;
    }

    if (bga.m_bFinished) {
      continue;
    }

    /* Update the actor even if we're about to hide it, so queued commands
     * are always run. */
    float lDeltaTime;
    // CC fork: NotITG modfiles hide/unhide their own root, so "not visible"
    // can't mean "not started yet" for them.
    const bool bNeedStart = g_bCCNotITGColumns ? !bga.m_bCCStarted
                                               : !bga.m_bga->GetVisible();
    if (bNeedStart) {
      bga.m_bCCStarted = true;
      bga.m_bga->SetVisible(true);
      bga.m_bga->PlayCommand("On");
      // CC fork: NotITG follows On with ScreenReady (Mirin 4 starts there).
      if (g_bCCNotITGColumns) {
        bga.m_bga->PlayCommand("ScreenReady");
      }

      const float fStartSecond =
          m_pSong->m_SongTiming.GetElapsedTimeFromBeat(bga.m_fStartBeat);
      const float fStopSecond = fStartSecond + bga.m_bga->GetTweenTimeLeft();
      bga.m_fStopBeat =
          m_pSong->m_SongTiming.GetBeatFromElapsedTime(fStopSecond);

      lDeltaTime = GAMESTATE->m_Position.m_fMusicSeconds - fStartSecond;
      if (g_bCCNotITGColumns) {
        lDeltaTime = 0;  // CC fork: started early, nothing to catch up on
      }
    } else {
      lDeltaTime = GAMESTATE->m_Position.m_fMusicSeconds - m_fLastMusicSeconds;
    }

    // This shouldn't go down, but be safe:
    lDeltaTime = std::max(lDeltaTime, 0.0f);

    bga.m_bga->Update(lDeltaTime / fRate);

    if (GAMESTATE->m_Position.m_fSongBeat > bga.m_fStopBeat) {
      // Finished.
      bga.m_bga->SetVisible(false);
      bga.m_bFinished = true;
      continue;
    }
  }

  m_fLastMusicSeconds = GAMESTATE->m_Position.m_fMusicSeconds;
}

void Foreground::HandleMessage(const Message& msg) {
  // We want foregrounds to behave as if their On command happens at the
  // starting beat, not when the Foreground object receives an On command.
  // So don't propagate that; we'll call it ourselves.
  if (msg.GetName() == "On") {
    Actor::HandleMessage(msg);
  } else {
    ActorFrame::HandleMessage(msg);
  }
}

/*
 * (c) 2004 Glenn Maynard
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, and/or sell copies of the Software, and to permit persons to
 * whom the Software is furnished to do so, provided that the above
 * copyright notice(s) and this permission notice appear in all copies of
 * the Software and that both the above copyright notice(s) and this
 * permission notice appear in supporting documentation.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
 * THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS
 * INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT
 * OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
 * OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

// CC fork: lets Lua (theme/compat layer) ask whether a NotITG modfile is loaded.
LuaFunction(CCIsNotITGSong, g_bCCNotITGColumns);
