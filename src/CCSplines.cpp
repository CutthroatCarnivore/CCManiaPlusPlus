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

struct Spline {
  bool set[kPoints] = {};
  float off[kPoints] = {};
  float val[kPoints] = {};
  bool dirty = false;
  std::vector<std::pair<float, float>> sorted;  // (offset, value)
};

Spline g_splines[kPlayers][NUM_CCSP][kCols];
int g_count[kPlayers] = {};

void Rebuild(Spline& s) {
  s.sorted.clear();
  for (int i = 0; i < kPoints; ++i) {
    if (s.set[i]) s.sorted.emplace_back(s.off[i], s.val[i]);
  }
  std::stable_sort(s.sorted.begin(), s.sorted.end(),
                   [](const std::pair<float, float>& a,
                      const std::pair<float, float>& b) { return a.first < b.first; });
  s.dirty = false;
}

void Recount(int pn) {
  int n = 0;
  for (int t = 0; t < NUM_CCSP; ++t)
    for (int c = 0; c < kCols; ++c)
      for (int i = 0; i < kPoints; ++i) n += g_splines[pn][t][c].set[i] ? 1 : 0;
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
    if (!s.set[index]) ++g_count[pn];
    s.set[index] = true;
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
    for (int i = 0; i < kPoints; ++i) s.set[i] = false;
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
  // Catmull-Rom through the neighbouring points (ends clamped).
  const float v0 = p[i > 0 ? i - 1 : i].second;
  const float v1 = p[i].second;
  const float v2 = p[i + 1].second;
  const float v3 = p[i + 2 < p.size() ? i + 2 : i + 1].second;
  const float t2 = t * t, t3 = t2 * t;
  return 0.5f * ((2.0f * v1) + (-v0 + v2) * t +
                 (2.0f * v0 - 5.0f * v1 + 4.0f * v2 - v3) * t2 +
                 (-v0 + 3.0f * v1 - 3.0f * v2 + v3) * t3);
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
