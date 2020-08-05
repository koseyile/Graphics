// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

#ifndef COMMON_RIM_GLOW_INCLUDED
#define COMMON_RIM_GLOW_INCLUDED

//Uniform
uniform half4 _RGColor;
uniform float _RGShininess;
uniform float _RGScale;
uniform float _RGBias;
uniform float _RGRatio;
uniform float _RGSmooth;
uniform float _RGBloomFactor;
uniform int _RGBlendType;

//Vertex Shader
void rgVert(in float3 vert, in float3 localPos, out float3 rgviewdir)
{
    rgviewdir = _WorldSpaceCameraPos - mul((float3x3)unity_ObjectToWorld, localPos);
}

half fresnel(in float3 N, in float3 V)
{
    return _RGBias + (pow(clamp(1.0 - dot(V, N), 0.0, 1.0), _RGShininess) * _RGScale);
}

//Fragment Shader
half3 rgFrag(in half3 srcColor, in float3 N, in float3 V)
{
    half f = fresnel(N, V);
    half3 rgColor = f * _RGColor;
    // return rgColor + srcColor - rgColor * srcColor;
    // return rgColor;
    // return lerp(srcColor, rgColor, _RGRatio);
    return lerp(srcColor, rgColor, clamp(f, 0, 1) * _RGRatio);
}

half3 rgFragEx(in half3 srcColor, in float3 N, in float3 V, half facter, half lightArea)
{
    half f = fresnel(N, V);
    half3 rgColor = _RGColor;

    //return lerp(srcColor, rgColor, saturate(f) * _RGRatio * (1 - step(facter, lightArea)));
    half rim = smoothstep(0, _RGSmooth, saturate(f));
    return lerp(srcColor, rgColor, _RGRatio * rim * (1 - step(facter, lightArea)));
}

half4 rgFragWithLight(in half4 srcColor,
    in half3 lightColor,
    in float3 N,
    in float3 V,
    in half factor,
    in half lightArea,
    in half bloomFactor)
{
    half f = fresnel(N, V);
    half3 rgColor = srcColor + lightColor;

    //return lerp(srcColor, rgColor, saturate(f) * _RGRatio * (1 - step(facter, lightArea)));
    half rim = smoothstep(0, _RGSmooth, saturate(f));
    half weight = _RGRatio * rim * (1 - step(factor, lightArea));
    half4 color;
    color.rgb = lerp(srcColor, rgColor, weight);
    color.a = lerp(bloomFactor, _RGBloomFactor, weight);
    return color;
}

//Fragment Shader
half4 rgFrag_Alpha(in half4 srcColor, in float3 N, in float3 V)
{
	half f = fresnel(N, V);
	half4 rgColor = f * _RGColor;
	rgColor.a = 1;
	// return rgColor + srcColor - rgColor * srcColor;
	// return rgColor;
	// return lerp(srcColor, rgColor, _RGRatio);
	return lerp(srcColor, rgColor, clamp(f, 0, 1) * _RGRatio);
}

half3 rgFrag_withV(in half3 srcColor, in float3 N, in float3 V)
{
    half f = fresnel(N, V);
    half3 rgColor = f * _RGColor;
    // return rgColor + srcColor - rgColor * srcColor;
    // return rgColor;
    // return lerp(srcColor, rgColor, _RGRatio);
    return lerp(srcColor, rgColor, clamp(f, 0, 1) * _RGRatio);
}

half3 rgFrag_Add(in half3 srcColor, in float3 N, in float3 V)
{
	half f = fresnel(N, V);
	half3 rgColor = f * _RGColor;
	return srcColor + max(rgColor,0);
}


#endif // COMMON_RIM_GLOW_INCLUDED
