#ifndef CC_SHADER_H
#define CC_SHADER_H

#include <cstdint>
#include <map>
#include <string>
#include <vector>

struct lua_State;
class Actor;
class RageTexture;

// CC fork: NotITG-style GLSL shader attached to an actor.
// NotITG contract: GLSL 1.20; built-in uniforms time, resolution,
// textureSize, imageSize, sampler0; varyings textureCoord, imageCoord, color.
class CCShader {
 public:
  ~CCShader();
  void SetFiles(const std::string& sVertFile, const std::string& sFragFile);
  // iComps > 0: v holds an array of iComps-wide elements (uniformNfv).
  void SetUniform(const std::string& sName, const std::vector<float>& v,
                  int iComps = 0);
  void SetUniformInt(const std::string& sName, int i);
  void SetUniformTexture(const std::string& sName, RageTexture* pTex);
  // Bind for drawing pActor (pTex = the actor's texture, may be null).
  void Begin(RageTexture* pTex);
  void End();
  bool IsUsable() const { return !m_sFrag.empty() || !m_sVert.empty(); }
  void PushSelf(lua_State* L);

  // Shaders live until program exit: Lua can hold raw pointers to them.
  static CCShader* Create();

 private:
  CCShader() {}
  std::string m_sVert, m_sFrag;
  uintptr_t m_hProgram = 0;
  bool m_bDirty = true;
  bool m_bFailed = false;
  uintptr_t m_hPrevious = 0;
  std::map<std::string, std::vector<float>> m_Uniforms;
  std::map<std::string, int> m_UniformComps;
  std::map<std::string, int> m_IntUniforms;
  std::map<std::string, RageTexture*> m_TexUniforms;
};

#endif
