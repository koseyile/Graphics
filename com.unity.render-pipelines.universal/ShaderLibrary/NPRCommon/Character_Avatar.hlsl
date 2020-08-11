#ifndef CHARACTER_AVATAR_INCLUDED
#define CHARACTER_AVATAR_INCLUDED

#include "Common_Macros.hlsl"  

half4 _BaseColor;
sampler2D _MainTex;
sampler2D _MainTex_Alpha;
float4 _MainTex_ST;
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


struct Attributes
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

struct Varyings
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

// Lighting functions
half diffuse_factor(half3 N, half3 L)
{
    // 由于某些精度问题，这里乘0.4975，而不是0.5
    return dot(N, L) * 0.4975f + 0.5f;
    //return dot(N, L);
}

half specular_factor(half3 N, half3 H, half shininess)
{
    return pow(max(dot(N, H), 0), shininess);
}

half rim_factor(half3 N, half3 V, half shininess)
{
    return pow(1.0f - max(0, dot(N, V)), shininess);
}

half front_factor(half3 N, half3 V, half shininess)
{
    return pow(max(0, dot(N, V)), shininess);
}

float sigmoid(float x, float center, float sharp)
{
    float s;
    s = 1 / (1 + pow(100000, (-3 * sharp * (x - center))));
    return s;
}


half3 complex_toon_diffuse(half factor, half t1, half t2, half3 baseTexColor)
{
    half3 diffColor = half3(1.0f, 1.0f, 1.0f).rgb;

    half D = t1 * t2;
    half threshold = 0;

    if (less(D, 0.09f))
    {
        threshold = (factor + D) * 0.5f;
        // in dark shadow
        if (less(threshold, _SecondShadow))
        {
            diffColor = baseTexColor * _SecondShadowMultColor;
            //diffColor = half3(1, 0, 0);
        }
        // in light shadow
        else
        {
            diffColor = baseTexColor * _FirstShadowMultColor;
            //diffColor = half3(0, 1, 0);
        }
    }
    else
    {
        // mapping [0.1, 0.5) to [-0.1, 0.5)
        if (greaterEqual(D, 0.5f)) D = D * 1.2f - 0.1f;
        else D = D * 1.25f - 0.125f;

        threshold = (factor + D) * 0.5f;

        // in light shadow
        if (less(threshold, _LightArea))
        {
            diffColor = baseTexColor * _FirstShadowMultColor;
            //diffColor = half3(0, 1, 0);
        }
        // in light
        else
        {
            diffColor = baseTexColor;
            //diffColor = half3(0, 0, 1);
        }

    }
    return diffColor;
}

//3阶：light, light shadow(_FirstShadowMultColor), dark shadow(_SecondShadowMultColor)
// 高光贴图的G通道乘以顶点色的R通道可以控制阴影的区域
half3 ToonDiffuse(half factor,
    half t1,
    half t2,
    half3 baseTexColor,
    half3 mainLightColor,
    half3 GI,
    half shadowAttenuation)
{
    half3 diffColor = half3(1.0f, 1.0f, 1.0f).rgb;

    half D = t1 * t2;
    half threshold = 0;

    if (less(D, 0.09f))
    {
        threshold = (factor + D) * 0.5f;
        half3 shadowColor = less(threshold, _SecondShadow) ? _SecondShadowMultColor : _FirstShadowMultColor + GI;
        diffColor = baseTexColor * shadowColor;
    }
    else
    {
        // mapping [0.1, 0.5) to [-0.1, 0.5)
        if (greaterEqual(D, 0.5f)) D = D * 1.2f - 0.1f;
        else D = D * 1.25f - 0.125f;

        threshold = (factor + D) * 0.5f;
        //threshold = factor;
        //threshold = smoothstep(_ShadowFeather - threshold, _ShadowFeather + threshold, threshold);
#ifdef DIFFUSE_RAMP
        half ramp = tex2D(_RampTex, float2(saturate(threshold - _LightArea), 0.5)).r;
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, ramp);
#else
        half w = sigmoid(threshold, _LightArea, _ShadowFeather);
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, w);
#endif
        //half3 shadowColor = less(threshold, _LightArea) ? _FirstShadowMultColor * GI : _MainLightColor.rgb;

        shadowColor *= shadowAttenuation < 0.5h ? _ShadowDarkness : 1.0h;
        diffColor = baseTexColor * shadowColor;
    }
    return diffColor;
}

