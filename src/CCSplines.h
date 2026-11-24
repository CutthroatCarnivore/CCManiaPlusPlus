#ifndef CC_SPLINES_H
#define CC_SPLINES_H

#include <utility>
#include <vector>

// CC fork: NotITG per-column splines (Player:SetXSpline etc.).
// A spline is up to 40 points (offset, value) per column. "offset" is how far
// the arrow is from the receptors in percent of an arrow (100 = 64 px);
// "value" is in the matching mod's units (x/y/z: percent of an arrow,
// rotations: degrees, size: like Mini, tiny: like Tiny, stealth: like Stealth,
// skew: like NoteSkew).

class PlayerState;
// Storage slot for a player's splines/gradients: 0-1 for players 1-2, 2-7 for
// NotITG's extra players 3-8 (they share PlayerNumber 1, so the number alone
// would mix their splines with player 1's).
int CCSplineSlot(const PlayerState* ps);

enum CCSplineType {
  CCSP_X, CCSP_Y, CCSP_Z, CCSP_ROTX, CCSP_ROTY, CCSP_ROTZ,
  CCSP_SIZE, CCSP_SKEW, CCSP_STEALTH, CCSP_TINY, NUM_CCSP
};

// Sets point `index` (0-39) of a spline; column -1 = every column.
void CCSplineSetPoint(int pn, int type, int index, int column, float value,
                      float offset);
// Removes every point of one spline type for a column (-1 = every column).
void CCSplineReset(int pn, int type, int column);
// Removes all splines (new song).
void CCSplineResetAll();
// True when this player has any spline point at all (fast path).
bool CCSplineAny(int pn);
// Value of a spline at an arrow's y offset (pixels); 0 when unset.
float CCSplineEval(int pn, int type, int column, float y_offset_px);


// CC fork: NotITG arrow / stealth / path gradients (Player:SetArrowGradientPoint
// etc.). Offsets are in arrows from the receptors (1 = 64 px); colors 0-1.
enum CCGradientType { CCGR_ARROW, CCGR_STEALTH, CCGR_PATH, NUM_CCGR };
void CCGradientSetNum(int pn, int type, int column, int num);
void CCGradientSetPoint(int pn, int type, int point, int column, float offset);
void CCGradientSetColor(int pn, int type, int point, int column, float r,
                        float g, float b, float a);
// Fills rgba and returns true when the column has a gradient.
bool CCGradientEval(int pn, int type, int column, float y_offset_px,
                    float out_rgba[4]);
void CCGradientResetAll();

// CC fork: NotITG Player:SetNoteTypeMults({{beat, mult}, ...}): from `beat`
// on, a note's quantization color is picked as if its distance from `beat`
// were multiplied by `mult` (Schall, Clock Atelier, ILIAS, Foolish Hero).
void CCSetNoteTypeMults(int pn, const std::vector<std::pair<float, float>>& v);
float CCNoteTypeBeat(int pn, float beat);
// CC fork: Player:SetArrowPathBlendMode('add' / 'normal').
void CCSetArrowPathAdd(int pn, bool add);
bool CCArrowPathAdd(int pn);
// Clears note type mults and path blend modes (new song).
void CCNoteTypeResetAll();

#endif
