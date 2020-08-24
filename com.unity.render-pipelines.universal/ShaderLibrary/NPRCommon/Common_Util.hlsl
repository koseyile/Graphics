#ifndef COMMON_UTIL_INCLUDED
#define COMMON_UTIL_INCLUDED

#include "../Core.hlsl"
#include "Common_Macros.hlsl"  

// return fade degree caused by nearing camera
float camera_fade(float4 vertex, float fadeOffset, float fadeDistance)
{
	float4 viewPos = mul(UNITY_MATRIX_MV, vertex);
	float fade = (-viewPos.z - _ProjectionParams.y - fadeOffset) / fadeDistance;
	fade = saturate(fade);
	return fade;
}

// return fade degree caused by nearing camera with a start alpha
float camera_fade_with_alpha(float4 vertex, float fadeOffset, float fadeDistance, float2 posInViewPort, float startAlpha)
{
	float4 viewPos = mul(UNITY_MATRIX_MV, vertex);
	float dist = length(posInViewPort.xy);
	float rev_dist = 1 - saturate(dist);
	float factor = (-viewPos.z - _ProjectionParams.y - fadeOffset) / (fadeDistance * rev_dist + 0.1); // add 0.1 to make sure there is a transition region
	float fade = lerp(startAlpha, 1, saturate(factor));
	return fade;
}

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

// return output alpha based on the input alpha and clip plane
//NOTE: need to modify the given vertex
float plane_clip_world_space(float alpha, inout float4 vertex, float4 clipPlane, float4x4 world2obj)
{
	//Transform the clipping plane defined in world space into object space
	// calc a point in plane in object space
	float4 pointInPlane;
	if (abs(clipPlane.w) < 0.001f)
	{
		pointInPlane = float4(0,0,0,1);
	}
	else
	{
		pointInPlane = float4(clipPlane.xyz * clipPlane.w, 1);
	}
	pointInPlane = mul(world2obj, pointInPlane);
	pointInPlane /= pointInPlane.w;

	// calc the plane normal in object space
	float3 planeNormal = mul((float3x3)world2obj, clipPlane.xyz);

	// calc the dist from origin to plane
	float origin_plane_dist = dot(pointInPlane.xyz, planeNormal);

	float plane_dist = dot(vertex.xyz, planeNormal);

	if(less(plane_dist, origin_plane_dist))
	{
		// Collapse the clipped vertice to the clip plane avoiding 
		// the clipped part occlude other transparent objects.
		vertex.xyz -= (plane_dist - origin_plane_dist) * planeNormal;
		return 0.0f;
	}
	else
	{
		return alpha;
	}

	return alpha;
}

// reflect the vertex about the plane
// return false if the vertex behind the plane
bool reflectVertex(inout float4 vert, float4 plane)
{
	plane.xyz = normalize(plane.xyz);
	float offset = dot(vert, plane);
	vert.xyz -= 2 * offset * plane.xyz;
	
	return offset > 0;
}

// decompose scale from RST matrix
// output scale as float3 and a new matrix without scale
void decompose_scale_from_matrix(in float4x4 inMatrix, out float4x4 outMatrix, out float3 scale)
{
	scale = sqrt(inMatrix[0].xyz * inMatrix[0].xyz
		+ inMatrix[1].xyz * inMatrix[1].xyz
		+ inMatrix[2].xyz * inMatrix[2].xyz);
	
	outMatrix = inMatrix;
	outMatrix[0].xyz /= scale;
	outMatrix[1].xyz /= scale;
	outMatrix[2].xyz /= scale;
}

// decompose scale from SRT matrix
// output scale as float3 and a new matrix without scale
void decompose_scale_from_matrix_rot(in float4x4 inMatrix, out float4x4 outMatrix, out float3 scale)
{
	scale.x = length(inMatrix[0].xyz);
	scale.y = length(inMatrix[1].xyz);
	scale.z = length(inMatrix[2].xyz);
	
	outMatrix = inMatrix;
	outMatrix[0].xyz /= scale;
	outMatrix[1].xyz /= scale;
	outMatrix[2].xyz /= scale;
}

// Screen Blend
half3 screen_blend(in half3 a, in half3 b)
{
	return 1 - (1-a) * (1-b);
}

// HSV color space
half3 rgb_to_hsv_no_clip(half3 RGB)
{
    half3 HSV;
   
    half minChannel, maxChannel;
    if (less(RGB.y, RGB.x)) 
    {
		maxChannel = RGB.x;
        minChannel = RGB.y;
    }
    else 
    {
        maxChannel = RGB.y;
        minChannel = RGB.x;
    }
     
    if (less(maxChannel, RGB.z)) maxChannel = RGB.z;
    if (less(RGB.z, minChannel)) minChannel = RGB.z;

    HSV.xy = 0;
    HSV.z = maxChannel;
	half delta = maxChannel - minChannel;             //Delta RGB value
    // if (delta != 0)                    // If gray, leave H  S at zero
    if (!equal(delta, 0))                   // If gray, leave H  S at zero
	{
        HSV.y = delta / HSV.z;
        half3 delRGB;
        delRGB = (HSV.zzz - RGB + 3*delta) / (6.0*delta);
        if      ( equal(RGB.x, HSV.z )) HSV.x = delRGB.z - delRGB.y;
        else if ( equal(RGB.y, HSV.z )) HSV.x = ( 1.0/3.0) + delRGB.x - delRGB.z;
        else if ( equal(RGB.z, HSV.z )) HSV.x = ( 2.0/3.0) + delRGB.y - delRGB.x;
    }
    return (HSV);
}

