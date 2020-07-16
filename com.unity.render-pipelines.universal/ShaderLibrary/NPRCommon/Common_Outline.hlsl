#ifndef COMMON_OUTLINE_INCLUDED
#define COMMON_OUTLINE_INCLUDED

//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Version.hlsl"  
//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

//#include "UnityCG.cginc"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Common_Util.hlsl"

//Uniform
half4 _BaseColor;
half _OutlineWidth;
half4 _OutlineColor;
half _MaxOutlineZOffset;
half _Scale;
float4 _ClipPlane;
half _FadeDistance;
half _FadeOffset;
half _Opaqueness;
sampler2D _MainTex;
float4 _MainTex_ST;

float _UsingDitherAlpha;
float _DitherAlpha;

//Input
struct Attributes
{
	float4 vertex : POSITION;
    float3 normal : NORMAL;
#ifdef TANGENT_OUTLINE
    float4 tangent : TANGENT;
#endif
	half4 color : COLOR0;
    float4 texcoord : TEXCOORD0;
};

struct Varyings
{
	float4 position : SV_POSITION;
	half4 color : COLOR0;
	float4 scrpos : TEXCOORD3;
};


void setColor(out half4 color)
{
	color = _OutlineColor;
}


//Vertext Shader
// camera离近了会有渐隐
Varyings vert_simple (Attributes input)
{
	Varyings output = (Varyings)0;

	output.position = mul(UNITY_MATRIX_MV, input.vertex);
	output.position /= output.position.w;

	// 由camera的Z和fov来控制勾线的宽度
	half cameraFactor = -output.position.z / unity_CameraProjection[1][1];
	cameraFactor = pow(cameraFactor / _Scale, 0.5f);

	// 有时w不为0，所以这里只使用xyz
	// 把切线或法线transform到view space
#ifdef TANGENT_OUTLINE
	half3 N = mul((float3x3)UNITY_MATRIX_MV, input.tangent.xyz);
#else
    half3 N = mul((float3x3)UNITY_MATRIX_MV, input.normal.xyz);
#endif
	// 用N来确定XY平面的一个扩张方向
	N.z = 0.01f;
	N = normalize(N);
	half offset = _OutlineWidth * _Scale * cameraFactor;
	// 施加XY平面上的偏移
	output.position.xy += N.xy * offset;
	setColor(output.color);

	// 根据Z值做渐隐
	output.color.a = camera_fade(input.vertex, _FadeOffset, _FadeDistance);
	// Get opaqueness from vertex
	//output.color.a *= lerp(1.0f, input.color.a, _VertexAlphaFactor);

	output.position = mul(UNITY_MATRIX_P, output.position);
	if(_UsingDitherAlpha)
	{
		output.scrpos = ComputeScreenPos(output.position);
		output.scrpos.z = _DitherAlpha;
	}
	return output;
}


// 1. 用顶点色控制勾线宽度
// 2. camera离近了没有渐隐
Varyings vert_complex (Attributes input)
{
	Varyings output = (Varyings)0;

	// Position, transform到view space
	output.position = mul(UNITY_MATRIX_MV, input.vertex);
	output.position /= output.position.w;

	// 由camera的Z和fov来控制勾线的宽度
	half cameraFactor = -output.position.z / unity_CameraProjection[1][1];

	// Somehow the w component not be zero, so only use xyz
	// 把切线或法线transform到view space
#ifdef TANGENT_OUTLINE
    half3 N = mul((float3x3)UNITY_MATRIX_MV, input.tangent.xyz);
#else
    half3 N = mul((float3x3)UNITY_MATRIX_MV, input.normal.xyz);
#endif
	// 用N来确定XY平面的一个扩张方向
	N.z = 0.01f;
    //N.z = 0;
	N = normalize(N);

	//NOTE: do not use camera adjustment factor from vertex color at present
	// half start = _OutlineCamStart * _Scale;
	// input.color.g = 0.5f + saturate((-output.position.z - start)*2/start) * (input.color.g - 0.5f);
	// S = pow(S / _Scale, 0.4f + input.color.g * 0.2f);
	cameraFactor = pow(cameraFactor / _Scale, 0.5f);
	half offset = _OutlineWidth * _Scale * input.color.g * cameraFactor;
	// 施加Z偏移。顶点色G控制Z方向上的偏移
	// output.position.xyz作为方向向量的话就是view direction
	output.position.xyz += normalize(output.position.xyz) * _MaxOutlineZOffset * _Scale * (input.color.b-0.5f);

	// 施加XY平面上的偏移
	output.position.xy += N.xy * offset;

	setColor(output.color);
	output.color.a = 1;

	output.position = mul(UNITY_MATRIX_P, output.position);
	if(_UsingDitherAlpha)
	{
		output.scrpos = ComputeScreenPos(output.position);
		output.scrpos.z = _DitherAlpha;
	}
	return output;
}

//Fragment Shader
half4 frag (Varyings input) : SV_Target
{
	half4 color = input.color;
	color.rgb *= _BaseColor.rgb;
	//color.rgb = input.color.rgb;
	if(_UsingDitherAlpha)
		dither_clip(input.scrpos, input.scrpos.z);
	//color.rgba = _BaseColor.rgba;
	return color;
}

//与vert_simple配合实现fade
half4 frag_alpha_test(Varyings input) : SV_Target
{
	half4 color = input.color;
	clip(color.a - 0.01f);
	color.rgb *= _BaseColor.rgb;
	if (_UsingDitherAlpha)
		dither_clip(input.scrpos, input.scrpos.z);
	return color;
}

half4 frag_transparent (Varyings input) : SV_Target
{
	half4 color = input.color;
	color.rgb *= _BaseColor.rgb;
	color.a *= _Opaqueness;
	if(_UsingDitherAlpha)
		dither_clip(input.scrpos, input.scrpos.z);
	//color.rgba = 1;
	return color;
}

#endif // COMMON_OUTLINE_INCLUDED
