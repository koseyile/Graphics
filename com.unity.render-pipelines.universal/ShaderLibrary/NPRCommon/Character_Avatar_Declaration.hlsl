#ifndef CHARACTER_AVATAR_DECLARATION_INCLUDED
#define CHARACTER_AVATAR_DECLARATION_INCLUDED

#include "Common_Macros.hlsl"  

sampler2D _LightMapTex;
sampler2D _RampTex;

half _LightArea;
half _SecondShadow;
half3 _FirstShadowMultColor;
half3 _SecondShadowMultColor;
half _ShadowFeather;
half _ShadowFeatherCenter;
#ifdef _ADDITIONAL_LIGHTS
half _AdditionalLightFactor;
#endif
half _Shininess;
half _SpecMulti;
half _ShadowDarkness;
half3 _LightSpecColor;

half4 _EmissiveColor;
sampler2D _EmissiveTex;

half _Opaqueness;

half4 _LightColor0;
half _BloomFactor;
half _RevertTonemapping;

half _FadeDistance;
half _FadeOffset;

float _UsingDitherAlpha;
float _DitherAlpha;
#ifdef FRONT_FACE_LIGHT
float3 _CharacterOrientation;
float3 _VirtualLightDir;
#endif
#ifdef FACE_MAP
sampler2D _FaceMap;
#endif
#ifdef ENABLE_MATCAP
sampler2D _Matcap;
half4 _MatcapColor;
#ifdef ENABLE_MATCAP_NROMAL_MAP
sampler2D _MatcapNormalMap;
uniform float4 _MatcapNormalMap_ST;
#endif
#endif

struct ToonAttributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float4 texcoord : TEXCOORD0;
    // R通道控制阴影的区域
    // G和B通道控制勾线
    // 其中G通道控制XY平面的宽度，B通道控制Z方向的offset
    half4 color : COLOR;
};

struct ToonVaryings
{
    float4 position : POSITION;
    half4 color : COLOR0;
    float2 texcoord : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 posWS : TEXCOORD2;
    float4 scrpos : TEXCOORD3;
#ifndef _RECEIVE_SHADOWS_OFF
    float4 shadowCoord : TEXCOORD4;
#endif
#ifdef ENABLE_MATCAP
    half2 matcapUV : TEXCOORD5;
#ifdef ENABLE_MATCAP_NROMAL_MAP
    half3 tspace0 : TEXCOORD6;
    half3 tspace1 : TEXCOORD7;
    half3 tspace2 : TEXCOORD8;
#endif
#endif
    //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
    half2 diff : COLOR1;
};

#endif // CHARACTER_AVATAR_DECLARATION_INCLUDED
