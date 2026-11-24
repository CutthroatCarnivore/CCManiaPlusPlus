#include "global.h"
#include "CCSplines.h"

#include <algorithm>
#include <utility>
#include <vector>

#include "PlayerState.h"
#include "ScreenGameplay.h"  // CC_NOTITG_EXTRA_PLAYERS

PlayerState* CCGetExtraPlayerState(int idx);  // ScreenGameplay.cpp

int CCSplineSlot(const PlayerState* ps) {
  if (ps == nullptr) return -1;
  for (int i = 0; i < CC_NOTITG_EXTRA_PLAYERS; ++i) {
    if (CCGetExtraPlayerState(i) == ps) return 2 + i;
  }
  return static_cast<int>(ps->m_PlayerNumber);
}

namespace {
constexpr int kPlayers = 2 + CC_NOTITG_EXTRA_PLAYERS;
constexpr int kCols = 16;
constexpr int kPoints = 40;

// How NotITG reads spline points (CC Conformance 34 "Spline gaps", side by
// side against NotITG 4.9.1): points are used in index order, 0 up to the
// highest index set; a point that was never set counts as offset 0, value 0
// (so a lone point 1 at 300 ramps up from 0 at the receptors instead of
// moving them); reading stops at the first point whose offset is lower than
// the one before it. One usable point gives a constant.
struct Spline {
  int n = 0;  // highest index set since the last reset, plus one
  float off[kPoints] = {};
  float val[kPoints] = {};
  bool dirty = false;
  std::vector<std::pair<float, float>> sorted;  // usable (offset, value) points
};

Spline g_splines[kPlayers][NUM_CCSP][kCols];
int g_count[kPlayers] = {};

void Rebuild(Spline& s) {
  s.sorted.clear();
  for (int i = 0; i < s.n; ++i) {
    if (i > 0 && s.off[i] < s.off[i - 1]) break;
    s.sorted.emplace_back(s.off[i], s.val[i]);
  }
  s.dirty = false;
}

void Recount(int pn) {
  int n = 0;
  for (int t = 0; t < NUM_CCSP; ++t)
    for (int c = 0; c < kCols; ++c) n += g_splines[pn][t][c].n;
  g_count[pn] = n;
}
}  // namespace

void CCSplineSetPoint(int pn, int type, int index, int column, float value,
                      float offset) {
  if (pn < 0 || pn >= kPlayers || type < 0 || type >= NUM_CCSP) return;
  if (index < 0 || index >= kPoints) return;
  const int c0 = column < 0 ? 0 : column, c1 = column < 0 ? kCols - 1 : column;
  if (c0 >= kCols) return;
  for (int c = c0; c <= std::min(c1, kCols - 1); ++c) {
    Spline& s = g_splines[pn][type][c];
    if (index + 1 > s.n) {
      g_count[pn] += index + 1 - s.n;
      s.n = index + 1;
    }
    s.off[index] = offset;
    s.val[index] = value;
    s.dirty = true;
  }
}

void CCSplineReset(int pn, int type, int column) {
  if (pn < 0 || pn >= kPlayers || type < 0 || type >= NUM_CCSP) return;
  const int c0 = column < 0 ? 0 : column, c1 = column < 0 ? kCols - 1 : column;
  for (int c = c0; c <= std::min(c1, kCols - 1); ++c) {
    Spline& s = g_splines[pn][type][c];
    for (int i = 0; i < kPoints; ++i) s.off[i] = s.val[i] = 0.0f;
    s.n = 0;
    s.sorted.clear();
    s.dirty = false;
  }
  Recount(pn);
}

void CCSplineResetAll() {
  for (int p = 0; p < kPlayers; ++p) {
    for (int t = 0; t < NUM_CCSP; ++t) CCSplineReset(p, t, -1);
    g_count[p] = 0;
  }
}

bool CCSplineAny(int pn) {
  return pn >= 0 && pn < kPlayers && g_count[pn] > 0;
}

float CCSplineEval(int pn, int type, int column, float y_offset_px) {
  if (!CCSplineAny(pn) || type < 0 || type >= NUM_CCSP) return 0.0f;
  if (column < 0 || column >= kCols) column = 0;
  Spline& s = g_splines[pn][type][column];
  if (s.dirty) Rebuild(s);
  const auto& p = s.sorted;
  if (p.empty()) return 0.0f;
  if (p.size() == 1) return p[0].second;
  const float x = y_offset_px * 100.0f / 64.0f;
  if (x <= p.front().first) return p.front().second;
  if (x >= p.back().first) return p.back().second;
  size_t i = 0;
  while (i + 1 < p.size() && p[i + 1].first < x) ++i;
  const float x0 = p[i].first, x1 = p[i + 1].first;
  if (x1 - x0 < 1e-6f) return p[i + 1].second;
  const float t = (x - x0) / (x1 - x0);
  // NotITG interpolates splines linearly between points (side by side:
  // 0 @ 0, 200 @ 200, 0 @ 400 puts an arrow 108 px out at +1.69 arrows).
  return p[i].second + (p[i + 1].second - p[i].second) * t;
}

