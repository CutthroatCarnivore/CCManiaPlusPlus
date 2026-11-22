#include "global.h"
#include "CCShader.h"

#include <memory>
#include <vector>

#include "LuaBinding.h"
#include "LuaManager.h"
#include "RageDisplay.h"
#include "RageLog.h"
#include "RageTexture.h"
#include "RageTimer.h"

static std::vector<std::unique_ptr<CCShader>>& AllShaders() {
  static std::vector<std::unique_ptr<CCShader>> v;
  return v;
}

CCShader* CCShader::Create() {
  AllShaders().emplace_back(new CCShader);
  return AllShaders().back().get();
}

CCShader::~CCShader() {
  if (m_hProgram != 0 && DISPLAY != nullptr) {
    DISPLAY->CCDeleteShader(m_hProgram);
  }
}

void CCShader::SetFiles(const std::string& sVert, const std::string& sFrag) {
  if (!sVert.empty()) m_sVert = sVert;
  if (!sFrag.empty()) m_sFrag = sFrag;
  m_bDirty = true;
  m_bFailed = false;
}

void CCShader::SetUniform(const std::string& sName, const std::vector<float>& v) {
  m_Uniforms[sName] = v;
}
void CCShader::SetUniformInt(const std::string& sName, int i) {
  m_IntUniforms[sName] = i;
}
void CCShader::SetUniformTexture(const std::string& sName, RageTexture* pTex) {
  m_TexUniforms[sName] = pTex;
}

void CCShader::Begin(RageTexture* pTex) {
  m_hPrevious = DISPLAY->CCGetActiveShader();
  if (m_bDirty && !m_bFailed) {
    if (m_hProgram != 0) {
      DISPLAY->CCDeleteShader(m_hProgram);
    }
    m_hProgram = DISPLAY->CCCompileShader(m_sVert, m_sFrag);
    m_bFailed = (m_hProgram == 0);
    m_bDirty = false;
  }
  if (m_hProgram == 0) {
    return;
  }
  DISPLAY->CCSetActiveShader(m_hProgram);
  float t[1] = {static_cast<float>(RageTimer::GetTimeSinceStart())};
  DISPLAY->CCSetUniform(m_hProgram, "time", 1, t);
  const ActualVideoModeParams vmp = DISPLAY->GetActualVideoModeParams();
  float res[2] = {static_cast<float>(vmp.width), static_cast<float>(vmp.height)};
  DISPLAY->CCSetUniform(m_hProgram, "resolution", 2, res);
  float ts[2] = {1, 1}, is[2] = {1, 1};
  if (pTex != nullptr) {
    ts[0] = static_cast<float>(pTex->GetTextureWidth());
    ts[1] = static_cast<float>(pTex->GetTextureHeight());
    is[0] = static_cast<float>(pTex->GetImageWidth());
    is[1] = static_cast<float>(pTex->GetImageHeight());
  }
  DISPLAY->CCSetUniform(m_hProgram, "textureSize", 2, ts);
  DISPLAY->CCSetUniform(m_hProgram, "imageSize", 2, is);
  DISPLAY->CCSetUniformInt(m_hProgram, "sampler0", 0);
  for (const auto& u : m_Uniforms) {
    DISPLAY->CCSetUniform(
        m_hProgram, u.first, static_cast<int>(u.second.size()), u.second.data());
  }
  for (const auto& u : m_IntUniforms) {
    DISPLAY->CCSetUniformInt(m_hProgram, u.first, u.second);
  }
  int unit = 1;
  for (const auto& u : m_TexUniforms) {
    if (u.second != nullptr && unit < 4) {
      DISPLAY->CCBindTextureUnit(unit, u.second->GetTexHandle());
      DISPLAY->CCSetUniformInt(m_hProgram, u.first, unit);
      ++unit;
    }
  }
}

void CCShader::End() {
  if (m_hProgram != 0) {
    DISPLAY->CCSetActiveShader(m_hPrevious);
  }
}

// Lua ------------------------------------------------------------------------
class LunaCCShader : public Luna<CCShader> {
 public:
  static int SetUniformN(T* p, lua_State* L, int n) {
    std::vector<float> v;
    for (int i = 0; i < n; ++i) {
      v.push_back(FArg(2 + i));
    }
    p->SetUniform(SArg(1), v);
    COMMON_RETURN_SELF;
  }
  static int uniform1f(T* p, lua_State* L) { return SetUniformN(p, L, 1); }
  static int uniform2f(T* p, lua_State* L) { return SetUniformN(p, L, 2); }
  static int uniform3f(T* p, lua_State* L) { return SetUniformN(p, L, 3); }
  static int uniform4f(T* p, lua_State* L) { return SetUniformN(p, L, 4); }
  static int uniform1i(T* p, lua_State* L) {
    p->SetUniformInt(SArg(1), IArg(2));
    COMMON_RETURN_SELF;
  }
  // uniformNfv(name, {..}) -- first N values of the table (arrays: TODO)
  static int SetUniformFV(T* p, lua_State* L, int n) {
    std::vector<float> v;
    if (lua_istable(L, 2)) {
      for (int i = 1; i <= n; ++i) {
        lua_rawgeti(L, 2, i);
        v.push_back(static_cast<float>(lua_tonumber(L, -1)));
        lua_pop(L, 1);
      }
    }
    p->SetUniform(SArg(1), v);
    COMMON_RETURN_SELF;
  }
  static int uniform1fv(T* p, lua_State* L) { return SetUniformFV(p, L, 1); }
  static int uniform2fv(T* p, lua_State* L) { return SetUniformFV(p, L, 2); }
  static int uniform3fv(T* p, lua_State* L) { return SetUniformFV(p, L, 3); }
  static int uniform4fv(T* p, lua_State* L) { return SetUniformFV(p, L, 4); }
  static int uniformTexture(T* p, lua_State* L) {
    RageTexture* pTex = Luna<RageTexture>::check(L, 2);
    p->SetUniformTexture(SArg(1), pTex);
    COMMON_RETURN_SELF;
  }
  LunaCCShader() {
    ADD_METHOD(uniform1f);
    ADD_METHOD(uniform2f);
    ADD_METHOD(uniform3f);
    ADD_METHOD(uniform4f);
    ADD_METHOD(uniform1i);
    ADD_METHOD(uniform1fv);
    ADD_METHOD(uniform2fv);
    ADD_METHOD(uniform3fv);
    ADD_METHOD(uniform4fv);
    ADD_METHOD(uniformTexture);
  }
};
LUA_REGISTER_CLASS(CCShader)