half3 ToonDiffuseWithAdditionalLights(half factor,
    half t1,
    half t2,
    half3 baseTexColor,
    half3 mainLightColor,
    half3 additionalColor,
    half3 GI,
    half shadowAttenuation)
{
    half3 diffColor = half3(1.0f, 1.0f, 1.0f).rgb;

    half D = t1 * t2;
    half threshold = 0;

    if (less(D, 0.09f))
    {
        threshold = (factor + D) * 0.5f;
        half3 shadowColor = less(threshold, _SecondShadow) ? _SecondShadowMultColor : _FirstShadowMultColor + GI;
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
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, ramp);
        half3 lightColor = lerp(0, additionalColor, ramp);
#else
        half w = sigmoid(threshold, _LightArea, _ShadowFeather);
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, w);
        half3 lightColor = lerp(0, additionalColor, w);
#endif
        shadowColor *= shadowAttenuation < 0.5h ? _ShadowDarkness : 1.0h;
        diffColor = baseTexColor * shadowColor;
        diffColor += lightColor * baseTexColor;
    }
    return diffColor;
}

half3 simple_toon_diffuse(half factor, half t1, half t2, half3 baseTexColor)
{
    half D = t1 * t2;
    half threshold = (factor + D) * 0.5f;;
    half ramp = step(threshold, _LightArea);
    return lerp(baseTexColor, _FirstShadowMultColor * baseTexColor, ramp);
}

half3 complex_toon_specular(half3 N, half3 H, half threshold, half mask)
{
    half3 color;

    half s = specular_factor(N, H, _Shininess);

    if (greaterEqual(s, 1.0f - threshold))
    {
        color = _LightSpecColor.rgb * _SpecMulti * mask;

        // to debug
        //color = half3(_SpecMulti, 0, 0);
        //color = _LightSpecColor.rgb;

        //color = half3(1, 1, 0);
    }
    else
    {
        color = 0;
        //color = half3(1, 0, 1);
    }

    return color;
}

void CalculateMatcapUV(half3 N, out half2 matcapUV)
{
#ifdef ENABLE_MATCAP
    half3 normal = mul(UNITY_MATRIX_IT_MV, N);
    normal = normalize(normal);
    matcapUV.xy = normal.xy * 0.5f + 0.5f;
#endif
}

void ApplyMatcap(Varyings varying, out half3 color)
{
#ifdef ENABLE_MATCAP
#ifdef ENABLE_MATCAP_NROMAL_MAP
    float2 uv = TRANSFORM_TEX(varying.texcoord, _MatcapNormalMap);
    half3 normal = UnpackNormal(tex2D(_MatcapNormalMap, uv));
    normal = TangentToWorldNormal(normal, varying.tspace0, varying.tspace1, varying.tspace2);
    //float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
    normal = mul(UNITY_MATRIX_V, normal);
    //float3 viewNormal = (mul(UNITY_MATRIX_V, float4(lerp(i.normalDir, mul(normal, tangentTransform).rgb, _Is_NormalMapForMatCap), 0))).rgb;
    normal = normalize(normal);
    varying.matcapUV.xy = normal.xy * 0.5f + 0.5f;
#endif
    color = tex2D(_Matcap, varying.matcapUV).rgb * _MatcapColor;
#endif
}



Varyings vert(Attributes attribute)
{
    Varyings varying = (Varyings)0;

    varying.position = TransformObjectToHClip(attribute.vertex.xyz);
    varying.color = attribute.color;
    float4 objPos = mul(unity_ObjectToWorld, attribute.vertex);
    varying.posWS = objPos.xyz / objPos.w;
    //varying.texcoord = TRANSFORM_TEX(attribute.texcoord.xy, _MainTex);
    varying.texcoord = attribute.texcoord.xy;

    //Normal
    varying.normal = normalize(TransformObjectToWorldNormal(attribute.normal));

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

    return varying;
} // End of vert

half4 frag(Varyings varying) : COLOR
{
    half4 outColor = (float4)0;
    float2 mainUV = TRANSFORM_TEX(varying.texcoord, _MainTex);
    // 高光贴图的通道作用：
    // R通道：高光强度，控制高光的强度，当0时可以禁用
    // G通道：阴影阀值，它乘以顶点色的R通道可以控制阴影的区域
    // B通道：光滑度，镜面阈值；数值越大，高光越强。
    half3 tex_Light_Color = tex2DRGB(_LightMapTex, mainUV).rgb;

    half3 baseTexColor = tex2D(_MainTex, mainUV).rgb;
    baseTexColor = RampBaseColor(baseTexColor, _RevertTonemapping);
#ifdef RECEIVE_SHADOW
#ifdef NO_SELF_SHADOW
    Light mainLight = GetMainLight();
    mainLight.shadowAttenuation = MainLightRealtimeShadow(varying.shadowCoord);
#else
    Light mainLight = GetMainLight(varying.shadowCoord, varying.posWS);
#endif
#else
    Light mainLight = GetMainLight();
#endif
    // 无方向的light probe的全局光只作用于暗部
    half3 GI = SampleSH(half3(0, 0, 0));
    //GI *= PI * PI;

    half3 lightColor = (half3)0;
#ifdef _ADDITIONAL_LIGHTS
    if (_AdditionalLightFactor > 0.001f)
    {
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, varying.posWS);
            lightColor += light.color * light.distanceAttenuation;
            //#if defined(RIM_GLOW_WITH_LIGHT) && defined(RIM_GLOW)
            //        half factor = diffuse_factor(varying.normal, light.direction);
            //        baseTexColor.rgb = rgFragWithLight(baseTexColor.rgb, lightColor, normalize(varying.normal), normalize(_WorldSpaceCameraPos.xyz - varying.posWS), factor, _LightArea);
            //#endif
        }
        lightColor *= _AdditionalLightFactor / PI;
        //baseTexColor += lightColor;
    }