// Gradients -----------------------------------------------------------------
namespace {
constexpr int kGradPoints = 64;
struct Gradient {
  int num = 0;
  float off[kGradPoints] = {};
  float col[kGradPoints][4] = {};
};
Gradient g_grad[kPlayers][NUM_CCGR][kCols];
bool g_grad_any[kPlayers] = {};

template <typename F>
void ForCols(int column, F f) {
  const int c0 = column < 0 ? 0 : column, c1 = column < 0 ? kCols - 1 : column;
  for (int c = c0; c <= std::min(c1, kCols - 1); ++c) f(c);
}
bool GradOk(int pn, int type) {
  return pn >= 0 && pn < kPlayers && type >= 0 && type < NUM_CCGR;
}
}  // namespace

void CCGradientSetNum(int pn, int type, int column, int num) {
  if (!GradOk(pn, type)) return;
  num = std::clamp(num, 0, kGradPoints);
  ForCols(column, [&](int c) {
    Gradient& g = g_grad[pn][type][c];
    for (int i = g.num; i < num; ++i) {
      g.off[i] = 0;
      g.col[i][0] = g.col[i][1] = g.col[i][2] = g.col[i][3] = 1;
    }
    g.num = num;
  });
  if (num > 0) g_grad_any[pn] = true;
}

void CCGradientSetPoint(int pn, int type, int point, int column, float offset) {
  if (!GradOk(pn, type) || point < 0 || point >= kGradPoints) return;
  ForCols(column, [&](int c) {
    Gradient& g = g_grad[pn][type][c];
    if (point >= g.num) CCGradientSetNum(pn, type, c, point + 1);
    g.off[point] = offset;
  });
}

void CCGradientSetColor(int pn, int type, int point, int column, float r,
                        float g, float b, float a) {
  if (!GradOk(pn, type) || point < 0 || point >= kGradPoints) return;
  ForCols(column, [&](int c) {
    Gradient& gr = g_grad[pn][type][c];
    if (point >= gr.num) CCGradientSetNum(pn, type, c, point + 1);
    gr.col[point][0] = r; gr.col[point][1] = g;
    gr.col[point][2] = b; gr.col[point][3] = a;
  });
}

bool CCGradientEval(int pn, int type, int column, float y_offset_px,
                    float out[4]) {
  if (!GradOk(pn, type) || !g_grad_any[pn]) return false;
  if (column < 0 || column >= kCols) column = 0;
  const Gradient& g = g_grad[pn][type][column];
  if (g.num <= 0) return false;
  const float x = y_offset_px / 64.0f;
  // Points are expected in increasing offset order (as NotITG modfiles set them).
  int lo = -1, hi = -1;
  for (int i = 0; i < g.num; ++i) {
    if (g.off[i] <= x && (lo < 0 || g.off[i] >= g.off[lo])) lo = i;
    if (g.off[i] >= x && (hi < 0 || g.off[i] <= g.off[hi])) hi = i;
  }
  if (lo < 0) lo = hi;
  if (hi < 0) hi = lo;
  const float span = g.off[hi] - g.off[lo];
  const float t = span > 1e-6f ? (x - g.off[lo]) / span : 0.0f;
  for (int k = 0; k < 4; ++k)
    out[k] = g.col[lo][k] + (g.col[hi][k] - g.col[lo][k]) * t;
  return true;
}

void CCGradientResetAll() {
  for (int p = 0; p < kPlayers; ++p) {
    for (int t = 0; t < NUM_CCGR; ++t)
      for (int c = 0; c < kCols; ++c) g_grad[p][t][c].num = 0;
    g_grad_any[p] = false;
  }
}

namespace {
std::vector<std::pair<float, float>> g_ntmults[2 + CC_NOTITG_EXTRA_PLAYERS];
bool g_pathadd[2 + CC_NOTITG_EXTRA_PLAYERS] = {};
}  // namespace

void CCSetNoteTypeMults(int pn, const std::vector<std::pair<float, float>>& v) {
  if (pn < 0 || pn >= kPlayers) return;
  g_ntmults[pn] = v;
  std::stable_sort(g_ntmults[pn].begin(), g_ntmults[pn].end(),
                   [](const std::pair<float, float>& a,
                      const std::pair<float, float>& b) { return a.first < b.first; });
}

float CCNoteTypeBeat(int pn, float beat) {
  if (pn < 0 || pn >= kPlayers || g_ntmults[pn].empty()) return beat;
  const std::pair<float, float>* seg = nullptr;
  for (const auto& m : g_ntmults[pn]) {
    if (m.first <= beat + 0.0001f) seg = &m; else break;
  }
  if (seg == nullptr || seg->second == 1.0f) return beat;
  return seg->first + (beat - seg->first) * seg->second;
}

void CCSetArrowPathAdd(int pn, bool add) {
  if (pn >= 0 && pn < kPlayers) g_pathadd[pn] = add;
}
bool CCArrowPathAdd(int pn) { return pn >= 0 && pn < kPlayers && g_pathadd[pn]; }

void CCNoteTypeResetAll() {
  for (int p = 0; p < kPlayers; ++p) { g_ntmults[p].clear(); g_pathadd[p] = false; }
}
