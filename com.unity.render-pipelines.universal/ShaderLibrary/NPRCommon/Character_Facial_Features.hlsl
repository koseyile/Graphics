#ifndef CHARACTER_FACIAL_FEATURES
#define CHARACTER_FACIAL_FEATURES

#include "Common_Macros.hlsl"  

float4 _BaseColor;
sampler2D _MainTex;
half4 _MainTex_ST;
half _BloomFactor;
half _EmissionFactor;

// hsv tune
half3 _ColorToOffset;
half _ColorTolerance;
half _HueOffset;
half _SaturationOffset;
half _ValueOffset;

float _UsingDitherAlpha;
float _DitherAlpha;

struct appdata
{
    float4 position : POSITION0;
    float3 normal : NORMAL;
    half2 uv_MainTex : TEXCOORD0;
};

struct v2f
{
    float4 position : POSITION0;
    float4 color : COLOR0;
    half2 uv_MainTex : TEXCOORD0;
    half3 hsvToOffset : TEXCOORD1;
    float4 scrpos : TEXCOORD2;
};

v2f vert(appdata in_data)
{
    v2f outData = (v2f)0;
    outData.position = TransformObjectToHClip(in_data.position.xyz);
    //Texture
    outData.uv_MainTex = TRANSFORM_TEX(in_data.uv_MainTex, _MainTex);
    if (_UsingDitherAlpha)
    {
        outData.scrpos = ComputeScreenPos(outData.position);
        outData.scrpos.z = _DitherAlpha;
    }
    return outData;
}

float4 frag(v2f in_data) : COLOR
{
    half4 outColor = tex2D(_MainTex, in_data.uv_MainTex);
    outColor.rgb = outColor.rgb*_BaseColor.rgb*_EmissionFactor;
    //applyLightProb(outColor.rgb);

    if (_UsingDitherAlpha)
        dither_clip(in_data.scrpos, in_data.scrpos.z);

    return outColor;
}

v2f vertHSV(appdata in_data)
{
    v2f outData = (v2f)0;
    outData.position = TransformObjectToHClip(in_data.position.xyz);
    //Texture
    outData.uv_MainTex = TRANSFORM_TEX(in_data.uv_MainTex, _MainTex);
    // hsv
    outData.hsvToOffset = rgb_to_hsv_no_clip(_ColorToOffset);
    if (_UsingDitherAlpha)
    {
        outData.scrpos = ComputeScreenPos(outData.position);
        outData.scrpos.z = _DitherAlpha;
    }
    return outData;
}

float4 fragHSV(v2f in_data) : COLOR
{
    half4 outColor = tex2D(_MainTex, in_data.uv_MainTex);
    // 色相调整
    half3 hsv = rgb_to_hsv_no_clip(outColor.rgb);
    // 计算纹理的颜色与给定的调色板的颜色的tolerance
    half dist = length(hsv - in_data.hsvToOffset);
    half3 hsvDst = half3(frac(hsv.x + _HueOffset),
        saturate(hsv.y + _SaturationOffset),
        saturate(hsv.z + _ValueOffset));
    // 如果上面计算的dist(tolerance)小于阀值，则使用偏移过得hsvDst
    hsvDst = lerp(hsvDst, hsv, step(_ColorTolerance, dist));
    outColor.rgb = hsv_to_rgb(hsvDst);

    outColor.rgb = outColor.rgb*_BaseColor.rgb*_EmissionFactor;
    //applyLightProb(outColor.rgb);

    if (_UsingDitherAlpha)
        dither_clip(in_data.scrpos, in_data.scrpos.z);

    return outColor;
}

float4 fragHSVAlphaTest(v2f in_data) : COLOR
{
    half4 outColor = tex2D(_MainTex, in_data.uv_MainTex);
    clip(outColor.a - 0.5f);

    // 色相调整
    half3 hsv = rgb_to_hsv_no_clip(outColor.rgb);
    // 计算纹理的颜色与给定的调色板的颜色的tolerance
    half dist = length(hsv - in_data.hsvToOffset);
    half3 hsvDst = half3(frac(hsv.x + _HueOffset),
        saturate(hsv.y + _SaturationOffset),
        saturate(hsv.z + _ValueOffset));
    // 如果上面计算的dist(tolerance)小于阀值，则使用偏移过得hsvDst
    hsvDst = lerp(hsvDst, hsv, step(_ColorTolerance, dist));
    outColor.rgb = hsv_to_rgb(hsvDst);

    outColor.rgb = outColor.rgb*_BaseColor.rgb*_EmissionFactor;
    //applyLightProb(outColor.rgb);

    if (_UsingDitherAlpha)
        dither_clip(in_data.scrpos, in_data.scrpos.z);

    return outColor;
}

#endif // CHARACTER_FACIAL_FEATURES
