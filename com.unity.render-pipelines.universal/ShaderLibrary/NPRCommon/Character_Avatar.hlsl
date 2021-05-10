#ifndef CHARACTER_AVATAR_INCLUDED
#define CHARACTER_AVATAR_INCLUDED

#include "Common_Macros.hlsl"  
#include "Character_Avatar_Declaration.hlsl"

float sigmoid(float x, float center, float sharp)
{
    float s;
    s = 1 / (1 + pow(100000, (-3 * sharp * (x - center))));
    return s;
}

half3 Emissive(half2 uv)
{
    half3 emissive = tex2D(_EmissiveTex, uv);
    emissive *= _EmissiveColor.rgb;
    return emissive;
}

//3阶：light, light shadow(_FirstShadowMultColor), dark shadow(_SecondShadowMultColor)
// 高光贴图的G通道乘以顶点色的R通道可以控制阴影的区域
half3 ToonDiffuse(half factor,
    half t1,
    half t2,
    half3 baseTexColor,
    half3 mainLightColor,
#ifdef _ADDITIONAL_LIGHTS
    half3 additionalColor,
#endif
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
#ifdef _ADDITIONAL_LIGHTS
        half3 lightColor = lerp(0, additionalColor, ramp);
#endif
#else
        half ramp = sigmoid(threshold, _LightArea, _ShadowFeather);
        half3 shadowColor = lerp(_FirstShadowMultColor + GI, mainLightColor, ramp);
#ifdef _ADDITIONAL_LIGHTS
        half3 lightColor = lerp(0, additionalColor, ramp);
#endif
#endif
        //shadowColor *= shadowAttenuation;
        shadowColor *= shadowAttenuation < 1 ? LerpWhiteTo(shadowAttenuation, 1 - _ShadowDarkness): 1.0h;
        diffColor = baseTexColor * shadowColor;
#ifdef _ADDITIONAL_LIGHTS
        diffColor += lightColor * baseTexColor;
#endif
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

void ApplyMatcap(half2 matcapUV, out half3 color)
{
#ifdef ENABLE_MATCAP
    color = tex2D(_Matcap, matcapUV).rgb * _MatcapColor;
#endif
}

void ApplyMatcap(half2 uv, half3 tspace0, half3 tspace1, half3 tspace2, out half3 color)
{
#ifdef ENABLE_MATCAP_NROMAL_MAP
    uv = TRANSFORM_TEX(uv, _MatcapNormalMap);
    half3 normal = UnpackNormal(tex2D(_MatcapNormalMap, uv));
    normal = TangentToWorldNormal(normal, tspace0, tspace1, tspace2);
    //float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
    normal = mul(UNITY_MATRIX_V, normal);
    //float3 viewNormal = (mul(UNITY_MATRIX_V, float4(lerp(i.normalDir, mul(normal, tangentTransform).rgb, _Is_NormalMapForMatCap), 0))).rgb;
    normal = normalize(normal);
    half2 matcapUV = normal.xy * 0.5f + 0.5f;
    color = tex2D(_Matcap, matcapUV).rgb * _MatcapColor;
#endif
}


half4 ToonShading(ToonVaryings varying, int writeBloom)
{
    half4 outColor = (float4)0;
    half2 mainUV = TRANSFORM_TEX(varying.texcoord, _BaseMap);
    // 高光贴图的通道作用：
    // R通道：高光强度，控制高光的强度，当0时可以禁用
    // G通道：阴影阈值，它乘以顶点色的R通道可以控制阴影的区域
    // B通道：光滑度，镜面阈值；数值越大，高光越强。
    half3 tex_Light_Color = tex2DRGB(_LightMapTex, mainUV).rgb;

    half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, mainUV);
    baseColor.rgb = RampBaseColor(baseColor.rgb, _RevertTonemapping);
#ifndef _RECEIVE_SHADOWS_OFF
#ifdef NO_SELF_SHADOW
    Light mainLight = GetMainLight();
    mainLight.shadowAttenuation = MainLightRealtimeShadow(varying.shadowCoord);
#else
    Light mainLight = GetMainLight(varying.shadowCoord, varying.posWS);
#endif
#else
    Light mainLight = GetMainLight();
#endif

    half3 additionalLightColor = (half3)0;
#ifdef _ADDITIONAL_LIGHTS
    if (_AdditionalLightFactor > 0.001f)
    {
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, varying.posWS);
            additionalLightColor += light.color * light.distanceAttenuation;
            //#if defined(RIM_GLOW_WITH_LIGHT) && defined(RIM_GLOW)
            //        half factor = diffuse_factor(varying.normal, light.direction);
            //        baseTexColor.rgb = rgFragWithLight(baseTexColor.rgb, lightColor, normalize(varying.normal), normalize(_WorldSpaceCameraPos.xyz - varying.posWS), factor, _LightArea);
            //#endif
        }
        additionalLightColor *= _AdditionalLightFactor / PI;
    }
