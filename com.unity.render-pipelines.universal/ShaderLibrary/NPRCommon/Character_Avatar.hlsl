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

half _Shininess;
half _SpecMulti;

half3 _LightSpecColor;

half _Opaqueness;

half4 _LightColor0;
half _BloomFactor;

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
half3 complex_toon_diffuseEx(half factor, half t1, half t2, half3 baseTexColor, half3 mainLightColor, half3 GI, half shadowAttenuation)
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
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, ramp * shadowAttenuation);
#else
        half w = sigmoid(threshold, _LightArea, _ShadowFeather);
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, w * shadowAttenuation);
#endif
        //half3 shadowColor = less(threshold, _LightArea) ? _FirstShadowMultColor * GI : _MainLightColor.rgb;

        diffColor = baseTexColor * shadowColor;
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


struct Attributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
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
    float3 objPos : TEXCOORD2;
    float4 scrpos : TEXCOORD3;
#ifdef RECEIVE_SHADOW
    float4 shadowCoord : TEXCOORD4;
#endif
    //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
    half2 diff : COLOR1;
};

Varyings vert(Attributes attribute)
{
    Varyings varying = (Varyings)0;

    varying.position = TransformObjectToHClip(attribute.vertex.xyz);
    varying.color = attribute.color;
    float4 objPos = mul(unity_ObjectToWorld, attribute.vertex);
    varying.objPos = objPos.xyz / objPos.w;
    varying.texcoord = TRANSFORM_TEX(attribute.texcoord.xy, _MainTex);

    //Normal
    varying.normal = normalize(TransformObjectToWorldNormal(attribute.normal));
    //outData.normal = normalize(mul(unity_ObjectToWorld, inData.normal).xyz);
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
    varying.shadowCoord = GetShadowCoord(varying.objPos);
#endif
    //OUTPUT_SH(varying.normal, varying.vertexSH);

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

    // 高光贴图的通道作用：
    // R通道：高光强度，控制高光的强度，当0时可以禁用
    // G通道：阴影阀值，它乘以顶点色的R通道可以控制阴影的区域
    // B通道：光滑度，镜面阈值；数值越大，高光越强。
    half3 tex_Light_Color = tex2DRGB(_LightMapTex, varying.texcoord).rgb;

    half3 baseTexColor = tex2D(_MainTex, varying.texcoord).rgb;
#ifdef RECEIVE_SHADOW
    Light mainLight = GetMainLight(varying.shadowCoord);
#else
    Light mainLight = GetMainLight();
#endif
    // 无方向的light probe的全局光只作用于暗部
    half3 GI = SampleSH(half3(0, 0, 0));
#ifdef _ADDITIONAL_LIGHTS
    half3 lightColor = (half3)0;
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, varying.objPos);
        lightColor += light.color * light.distanceAttenuation / PI;
    }
    baseTexColor += lightColor;
#endif

    half diff = 0.0f;
#ifdef FACE_MAP
    diff = tex2D(_FaceMap, varying.diff).a;
    //diff = diff * 2 - 1;
    //diff = max(diff, 0.001f);
    //diff = varying.diff / diff;
    //Diffuse
    outColor.rgb = complex_toon_diffuseEx(diff,
        0.1,
        1,
        baseTexColor,
        mainLight.color.rgb,
        GI,
        mainLight.shadowAttenuation);
#else
    diff = varying.diff.x;
    //Diffuse
    outColor.rgb = complex_toon_diffuseEx(diff,
        varying.color.r,
        tex_Light_Color.g,
        baseTexColor,
        mainLight.color.rgb,
        GI,
        mainLight.shadowAttenuation);
#endif
    

    // 高光项
    half3 N = normalize(varying.normal);
    half3 V = normalize(_WorldSpaceCameraPos.xyz - varying.objPos);
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
    //outColor.rgb = rgFrag(outColor.rgb, N, V);
    outColor.rgb = rgFragEx(outColor.rgb, N, V, varying.diff.x, _LightArea);
#endif

    //half shadow = SHADOW_ATTENUATION(varying);
    //outColor.rgb *= mainLight.shadowAttenuation;
    //outColor.r = varying.shadowCoord;

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