#endif

    half diff = 0.0f;
#ifdef FACE_MAP
    diff = tex2D(_FaceMap, varying.diff).a;
    //diff = diff * 2 - 1;
    //diff = max(diff, 0.001f);
    //diff = varying.diff / diff;
    //Diffuse
    outColor.rgb = ToonDiffuseWithLights(diff,
        0.1,
        1,
        baseTexColor,
        mainLight.color.rgb,
        lightColor,
        GI,
        mainLight.shadowAttenuation);
#else
    diff = varying.diff.x;
#ifdef _ADDITIONAL_LIGHTS
    //Diffuse
    outColor.rgb = ToonDiffuseWithAdditionalLights(diff,
        varying.color.r,
        tex_Light_Color.g,
        baseTexColor,
        mainLight.color.rgb,
        lightColor,
        GI,
        mainLight.shadowAttenuation);
#else
    outColor.rgb = ToonDiffuse(diff,
        varying.color.r,
        tex_Light_Color.g,
        baseTexColor,
        mainLight.color.rgb,
        GI,
        mainLight.shadowAttenuation);
#endif
#endif
    

    // 高光项
    half3 N = normalize(varying.normal);
    half3 V = normalize(_WorldSpaceCameraPos.xyz - varying.posWS);
#ifdef FRONT_FACE_LIGHT
    half3 H = normalize(_VirtualLightDir + V);
#else
    half3 H = normalize(_MainLightPosition.xyz + V);
#endif
    // b通道作为阀值：b通道不为0才会有高光，r通道作为mask
    outColor.rgb += complex_toon_specular(N, H, tex_Light_Color.b, tex_Light_Color.r);
    //to debug
    //outColor.rgb = complex_toon_specular(N, H, tex_Light_Color.b, tex_Light_Color.r);

    //Bloom factor
    outColor.a = _BloomFactor;

    outColor.rgb *= _BaseColor.rgb;

    //Rim Glow(边缘光)
    // 没有用texture来做mask. 
    // 在一些有平面的物体，当平面法线和视线接近垂直的时候，会导致整个平面都有边缘光。
    // 这会让一些不该有边缘光的地方出现边缘光。为了解决这个问题，在《GUILTY GEAR Xrd》中使用边缘光的Mask贴图来对边缘光区域进行调整。
#ifdef RIM_GLOW
#if defined(_ADDITIONAL_LIGHTS) && defined(RIM_GLOW_WITH_LIGHT)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, varying.posWS);
        half3 lightColor = light.color * light.distanceAttenuation;
        half factor = diffuse_factor(varying.normal, light.direction);
        outColor = rgFragWithLight(outColor, lightColor, N, V, factor, _LightArea, _BloomFactor);
    }
#else
    //outColor.rgb = rgFrag(outColor.rgb, N, V);
    outColor.rgb = rgFragEx(outColor.rgb, N, V, varying.diff.x, _LightArea);
#endif
    
#endif

#ifdef ENABLE_MATCAP
    half3 matcapColor;
    ApplyMatcap(varying, matcapColor);
    outColor.rgb += matcapColor;
#endif

    //half shadow = SHADOW_ATTENUATION(varying);
    //outColor.rgb *= mainLight.shadowAttenuation;
    //outColor.r = varying.shadowCoord;

    //outColor.rgb = lightColor;

    // 根据_DitherAlpha的值来做棋盘格式渐隐渐出
    if (_UsingDitherAlpha)
        dither_clip(varying.scrpos, varying.scrpos.z);

#ifdef FACE_MAP
    //outColor.r = varying.diff.x;
    //outColor.gb = 0;
#endif

    //outColor.rgb = _WorldSpaceLightPos0;
    return outColor;
} // End of frag

#endif // CHARACTER_AVATAR_INCLUDED