#endif

    // 间接光包含了环境光和GI，明暗面都会影响
    half3 indirectLight = SampleSH(half3(0, 0, 0));
    indirectLight += UNITY_LIGHTMODEL_AMBIENT;
    //GI *= PI * PI;

    half3 mainLightColor = mainLight.color.rgb;
    mainLightColor += indirectLight;

    half diff = 0.0f;
#ifdef FACE_MAP
    diff = tex2D(_FaceMap, varying.diff).a;
    //diff = diff * 2 - 1;
    //diff = max(diff, 0.001f);
    //diff = varying.diff / diff;
    //Diffuse
    outColor.rgb = ToonDiffuse(diff,
        0.1,
        1,
        baseColor.rgb,
        mainLightColor,
        lightColor,
        indirectLight,
        mainLight.shadowAttenuation);
#else
    diff = varying.diff.x;
#ifdef _ADDITIONAL_LIGHTS
    //Diffuse
    outColor.rgb = ToonDiffuse(diff,
        varying.color.r,
        tex_Light_Color.g,
        baseColor.rgb,
        mainLightColor,
        additionalLightColor,
        indirectLight,
        mainLight.shadowAttenuation);
#else
    outColor.rgb = ToonDiffuse(diff,
        varying.color.r,
        tex_Light_Color.g,
        baseColor.rgb,
        mainLightColor,
        indirectLight,
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
    if (writeBloom > 0)
        outColor.a = _BloomFactor * baseColor.a * _BaseColor.a;
    else
        outColor.a = baseColor.a * _BaseColor.a;

    outColor.rgb *= _BaseColor.rgb;

    //Rim Glow(边缘光)
    // 没有用texture来做mask. 
    // 在一些有平面的物体，当平面法线和视线接近垂直的时候，会导致整个平面都有边缘光。
    // 这会让一些不该有边缘光的地方出现边缘光。为了解决这个问题，在《GUILTY GEAR Xrd》中使用边缘光的Mask贴图来对边缘光区域进行调整。
#ifdef RIM_GLOW
#if defined(_ADDITIONAL_LIGHTS) && defined(RIM_GLOW_WITH_LIGHT)
    outColor = rgWithAllLights(outColor, varying.posWS, N, V);
#else
    //outColor.rgb = rgFrag(outColor.rgb, N, V);
    outColor.rgb = rgFragEx(outColor.rgb, N, V, varying.diff.x, _LightArea);
#endif
#endif

#ifdef ENABLE_MATCAP
    half3 matcapColor;
#ifdef ENABLE_MATCAP_NROMAL_MAP
    ApplyMatcap(varying.texcoord, varying.tspace0, varying.tspace1, varying.tspace2, matcapColor);
#else
    ApplyMatcap(varying.matcapUV, matcapColor);
#endif
    outColor.rgb += matcapColor;
#endif

#ifdef ENABLE_EMISSIVE
    outColor.rgb += Emissive(varying.texcoord);
#endif

    // 根据_DitherAlpha的值来做棋盘格式渐隐渐出
    if (_UsingDitherAlpha)
        dither_clip(varying.scrpos, varying.scrpos.z);

#ifdef FACE_MAP
    //outColor.r = varying.diff.x;
    //outColor.gb = 0;
#endif

    //outColor.rgb = _WorldSpaceLightPos0;
    return outColor;
}

ToonVaryings vert(ToonAttributes attribute)
{
    ToonVaryings varying = (ToonVaryings)0;

    varying.position = TransformObjectToHClip(attribute.vertex.xyz);
    varying.color = attribute.color;
    float4 objPos = mul(unity_ObjectToWorld, attribute.vertex);
    varying.posWS = objPos.xyz / objPos.w;
    //varying.texcoord = TRANSFORM_TEX(attribute.texcoord.xy, _BaseMap);
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

    return varying;
} // End of vert

half4 frag(ToonVaryings varying) : COLOR
{
    return ToonShading(varying, 1);
} 

half4 fragTransparent(ToonVaryings varying) : COLOR
{
    return ToonShading(varying, 0);
}

half4 fragTransparentOnlyAlpha(ToonVaryings varying) : COLOR
{
    half2 mainUV = TRANSFORM_TEX(varying.texcoord, _BaseMap);
    half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, mainUV);
    return half4(0, 0, 0, _BloomFactor * baseColor.a * _BaseColor.a);
}

#endif // CHARACTER_AVATAR_INCLUDED
