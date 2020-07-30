void BuildInputData(Varyings input, float3 normal, out InputData inputData)
{
    inputData.positionWS = input.positionWS;
#ifdef _NORMALMAP
    inputData.normalWS = TransformTangentToWorld(normal,
        half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(input.viewDirectionWS);
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.sh, inputData.normalWS);
}

PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

half4 frag(PackedVaryings packedInput) : SV_TARGET 
{    
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);

    SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(unpacked);
    SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

    #if _AlphaClip
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    InputData inputData;
    BuildInputData(unpacked, surfaceDescription.Normal, inputData);

    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
    #else   
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
    #endif


#ifdef _ToonStyle 
        half4 color = UniversalFragmentStylePBR(
            inputData,
            surfaceDescription.Albedo,
            metallic,
            specular,
            surfaceDescription.Smoothness,
            surfaceDescription.Occlusion,
            surfaceDescription.Emission,
            surfaceDescription.Alpha,
            surfaceDescription.StyleScale,
            surfaceDescription.StyleNdotL);
#else
        half4 color = UniversalFragmentPBR(
            inputData,
            surfaceDescription.Albedo,
            metallic,
            specular,
            surfaceDescription.Smoothness,
            surfaceDescription.Occlusion,
            surfaceDescription.Emission,
            surfaceDescription.Alpha);
#endif
    

	//#ifdef _ToonStyle
	//Light mainLight = GetMainLight(inputData.shadowCoord);
	//half NdotL = saturate(dot(inputData.normalWS, mainLight.direction));
	////NdotL = smoothstep(0, 0.01, NdotL); 

	//half3 rimDot = 1 - dot(inputData.viewDirectionWS, inputData.normalWS);
	//half rimIntensity = rimDot*pow(NdotL, 0.1);
	//half rimW = surfaceDescription.RimWidth;	
	//rimIntensity = smoothstep(rimW - 0.01, rimW+0.01, rimIntensity);
	//half3 rim = rimIntensity * mainLight.color;
	//color.rgb += rim;
	//#endif

#ifdef _ToonStyle
    color.rgb = lerp(color.rgb, surfaceDescription.TestColor, surfaceDescription.TestColorScale);
#endif
    
	

    color.rgb = MixFog(color.rgb, inputData.fogCoord); 
    return color;
}
