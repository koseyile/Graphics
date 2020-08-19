#ifndef CHARACTER_PBR_INCLUDED
#define CHARACTER_PBR_INCLUDED

#include "Common_Macros.hlsl"  

half _PBRBlendFactor;

// PBR and Toon
struct HybridAttributes
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

struct HybridVaryings
{
    float4 position : POSITION;
    half4 color : COLOR0;
    float2 texcoord : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 posWS : TEXCOORD2;
    float4 scrpos : TEXCOORD3;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
#ifdef _NORMALMAP
    float4 tangentWS                : TEXCOORD5;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS                : TEXCOORD6;

#ifdef RECEIVE_SHADOW
    float4 shadowCoord : TEXCOORD7;
#endif
#ifdef ENABLE_MATCAP
    half2 matcapUV : TEXCOORD8;
#ifdef ENABLE_MATCAP_NROMAL_MAP
    half3 tspace0 : TEXCOORD9;
    half3 tspace1 : TEXCOORD10;
    half3 tspace2 : TEXCOORD11;
#endif
#endif
   
    half2 diff : COLOR1;
};

HybridVaryings vertWithPBR(HybridAttributes attribute)
{
    HybridVaryings varying = (HybridVaryings)0;

    varying.position = TransformObjectToHClip(attribute.vertex.xyz);
    varying.color = attribute.color;
    float4 objPos = mul(unity_ObjectToWorld, attribute.vertex);
    varying.posWS = objPos.xyz / objPos.w;
    //varying.texcoord = TRANSFORM_TEX(attribute.texcoord.xy, _MainTex);
    varying.texcoord = attribute.texcoord.xy;

    //Normal
    //varying.normal = normalize(TransformObjectToWorldNormal(attribute.normal));
    varying.normal = (TransformObjectToWorldNormal(attribute.normal));

#if defined(ENABLE_MATCAP_NROMAL_MAP) && defined(ENABLE_MATCAP)
    calcTBNMatrix(attribute.normal, attribute.tangent, varying.tspace0, varying.tspace1, varying.tspace2);
#endif
    //Diffuse
    // calculate diffuse factor
#ifdef FRONT_FACE_LIGHT
    float3 mainLightDir = _VirtualLightDir;
#else
    float3 mainLightDir = _MainLightPosition.xyz;
#endif

#ifdef FACE_MAP
    float3x3 matrixWithoutTransport;
    matrixWithoutTransport[0] = unity_WorldToObject[0].xyz;
    matrixWithoutTransport[1] = unity_WorldToObject[1].xyz;
    matrixWithoutTransport[2] = unity_WorldToObject[2].xyz;
    float3 lightDirLocal = mul(matrixWithoutTransport, mainLightDir);
    varying.diff.x = (atan(lightDirLocal.x / lightDirLocal.z)) / PI;
    varying.diff.y = (atan(lightDirLocal.y / lightDirLocal.z)) / PI;
    varying.diff = varying.diff * 2.0f + 1.0f;
#else
    varying.diff.x = diffuse_factor(varying.normal, mainLightDir);
#endif
#ifdef RECEIVE_SHADOW
    varying.shadowCoord = GetShadowCoord(varying.posWS);
#endif
    //OUTPUT_SH(varying.normal, varying.vertexSH);

#if defined(ENABLE_MATCAP_NROMAL_MAP) && defined(ENABLE_MATCAP)
    CalculateMatcapUV(varying.normal, varying.matcapUV);
#endif

    if (_UsingDitherAlpha)
    {
        varying.scrpos = ComputeScreenPos(varying.position);
        varying.scrpos.z = _DitherAlpha;
    }

    VertexNormalInputs normalInput = GetVertexNormalInputs(attribute.normal, attribute.tangent);
#ifdef _NORMALMAP
    real sign = attribute.tangent.w * GetOddNegativeScale();
    varying.tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
    float3 viewDirWS = GetCameraPositionWS() - varying.posWS;
    varying.viewDirWS = viewDirWS;

    //OUTPUT_SH(normalInput.normalWS.xyz, varying.vertexSH);
    varying.vertexSH = max(half3(0, 0, 0), SampleSH(normalInput.normalWS));
    return varying;
} // End of vert

half4 fragBlendWithPBR(HybridVaryings varying) : COLOR
{
    ToonVaryings toonVaryings;
    toonVaryings.position = varying.position;
    toonVaryings.color = varying.color;
    toonVaryings.texcoord = varying.texcoord;
    toonVaryings.normal = varying.normal;
    toonVaryings.posWS = varying.posWS;
    toonVaryings.scrpos = varying.scrpos;
#ifdef RECEIVE_SHADOW
    toonVaryings.shadowCoord = varying.shadowCoord;
#endif
#ifdef ENABLE_MATCAP
    toonVaryings.matcapUV = varying.matcapUV;
#ifdef ENABLE_MATCAP_NROMAL_MAP
    toonVaryings.tspace0 = varying.tspace0;
    toonVaryings.tspace1 = varying.tspace1;
    toonVaryings.tspace2 = varying.tspace2;
#endif
#endif
    toonVaryings.diff = varying.diff;
    half4 toonColor = ToonShading(toonVaryings);

    // PBR部分
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(varying.texcoord, surfaceData);

    Varyings varyingPBR;
    varyingPBR.uv = varying.texcoord;
#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    varyingPBR.positionWS = varying.posWS;
#endif
    varyingPBR.normalWS = varying.normal;
#ifdef _NORMALMAP
    varyingPBR.tangentWS = varying.tangentWS;
#endif
    varyingPBR.viewDirWS = varying.viewDirWS;
    varyingPBR.fogFactorAndVertexLight = half4(0, 0, 0, 0);
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    varyingPBR.shadowCoord = varying.shadowCoord;
#endif
    varyingPBR.positionCS = varying.position;
#ifdef LIGHTMAP_ON
    varyingPBR.lightmapUV = float2(0, 0);
#else
    //varyingPBR.vertexSH = varying.vertexSH;
    varyingPBR.vertexSH = float3(0, 0, 0);
#endif
    InputData inputData;
    InitializeInputData(varyingPBR, surfaceData.normalTS, inputData);
    half4 colorPBR = UniversalFragmentPBR(inputData,
        surfaceData.albedo,
        surfaceData.metallic,
        surfaceData.specular,
        surfaceData.smoothness,
        surfaceData.occlusion,
        surfaceData.emission,
        surfaceData.alpha);
    colorPBR.a = OutputAlpha(colorPBR.a);
    colorPBR.a = Max3(colorPBR.r, colorPBR.g, colorPBR.b);

    //colorPBR.rgb = varying.vertexSH;
    return lerp(toonColor, colorPBR, _PBRBlendFactor);
} // End of frag

#endif // CHARACTER_PBR_INCLUDED
