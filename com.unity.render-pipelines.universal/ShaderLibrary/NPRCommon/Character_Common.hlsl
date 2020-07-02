#ifndef CHARACTER_COMMON_INCLUDED
#define CHARACTER_COMMON_INCLUDED

#include "Common_Macros.hlsl"  

half4 _BaseColor;
sampler2D _MainTex;
sampler2D _MainTex_Alpha;
float4 _MainTex_ST;
sampler2D _LightMapTex;

half _LightArea;
half _SecondShadow;
half3 _FirstShadowMultColor;
half3 _SecondShadowMultColor;

half _Shininess;
half _SpecMulti;

half3 _LightSpecColor;

half _Opaqueness;

half4 _LightColor0;
half _BloomFactor;

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
half3 complex_toon_diffuseEx(half factor, half t1, half t2, half3 baseTexColor)
{
	half3 diffColor = half3(1.0f, 1.0f, 1.0f).rgb;

	half D = t1 * t2;
	half threshold = 0;

	if (less(D, 0.09f))
	{
		threshold = (factor + D) * 0.5f;
		half3 shadowColor = less(threshold, _SecondShadow)? _SecondShadowMultColor: _FirstShadowMultColor;
		diffColor = baseTexColor * shadowColor;
	}
	else 
	{
		// mapping [0.1, 0.5) to [-0.1, 0.5)
		if (greaterEqual(D, 0.5f)) D = D * 1.2f - 0.1f;
		else D = D * 1.25f - 0.125f;

		threshold = (factor + D) * 0.5f;
        half3 shadowColor = less(threshold, _LightArea)? _FirstShadowMultColor: diffColor;
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

#endif // CHARACTER_COMMON_INCLUDED