half3 hsv_to_rgb(half3 HSV)
{
    half3 RGB = HSV.z;
   
	half var_h = HSV.x * 6;
	half var_i = floor(var_h);   // Or ... var_i = floor( var_h )
	half var_1 = HSV.z * (1.0 - HSV.y);
	half var_2 = HSV.z * (1.0 - HSV.y * (var_h-var_i));
	half var_3 = HSV.z * (1.0 - HSV.y * (1-(var_h-var_i)));
    if      (equal(var_i, 0)) { RGB = half3(HSV.z, var_3, var_1); }
    else if (equal(var_i, 1)) { RGB = half3(var_2, HSV.z, var_1); }
    else if (equal(var_i, 2)) { RGB = half3(var_1, HSV.z, var_3); }
    else if (equal(var_i, 3)) { RGB = half3(var_1, var_2, HSV.z); }
    else if (equal(var_i, 4)) { RGB = half3(var_3, var_1, HSV.z); }
    else                 { RGB = half3(HSV.z, var_1, var_2); }
   
    return (RGB);
}

half3 RampBaseColor(half3 color, half weight)
{
    half3 rampColor = 3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
    return lerp(color, rampColor, weight);
}

// TBN matrix
// NOTE: need store bitangent sign in wTangent.w
inline void calcTBNMatrix(in half3 normal, in half4 tangent, out half3 tspace0, out half3 tspace1, out half3 tspace2)
{
	// comput normal and tangent in world space
	half3 wNormal = TransformObjectToWorldNormal(normal);
	half4 wTangent;
	wTangent.xyz = TransformObjectToWorldDir(tangent.xyz);
	wTangent.w = tangent.w * unity_WorldTransformParams.w;

	// compute bitangent from cross product of normal and tangent
	half3 wBitangent = cross(wNormal, wTangent.xyz) * wTangent.w;
	// output the tangent space matrix
	tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
	tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
	tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
}

inline half3 TangentToWorldNormal(in half3 i, in half3 tspace0, half3 tspace1, half3 tspace2)
{
	half3 o;
	o.x = dot(tspace0, i);
	o.y = dot(tspace1, i);
	o.z = dot(tspace2, i);

	return o;
}

static const float4x4 _DITHERMATRIX =
    {  1.0,  9.0,  3.0, 11.0,
      13.0,  5.0, 15.0,  7.0,
       4.0, 12.0,  2.0, 10.0,
      16.0,  8.0, 14.0,  6.0
    };
//float4x4 _DITHERMATRIX;
void dither_clip(float4 scrpos, half a)
{
	if(a < 0.95f)
	{
		scrpos.xy = (scrpos.xy / scrpos.w) *_ScreenParams.xy;
    	a *= 17;
    	float curA = _DITHERMATRIX[fmod(scrpos.x, 4)][fmod(scrpos.y, 4)];
    	clip ((a - curA) - 0.01f);
	}
    return;
}

////////////////// BEGIN QUATERNION FUNCTIONS //////////////////

//float PI = 3.1415926535897932384626433832795;

float4 setAxisAngle(float3 axis, float rad) {
    rad = rad * 0.5;
    float s = sin(rad);
    return float4(s * axis[0], s * axis[1], s * axis[2], cos(rad));
}

float3 xUnitVec3 = float3(1.0, 0.0, 0.0);
float3 yUnitVec3 = float3(0.0, 1.0, 0.0);

float4 rotationTo(float3 a, float3 b)
{
    float vecDot = dot(a, b);
    float3 tmpvec3 = float3(0, 0, 0);
    if (vecDot < -0.999999)
    {
        tmpvec3 = cross(xUnitVec3, a);
        if (length(tmpvec3) < 0.000001)
        {
            tmpvec3 = cross(yUnitVec3, a);
        }
        tmpvec3 = normalize(tmpvec3);
        return setAxisAngle(tmpvec3, PI);
    }
    else if (vecDot > 0.999999)
    {
        return float4(0, 0, 0, 1);
    }
    else
    {
        tmpvec3 = cross(a, b);
        float4 _out = float4(tmpvec3[0], tmpvec3[1], tmpvec3[2], 1.0 + vecDot);
        return normalize(_out);
    }
}

float4 multQuat(float4 q1, float4 q2)
{
    return float4(
        q1.w * q2.x + q1.x * q2.w + q1.z * q2.y - q1.y * q2.z,
        q1.w * q2.y + q1.y * q2.w + q1.x * q2.z - q1.z * q2.x,
        q1.w * q2.z + q1.z * q2.w + q1.y * q2.x - q1.x * q2.y,
        q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
        );
}

//float3 rotateVector(float4 quat, float3 vec)
//{
//    float4 qv = multQuat(quat, float4(vec, 0.0));
//    return multQuat(qv, float4(-quat.x, -quat.y, -quat.z, quat.w)).xyz;
//}

float3 rotateVector(float4 quat, float3 vec)
{
    return vec + 2.0 * cross(cross(vec, quat.xyz) + quat.w * vec, quat.xyz);
}

////////////////// END QUATERNION FUNCTIONS //////////////////

#endif // COMMON_UTIL_INCLUDED
