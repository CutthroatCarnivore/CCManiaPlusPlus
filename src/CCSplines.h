#ifndef CC_SPLINES_H
#define CC_SPLINES_H

// CC fork: NotITG per-column splines (Player:SetXSpline etc.).
// A spline is up to 40 points (offset, value) per column. "offset" is how far
// the arrow is from the receptors in percent of an arrow (100 = 64 px);
// "value" is in the matching mod's units (x/y/z: percent of an arrow,
// rotations: degrees, size: like Mini, tiny: like Tiny, stealth: like Stealth,
// skew: like NoteSkew).

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

#endif
