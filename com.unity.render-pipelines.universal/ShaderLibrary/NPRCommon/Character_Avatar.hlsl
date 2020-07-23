#ifndef CHARACTER_AVATAR_INCLUDED
#define CHARACTER_AVATAR_INCLUDED

#include "Common_Macros.hlsl"  

half _FadeDistance;
half _FadeOffset;

float _UsingDitherAlpha;
float _DitherAlpha;
#ifdef FRONT_FACE_LIGHT
float3 _CharacterOrientation;
float3 _VirtualLightDir;
#endif

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
    half diff : COLOR1;
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
    varying.diff = diffuse_factor(varying.normal, _VirtualLightDir);
#else
    varying.diff = diffuse_factor(varying.normal, _MainLightPosition.xyz);
#endif
#ifdef RECEIVE_SHADOW
    varying.shadowCoord = GetShadowCoord(varying.position, varying.objPos);
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
    //Diffuse
    outColor.rgb = complex_toon_diffuseEx(varying.diff,
        varying.color.r,
        tex_Light_Color.g,
        baseTexColor,
        mainLight.color.rgb,
        GI,
        mainLight.shadowAttenuation);

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
    outColor.rgb = rgFragEx(outColor.rgb, N, V, varying.diff);
#endif

    //half shadow = SHADOW_ATTENUATION(varying);
    //outColor.rgb *= mainLight.shadowAttenuation;
    //outColor.r = varying.shadowCoord;

    // 根据_DitherAlpha的值来做棋盘格式渐隐渐出
    if (_UsingDitherAlpha)
        dither_clip(varying.scrpos, varying.scrpos.z);

    //outColor.rgb = _WorldSpaceLightPos0;
    return outColor;
} // End of frag

#endif // CHARACTER_AVATAR_INCLUDED
