#ifndef CHARACTER_AVATAR_SSS_INCLUDED
#define CHARACTER_AVATAR_SSS_INCLUDED

#include "Common_Macros.hlsl"

float Pow2(float x)
{
	return x * x;
}

float ndc2Normal(float x)
{
	return x * 0.5 + 0.5;
}

float warp(float x, float w)
{
	return (x + w) / (1 + w);
}

float3 warp(float3 x, float3 w)
{
	return (x + w) / (1 + w);
}

float3 warp(float3 x, float w)
{
	return (x + w.xxx) / (1 + w.xxx);
}

float sigmoid2(float x, float center, float sharp)
{
	float s;
	s = 1 / (1 + pow(100000, (-3 * sharp * (x - center))));
	return s;
}

float Gaussion(float x, float center, float var)
{
	return pow(2.718, -1 * Pow2(x - center) / var);
}

int _EnableSSS;
half4 _SSSColor;
//half4 _SSSColorSub;
half _SSSWeight;
half _SSSSize;
half _DiffuseBright;
//half _DividLineM;
//half _DividLineD;
//half _DividSharpness;
//half _SSForwardAtt;

half3 LightingSSS(half3 albedo, half smoothMap, half3 normal, half3 lightDir)
{
    const half _DividLineM = 0.8f;
    const half _DividSharpness = 0.2f;
    const half _DividLineD = 0.1f;
    const half _SSForwardAtt = 0.5f;
    half3 nNormal = normalize(normal);
    half NoL = dot(nNormal, lightDir);
    half Lambert = NoL;
    half SSLambert = warp(Lambert, _SSSWeight);

	//half roughness = 0.95 - 0.95 * (smoothMap * _Glossiness);
	half roughness = 0.95 - 0.95 * (smoothMap);
	half _BoundSharp = 9.5 * Pow2(roughness - 1) + 0.5;

    //--------------------------------------------
	// diffuse
	//--------------------------------------------
	half MidSig = sigmoid2(Lambert, _DividLineM, _BoundSharp * _DividSharpness);
	half DarkSig = sigmoid2(Lambert, _DividLineD, _BoundSharp * _DividSharpness);

	half MidLWin = MidSig;
	half MidDWin = DarkSig - MidSig;
	half DarkWin = 1 - DarkSig;

	half diffuseLumin1 = (1 + ndc2Normal(_DividLineM)) / 2;
	half diffuseLumin2 = (ndc2Normal(_DividLineM) + ndc2Normal(_DividLineD)) / 2;
	half diffuseLumin3 = (ndc2Normal(_DividLineD));

    half3 diffuseDeflectedColor1 = MidLWin * diffuseLumin1.xxx;
    half3 diffuseDeflectedColor2 = MidDWin * diffuseLumin2.xxx;
    half3 diffuseDeflectedColor3 = DarkWin * diffuseLumin3.xxx;
    half3 diffuseBrightedColor = warp(diffuseDeflectedColor1 + diffuseDeflectedColor2 + diffuseDeflectedColor3, _DiffuseBright.xxx);

    half3 diffuseResult = diffuseBrightedColor * albedo;
    //half3 diffuseResult = albedo;

    //----------------------------------------------
    // scattering
    //----------------------------------------------
    half SSMidLWin = Gaussion(Lambert, _DividLineM, _SSForwardAtt * _SSSSize);
    half SSMidDWin = Gaussion(Lambert, _DividLineM, _SSSSize);
    half SSMidLWin2 = Gaussion(Lambert, _DividLineM, _SSForwardAtt * _SSSSize*0.01);
    half SSMidDWin2 = Gaussion(Lambert, _DividLineM, _SSSSize * 0.01);
    half3 SSLumin1 = MidLWin * diffuseLumin2 * _SSForwardAtt * (SSMidLWin + SSMidLWin2);
    half3 SSLumin2 = ((MidDWin + DarkWin) * diffuseLumin2) * (SSMidDWin+ SSMidDWin2);
    half3 SS = _SSSWeight * (SSLumin1 + SSLumin2) * _SSSColor.rgb;

    //---------------------------------------------------------------------------
    half3 lightResult = diffuseResult.rgb + SS;
    return lightResult;
	//return 0;
}

#endif // CHARACTER_AVATAR_SSS_INCLUDED
