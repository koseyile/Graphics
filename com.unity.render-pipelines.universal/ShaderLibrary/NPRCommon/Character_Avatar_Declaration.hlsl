#ifndef CHARACTER_AVATAR_DECLARATION_INCLUDED
#define CHARACTER_AVATAR_DECLARATION_INCLUDED

#include "Common_Macros.hlsl"  

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
#ifdef RECEIVE_SHADOW
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
