#ifndef CC_NOTITG_MODS_H
#define CC_NOTITG_MODS_H

#include <string>

// CC fork: NotITG modifiers that stock ITGmania lacks.
// To add one: add a line here, then read it in ArrowEffects/NoteDisplay.
// Every mod also exists per column as "<name><col>" (NotITG numbering
// while a NotITG modfile is loaded, see CCColBase()).
#define CC_NOTITG_MODS(X) \
  X(ROTATIONX, "rotationx") \
  X(ROTATIONY, "rotationy") \
  X(ROTATIONZ, "rotationz") \
  X(PLAYERX, "x") \
  X(PLAYERY, "y") \
  X(PLAYERZ, "z") \
  X(PLAYERSKEWX, "skewx") \
  X(PLAYERSKEWY, "skewy") \
  X(TINYX, "tinyx")       \
  X(TINYY, "tinyy")       \
  X(TINYZ, "tinyz")       \
  X(NOTESKEW, "noteskew") \
  X(NOTESKEWX, "noteskewx") \
  X(NOTESKEWY, "noteskewy") \
  X(ARROWPATH, "arrowpath") \
  X(ARROWPATHGIRTH, "arrowpathgirth") \
  X(ARROWPATHWIDTH, "arrowpathwidth") \
  X(ARROWPATHDRAWSIZE, "arrowpathdrawsize") \
  X(ARROWPATHDRAWSIZEBACK, "arrowpathdrawsizeback") \
  X(ZOOM, "zoom")         \
  X(ZOOMX, "zoomx")       \
  X(ZOOMY, "zoomy")       \
  X(ZOOMZ, "zoomz")       \
  X(HIDENOTEFLASH, "hidenoteflash") \
  X(HIDENOTEFLASHES, "hidenoteflashes") \
  X(BUMPYY, "bumpyy")     \
  X(BUMPYYOFFSET, "bumpyyoffset") \
  X(BUMPYYPERIOD, "bumpyyperiod") \
  X(BUMPYZ, "bumpyz")     \
  X(BUMPYZOFFSET, "bumpyzoffset") \
  X(BUMPYZPERIOD, "bumpyzperiod") \
  X(CUBICX, "cubicx")     \
  X(CUBICY, "cubicy")     \
  X(CUBICZ, "cubicz")     \
  X(DRUNKY, "drunky")     \
  X(DRUNKYOFFSET, "drunkyoffset") \
  X(DRUNKYPERIOD, "drunkyperiod") \
  X(DRUNKYSPEED, "drunkyspeed") \
  X(HIDEMINES, "hidemines") \
  X(SCROLLSPEEDMULT, "scrollspeedmult") \
  X(STEALTHGLOWRED, "stealthglowred") \
  X(STEALTHGLOWGREEN, "stealthglowgreen") \
  X(STEALTHGLOWBLUE, "stealthglowblue") \
  X(HOLDGIRTH, "holdgirth") \
  X(HOLDTINY, "holdtiny") \
  X(APPROACHTYPE, "approachtype") \
  X(ARROWCULL, "arrowcull") \
  X(ARROWPATHDRAWDISTANCE, "arrowpathdrawdistance") \
  X(ARROWPATHDRAWDISTANCEBACK, "arrowpathdrawdistanceback") \
  X(ARROWPATHDRAWSIZEFRONT, "arrowpathdrawsizefront") \
  X(ARROWPATHGRAIN, "arrowpathgrain") \
  X(ARROWPATHGRANULATE, "arrowpathgranulate") \
  X(ARROWPATHSIZE, "arrowpathsize") \
  X(ATTENUATEXOFFSET, "attenuatexoffset") \
  X(BEATSIZE, "beatsize") \
  X(CENTEREDPATH, "centeredpath") \
  X(CENTERED2, "centered2") \
  X(COLTWIRL, "cc_coltwirl") \
  X(COLROLL, "cc_colroll") \
  X(COLBOOST, "cc_colboost") \
  X(COLBRAKE, "cc_colbrake") \
  X(ORIENT, "orient") \
  X(ORIENTOFFSET, "orientoffset") \
  X(CONFUSIONZOFFSET, "confusionzoffset") \
  X(CUBICXOFFSET, "cubicxoffset") \
  X(CUBICZOFFSET, "cubiczoffset") \
  X(DISABLEMINES, "disablemines") \
  X(DRAWDISTANCE, "drawdistance") \
  X(DRAWDISTANCEBACK, "drawdistanceback") \
  X(DRAWDISTANCEFRONT, "drawdistancefront") \
  X(DRAWSIZEFRONT, "drawsizefront") \
  X(DRUNKSIZE, "drunksize") \
  X(DRUNKSPACING, "drunkspacing") \
  X(DRUNKYSIZE, "drunkysize") \
  X(DRUNKYSPACING, "drunkyspacing") \
  X(DRUNKZSIZE, "drunkzsize") \
  X(DRUNKZSPACING, "drunkzspacing") \
  X(GAYHOLDS, "gayholds") \
  X(GLITCHYTAN, "glitchytan") \
  X(GRAIN, "grain") \
  X(HALGUN, "halgun") \
  X(HIDEHOLDS, "hideholds") \
  X(HIDEFIELD, "hide") \
  X(HOLDSTEALTH, "holdstealth") \
  X(LONGBOY, "longboy") \
  X(LONGBOYS, "longboys") \
  X(LONGHOLDS, "longholds") \
  X(MINESTEALTH, "minestealth") \
  X(MOVEX, "movex") \
  X(MOVEY, "movey") \
  X(MOVEZ, "movez") \
  X(PLANNEDOMSPEED, "plannedomspeed") \
  X(RECEPTORZBUFFER, "receptorzbuffer") \
  X(REVERSETYPE, "reversetype") \
  X(SINCLIP, "sinclip") \
  X(SPIRALHOLDS, "spiralholds") \
  X(SPIRALX, "spiralx") \
  X(SPIRALXOFFSET, "spiralxoffset") \
  X(SPIRALXPERIOD, "spiralxperiod") \
  X(SPIRALY, "spiraly") \
  X(SPIRALYOFFSET, "spiralyoffset") \
  X(SPIRALYPERIOD, "spiralyperiod") \
  X(SPIRALZ, "spiralz") \
  X(SPIRALZOFFSET, "spiralzoffset") \
  X(SPIRALZPERIOD, "spiralzperiod") \
  X(SPLINEXRESET, "splinexreset") \
  X(SPLINEXTYPE, "splinextype") \
  X(SPLINEYRESET, "splineyreset") \
  X(SPLINEYTYPE, "splineytype") \
  X(SPLINEZRESET, "splinezreset") \
  X(STEALTHGB, "stealthgb") \
  X(STEALTHGG, "stealthgg") \
  X(STEALTHGR, "stealthgr") \
  X(STRAIGHTHOLDS, "straightholds") \
  X(TANBUMPYY, "tanbumpyy") \
  X(TANDRUNKSIZE, "tandrunksize") \
  X(TIMING, "timing") \
  X(TIPSYSPACING, "tipsyspacing") \
  X(UNBOUNDEDREVERSE, "unboundedreverse") \
  X(WAVEOFFSET, "waveoffset") \
  X(WIREFRAME, "wireframe") \
  X(WIREFRAMEGIRTH, "wireframegirth")

enum CCMod {
#define CCX(e, n) CCMOD_##e,
  CC_NOTITG_MODS(CCX)
#undef CCX
  NUM_CCMODS
};

static const int CC_MAX_COLS = 16;

extern const char* const g_szCCModNames[NUM_CCMODS];
// Value a mod has when "off". 0 for most; 1 (=100%) for NotITG's zoom mods.
inline float CCModNeutral(int m) {
  return (m == CCMOD_ZOOM || m == CCMOD_ZOOMX || m == CCMOD_ZOOMY ||
          m == CCMOD_ZOOMZ || m == CCMOD_SCROLLSPEEDMULT ||
          m == CCMOD_STEALTHGLOWRED || m == CCMOD_STEALTHGLOWGREEN ||
          m == CCMOD_STEALTHGLOWBLUE) ? 1.0f : 0.0f;
}
// Returns the CCMod index for a lowercase mod name, or -1.
int CCModFromName(const std::string& sName);

#endif
