#include "ScreenGameplayNormal.h"
#include "GameState.h"

#include <vector>

#include "Difficulty.h"
#include "PlayerNumber.h"
#include "Screen.h"
#include "ScreenGameplay.h"

REGISTER_SCREEN_CLASS(ScreenGameplayNormal);

void ScreenGameplayNormal::FillPlayerInfo(
    std::vector<PlayerInfo>& vPlayerInfoOut) {
  // CC fork: NotITG modfiles expect PlayerP1..P8; add P3..P8 as dummies.
  const bool bNotITG = CCSongIsNotITG(GAMESTATE->m_pCurSong);
  vPlayerInfoOut.resize(NUM_PLAYERS + (bNotITG ? CC_NOTITG_EXTRA_PLAYERS : 0));
  FOREACH_PlayerNumber(p) vPlayerInfoOut[p].Load(
      p, MultiPlayer_Invalid, true, Difficulty_Invalid);
  if (bNotITG) {
    for (int d = 0; d < CC_NOTITG_EXTRA_PLAYERS; ++d) {
      vPlayerInfoOut[NUM_PLAYERS + d].LoadDummyP1(d, 0);
    }
  }
};

// lua end

/*
 * (c) 2005 Chris Danford
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
