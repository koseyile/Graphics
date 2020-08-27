#ifndef CHARACTER_PBR_INCLUDED
#define CHARACTER_PBR_INCLUDED

#include "Common_Macros.hlsl"  

half _PBRBlendFactor;

// PBR和卡通渲染混合渲染的顶点属性
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

#ifndef _RECEIVE_SHADOWS_OFF
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


half3 ToonDiffuseInPBR(half factor,
    half t1,
    half t2,
    half3 baseTexColor,
    half3 mainLightColor,
    half shadowAttenuation)
{
    half3 diffColor = half3(1.0f, 1.0f, 1.0f).rgb;

    half D = t1 * t2;
    half threshold = 0;

    if (less(D, 0.09f))
    {
        threshold = (factor + D) * 0.5f;
        half3 shadowColor = less(threshold, _SecondShadow) ? _SecondShadowMultColor : _FirstShadowMultColor;
        diffColor = baseTexColor * shadowColor;
    }
    else
    {
        // mapping [0.1, 0.5) to [-0.1, 0.5)
        if (greaterEqual(D, 0.5f)) D = D * 1.2f - 0.1f;
        else D = D * 1.25f - 0.125f;

        threshold = (factor + D) * 0.5f;
#ifdef DIFFUSE_RAMP
        half ramp = tex2D(_RampTex, float2(saturate(threshold - _LightArea), 0.5)).r;
        half3 shadowColor = lerp(_FirstShadowMultColor, mainLightColor, ramp);
#else
        half ramp = sigmoid(threshold, _LightArea, _ShadowFeather);
        half3 shadowColor = lerp(_FirstShadowMultColor, mainLightColor, ramp);
#endif
        shadowColor *= shadowAttenuation < 0.5h ? _ShadowDarkness : 1.0h;
        diffColor = baseTexColor * shadowColor;
    }
    return diffColor;
}

half3 LightingPhysicallyBasedWithToon(BRDFData brdfData,
    half3 lightColor,
    half3 lightDirectionWS,
    half lightAttenuation,
    half3 normalWS,
    half3 viewDirectionWS,
    bool isMainLight,
    half t1,
    half t2)
{
    half factor = saturate(diffuse_factor(normalWS, lightDirectionWS));
    brdfData.diffuse = RampBaseColor(brdfData.diffuse, _RevertTonemapping);
    brdfData.diffuse = ToonDiffuseInPBR(factor, t1, t2, brdfData.diffuse, lightColor, lightAttenuation);
    return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS, isMainLight);
}

half4 UniversalFragmentPBRWithToon(InputData inputData,
    half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha,
    half t1, half t2)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingPhysicallyBasedWithToon(brdfData, mainLight.color, mainLight.direction,
        mainLight.distanceAttenuation * mainLight.shadowAttenuation,
        inputData.normalWS, inputData.viewDirectionWS, true, t1, t2);

#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
        color += LightingPhysicallyBasedWithToon(brdfData, light.color, light.direction,
            light.distanceAttenuation * light.shadowAttenuation,
            inputData.normalWS, inputData.viewDirectionWS, false, t1, t2);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color += inputData.vertexLighting * brdfData.diffuse;
#endif

    color += emission;
    return half4(color, alpha);
    //return half4(color, _BloomFactor);
}

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
#ifndef _RECEIVE_SHADOWS_OFF
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

    OUTPUT_SH(normalInput.normalWS.xyz, varying.vertexSH);
    //varying.vertexSH = max(half3(0, 0, 0), SampleSH(normalInput.normalWS));
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
#ifndef _RECEIVE_SHADOWS_OFF
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
    half4 toonColor = ToonShading(toonVaryings, 1);

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


half4 fragHybridPBR(HybridVaryings varying) : COLOR
{
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
    varyingPBR.vertexSH = varying.vertexSH;
#endif
    InputData inputData;
    InitializeInputData(varyingPBR, surfaceData.normalTS, inputData);

    half3 tex_Light_Color = tex2DRGB(_LightMapTex, varying.texcoord).rgb;
    half4 colorPBR = UniversalFragmentPBRWithToon(inputData,
        surfaceData.albedo,
        surfaceData.metallic,
        surfaceData.specular,
        surfaceData.smoothness,
        surfaceData.occlusion,
        surfaceData.emission,
        surfaceData.alpha,
        varying.color.r,
        tex_Light_Color.g);

#ifdef ENABLE_MATCAP
    half3 matcapColor;
#ifdef ENABLE_MATCAP_NROMAL_MAP
    ApplyMatcap(varying.texcoord, varying.tspace0, varying.tspace1, varying.tspace2, matcapColor);
#else
    ApplyMatcap(varying.matcapUV, matcapColor);
#endif
    colorPBR.rgb += matcapColor;
#endif

#ifdef RIM_GLOW
#if defined(_ADDITIONAL_LIGHTS) && defined(RIM_GLOW_WITH_LIGHT)
    colorPBR = rgWithAllLights(colorPBR,
        varying.posWS,
        normalize(varying.normal),
        normalize(_WorldSpaceCameraPos.xyz - varying.posWS));
#else
    //outColor.rgb = rgFrag(outColor.rgb, N, V);
    colorPBR.rgb = rgFragEx(colorPBR.rgb, normalize(varying.normal), normalize(_WorldSpaceCameraPos.xyz - varying.posWS), varying.diff.x, _LightArea);
#endif
#endif

    // 根据_DitherAlpha的值来做棋盘格式渐隐渐出
    if (_UsingDitherAlpha)
        dither_clip(varying.scrpos, varying.scrpos.z);
    return colorPBR;
}

half4 fragTransparentOnlyAlpha(HybridVaryings varying) : COLOR
{
    half4 outputColor;
    half4 albedoAlpha = SampleAlbedoAlpha(varying.texcoord, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outputColor.a = _BloomFactor * Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
    return outputColor;
}
#endif // CHARACTER_PBR_INCLUDED
