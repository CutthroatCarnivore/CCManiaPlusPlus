#ifndef CC_NOTITG_MODS_H
#define CC_NOTITG_MODS_H

#include <string>

// CC fork: NotITG modifiers that stock ITGmania lacks.
// To add one: add a line here, then read it in ArrowEffects/NoteDisplay.
// Every mod also exists per column as "<name><col>" (NotITG numbering
// while a NotITG modfile is loaded, see CCColBase()).
#define CC_NOTITG_MODS(X) \
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
  X(ZOOMZ, "zoomz")

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
          m == CCMOD_ZOOMZ) ? 1.0f : 0.0f;
}
// Returns the CCMod index for a lowercase mod name, or -1.
int CCModFromName(const std::string& sName);

#endif
