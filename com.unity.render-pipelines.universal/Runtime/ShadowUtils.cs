using System;
using UnityEngine.Scripting.APIUpdating;

namespace UnityEngine.Rendering.Universal
{
    [MovedFrom("UnityEngine.Rendering.LWRP")] public struct ShadowSliceData
    {
        public Matrix4x4 viewMatrix;
        public Matrix4x4 projectionMatrix;
        public Matrix4x4 shadowTransform;
        public int offsetX;
        public int offsetY;
        public int resolution;

        public void Clear()
        {
            viewMatrix = Matrix4x4.identity;
            projectionMatrix = Matrix4x4.identity;
            shadowTransform = Matrix4x4.identity;
            offsetX = offsetY = 0;
            resolution = 1024;
        }
    }

    [MovedFrom("UnityEngine.Rendering.LWRP")] public static class ShadowUtils
    {
        private static readonly RenderTextureFormat m_ShadowmapFormat;
        private static readonly bool m_ForceShadowPointSampling;

        static ShadowUtils()
        {
            m_ShadowmapFormat = RenderingUtils.SupportsRenderTextureFormat(RenderTextureFormat.Shadowmap) && (SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES2)
                ? RenderTextureFormat.Shadowmap
                : RenderTextureFormat.Depth;
            m_ForceShadowPointSampling = SystemInfo.graphicsDeviceType == GraphicsDeviceType.Metal &&
                GraphicsSettings.HasShaderDefine(Graphics.activeTier, BuiltinShaderDefine.UNITY_METAL_SHADOWS_USE_POINT_FILTERING);
        }

        public static bool ExtractDirectionalLightMatrix(ref CullingResults cullResults, ref ShadowData shadowData, int shadowLightIndex, int cascadeIndex, int shadowmapWidth, int shadowmapHeight, int shadowResolution, float shadowNearPlane, out Vector4 cascadeSplitDistance, out ShadowSliceData shadowSliceData, out Matrix4x4 viewMatrix, out Matrix4x4 projMatrix)
        {
            ShadowSplitData splitData;
            bool success = cullResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(shadowLightIndex,
                cascadeIndex, shadowData.mainLightShadowCascadesCount, shadowData.mainLightShadowCascadesSplit, shadowResolution, shadowNearPlane, out viewMatrix, out projMatrix,
                out splitData);

            cascadeSplitDistance = splitData.cullingSphere;
            shadowSliceData.offsetX = (cascadeIndex % 2) * shadowResolution;
            shadowSliceData.offsetY = (cascadeIndex / 2) * shadowResolution;
            shadowSliceData.resolution = shadowResolution;
            shadowSliceData.viewMatrix = viewMatrix;
            shadowSliceData.projectionMatrix = projMatrix;
            shadowSliceData.shadowTransform = GetShadowTransform(projMatrix, viewMatrix);

            // If we have shadow cascades baked into the atlas we bake cascade transform
            // in each shadow matrix to save shader ALU and L/S
            if (shadowData.mainLightShadowCascadesCount > 1)
                ApplySliceTransform(ref shadowSliceData, shadowmapWidth, shadowmapHeight);

            return success;
        }

        static void CalculateSphereFrom4Points(Vector3[] points, out Vector3 outCenter, out float outRadius)
        {
            Matrix4x4 mat = new Matrix4x4();
            for (int i = 0; i< 4; ++i)
            {
                mat.SetRow(i, new Vector4(points[i].x, points[i].y, points[i].z, 1f));
            }
            float m11 = mat.determinant;

            for (int i = 0; i< 4; ++i)
            {
                mat.SetRow(i, new Vector4(
                    points[i].x * points[i].x + points[i].y * points[i].y + points[i].z * points[i].z,
                    points[i].y,
                    points[i].z,
                    1f));
            }
            float m12 = mat.determinant;

            for (int i = 0; i< 4; ++i)
            {
                mat.SetRow(i, new Vector4(points[i].x,
                    points[i].x * points[i].x + points[i].y * points[i].y + points[i].z * points[i].z,
                    points[i].z,
                    1f));
            }
            float m13 = mat.determinant;

            for (int i = 0; i< 4; ++i)
            {
                mat.SetRow(i, new Vector4(points[i].x,
                    points[i].y,
                    points[i].x * points[i].x + points[i].y * points[i].y + points[i].z * points[i].z,
                    1f));
            }
            float m14 = mat.determinant;

            for (int i = 0; i< 4; ++i)
            {
                mat.SetRow(i, new Vector4(points[i].x * points[i].x + points[i].y * points[i].y + points[i].z * points[i].z,
                    points[i].x,
                    points[i].y,
                    points[i].z));
            }
            float m15 = mat.determinant;

            Vector3 c = new Vector3();
            c.x = 0.5f * m12 / m11;
            c.y = 0.5f * m13 / m11;
            c.z = 0.5f * m14 / m11;
            outRadius = Mathf.Sqrt(c.x* c.x + c.y* c.y + c.z* c.z - m15 / m11);
            outCenter = c;
        }

        public static void CalcualteDirectionalLightMatrix(Bounds casterBounds,
            Light light,
            Camera camera,
            int shadowmapWidth,
            int shadowmapHeight,
            out Matrix4x4 viewMatrix,
            out Matrix4x4 projMatrix)
        {
            Vector3 center = casterBounds.center;
            float castersRadius = casterBounds.extents.magnitude;
            Matrix4x4 worldMat = light.transform.localToWorldMatrix;
            Vector3 axisX = worldMat.GetColumn(0);
            Vector3 axisY = worldMat.GetColumn(1);
            Vector3 axisZ = worldMat.GetColumn(2);
            Vector3 initialLightPos = center - axisZ * castersRadius * 1.2f;
            Matrix4x4 lightMatrix = new Matrix4x4();
            lightMatrix.SetColumn(0, new Vector4(axisX.x, axisX.y, axisX.z, 0f));
            lightMatrix.SetColumn(1, new Vector4(axisY.x, axisY.y, axisY.z, 0f));
            lightMatrix.SetColumn(2, new Vector4(axisZ.x, axisZ.y, axisZ.z, 0f));
            lightMatrix.SetColumn(3, new Vector4(initialLightPos.x, initialLightPos.y, initialLightPos.z, 1f));

            Matrix4x4 frustomTransform = camera.projectionMatrix * camera.worldToCameraMatrix;
            frustomTransform = frustomTransform.inverse;
            Vector3[] cameraFrustum = new Vector3[8];
            cameraFrustum[0] = frustomTransform.MultiplyPoint(new Vector3(-1, -1, -1));
            cameraFrustum[1] = frustomTransform.MultiplyPoint(new Vector3(1, -1, -1));
            cameraFrustum[2] = frustomTransform.MultiplyPoint(new Vector3(1, 1, -1));
            cameraFrustum[3] = frustomTransform.MultiplyPoint(new Vector3(-1, 1, -1));
            cameraFrustum[4] = frustomTransform.MultiplyPoint(new Vector3(-1, -1, 1));
            cameraFrustum[5] = frustomTransform.MultiplyPoint(new Vector3(1, -1, 1));
            cameraFrustum[6] = frustomTransform.MultiplyPoint(new Vector3(1, 1, 1));
            cameraFrustum[7] = frustomTransform.MultiplyPoint(new Vector3(-1, 1, 1));

            Vector3[] cameraFrustum2 = new Vector3[4];
            Vector3[] cameraFrustum3 = new Vector3[4];
            camera.CalculateFrustumCorners(new Rect(0, 0, 1, 1),
                camera.nearClipPlane,
                Camera.MonoOrStereoscopicEye.Mono,
                cameraFrustum2);
            camera.CalculateFrustumCorners(new Rect(0, 0, 1, 1),
                camera.farClipPlane,
                Camera.MonoOrStereoscopicEye.Mono,
                cameraFrustum3);
            cameraFrustum2[0] = camera.transform.TransformPoint(cameraFrustum2[0]);
            cameraFrustum2[1] = camera.transform.TransformPoint(cameraFrustum2[1]);
            cameraFrustum2[2] = camera.transform.TransformPoint(cameraFrustum2[2]);
            cameraFrustum2[3] = camera.transform.TransformPoint(cameraFrustum2[3]);
            cameraFrustum3[0] = camera.transform.TransformPoint(cameraFrustum3[0]);
            cameraFrustum3[1] = camera.transform.TransformPoint(cameraFrustum3[1]);
            cameraFrustum3[2] = camera.transform.TransformPoint(cameraFrustum3[2]);
            cameraFrustum3[3] = camera.transform.TransformPoint(cameraFrustum3[3]);

            float nearZ = camera.nearClipPlane;
            float farZ = camera.farClipPlane;
            float shadowFarZ = 300f;
            float scaledShadowRange = shadowFarZ - nearZ;
            float frustumScale = scaledShadowRange / (farZ - nearZ);
            Vector3[] portion = new Vector3[4];
            portion[0] = cameraFrustum[0];
            portion[1] = cameraFrustum[1];
            portion[2] = Vector3.Lerp(cameraFrustum[1], cameraFrustum[5], frustumScale);
            portion[3] = Vector3.Lerp(cameraFrustum[3], cameraFrustum[7], frustumScale);

            Vector3 sphereCenter = new Vector3();
            float radius = 0f;
            //CalculateSphereFrom4Points(portion, out sphereCenter, out radius);
            sphereCenter = (portion[0] + portion[1] + portion[2] + portion[3]) / 4;
            radius = (sphereCenter - portion[0]).magnitude;
            //sphereCenter = camera.cameraToWorldMatrix.MultiplyPoint(sphereCenter);
            Vector3 p = lightMatrix.inverse.MultiplyPoint(sphereCenter);



            Bounds frustomLightLocalBounds = new Bounds();
            frustomLightLocalBounds.Encapsulate(p);
            frustomLightLocalBounds.Expand(radius);
            Vector3 stableLightPosWorld = lightMatrix.MultiplyPoint(frustomLightLocalBounds.center);
            //Vector3 stableLightPosWorld = initialLightPos;
            double texelSizeX = frustomLightLocalBounds.size.x / shadowmapWidth;
            double texelSizeY = frustomLightLocalBounds.size.y / shadowmapHeight;
            double projX = axisX.x * (double)stableLightPosWorld.x + axisX.y * (double)stableLightPosWorld.y + axisX.z * (double)stableLightPosWorld.z;
            double projY = axisY.x * (double)stableLightPosWorld.x + axisY.y * (double)stableLightPosWorld.y + axisY.z * (double)stableLightPosWorld.z;
            float modX = (float)(projX % texelSizeX);
            float modY = (float)(projY % texelSizeY);
            stableLightPosWorld -= axisX * modX;
            stableLightPosWorld -= axisY * modY;
            const float kShadowProjectionPlaneOffsetFactor = 0.1f;
            Vector3 halfFrustumBoundsSizeLocal = frustomLightLocalBounds.size * 0.5f;
            stableLightPosWorld -= axisZ * halfFrustumBoundsSizeLocal.z * (1.0f + 2.0f * kShadowProjectionPlaneOffsetFactor);
            lightMatrix.SetColumn(3, new Vector4(stableLightPosWorld.x, stableLightPosWorld.y, stableLightPosWorld.z, 1f));

            Vector3 angle = lightMatrix.rotation.eulerAngles;
            Debug.Log(angle);
            float nearPlane = halfFrustumBoundsSizeLocal.z * kShadowProjectionPlaneOffsetFactor;
            float farPlane = halfFrustumBoundsSizeLocal.z * (2.0f + 3.0f * kShadowProjectionPlaneOffsetFactor);
            //projMatrix = Matrix4x4.Ortho(-halfFrustumBoundsSizeLocal.x, halfFrustumBoundsSizeLocal.x, -halfFrustumBoundsSizeLocal.y, halfFrustumBoundsSizeLocal.y, nearPlane, farPlane);
            projMatrix = Matrix4x4.Ortho(-5, 5, -5, 5, 0.1f, farPlane);

            viewMatrix = lightMatrix;
            viewMatrix.SetColumn(2, new Vector4(-axisZ.x, -axisZ.y, -axisZ.z, 0f));
            viewMatrix = viewMatrix.inverse;
        }

        public static void CalcualteDirectionalLightMatrixEx(Bounds casterBounds,
            Light light,
            Camera camera,
            int shadowmapWidth,
            int shadowmapHeight,
            out Matrix4x4 viewMatrix,
            out Matrix4x4 projMatrix)
        {
            Vector3 center = casterBounds.center;
            float castersRadius = casterBounds.extents.magnitude;
            Matrix4x4 worldMat = light.transform.localToWorldMatrix;
            Vector3 axisX = worldMat.GetColumn(0);
            Vector3 axisY = worldMat.GetColumn(1);
            Vector3 axisZ = worldMat.GetColumn(2);
            Vector3 initialLightPos = center - axisZ * castersRadius * 1.2f;
            Matrix4x4 lightMatrix = new Matrix4x4();
            lightMatrix.SetColumn(0, new Vector4(axisX.x, axisX.y, axisX.z, 0f));
            lightMatrix.SetColumn(1, new Vector4(axisY.x, axisY.y, axisY.z, 0f));
            lightMatrix.SetColumn(2, new Vector4(axisZ.x, axisZ.y, axisZ.z, 0f));
            lightMatrix.SetColumn(3, new Vector4(initialLightPos.x, initialLightPos.y, initialLightPos.z, 1f));

            Vector3[] cameraFrustum2 = new Vector3[4];
            Vector3[] cameraFrustum3 = new Vector3[4];
            camera.CalculateFrustumCorners(new Rect(0, 0, 1, 1),
                camera.nearClipPlane,
                Camera.MonoOrStereoscopicEye.Mono,
                cameraFrustum2);
            camera.CalculateFrustumCorners(new Rect(0, 0, 1, 1),
                camera.farClipPlane,
                Camera.MonoOrStereoscopicEye.Mono,
                cameraFrustum3);
            Vector3 frustumCenter = new Vector3();
            frustumCenter.x = (cameraFrustum2[0].x + cameraFrustum2[3].x) / 2f;
            frustumCenter.y = (cameraFrustum2[0].y + cameraFrustum2[2].y) / 2f;
            frustumCenter.z = (cameraFrustum2[0].z + cameraFrustum3[0].z) / 2f;
            frustumCenter = camera.transform.TransformPoint(frustumCenter);
            Vector3 size = new Vector3();
            size.x = Mathf.Abs(cameraFrustum3[0].x - frustumCenter.x) * 2f;
            size.y = Mathf.Abs(cameraFrustum3[0].y - frustumCenter.y) * 2f;
            size.z = Mathf.Abs(cameraFrustum3[0].z - frustumCenter.z) * 2f;

//             cameraFrustum2[0] = camera.transform.TransformPoint(cameraFrustum2[0]);
//             cameraFrustum2[1] = camera.transform.TransformPoint(cameraFrustum2[1]);
//             cameraFrustum2[2] = camera.transform.TransformPoint(cameraFrustum2[2]);
//             cameraFrustum2[3] = camera.transform.TransformPoint(cameraFrustum2[3]);
//             cameraFrustum3[0] = camera.transform.TransformPoint(cameraFrustum3[0]);
//             cameraFrustum3[1] = camera.transform.TransformPoint(cameraFrustum3[1]);
//             cameraFrustum3[2] = camera.transform.TransformPoint(cameraFrustum3[2]);
//             cameraFrustum3[3] = camera.transform.TransformPoint(cameraFrustum3[3]);
            
            Bounds cameraFrustum = new Bounds(frustumCenter, size);
            Bounds intersectBounds = casterBounds;
            Vector3 min = intersectBounds.min;
            min.x = Mathf.Max(cameraFrustum.min.x, intersectBounds.min.x);
            min.y = Mathf.Max(cameraFrustum.min.y, intersectBounds.min.y);
            min.z = Mathf.Max(cameraFrustum.min.z, intersectBounds.min.z);
            intersectBounds.min = min;
            Vector3 max = intersectBounds.max;
            max.x = Mathf.Min(cameraFrustum.max.x, intersectBounds.max.x);
            max.y = Mathf.Min(cameraFrustum.max.y, intersectBounds.max.y);
            max.z = Mathf.Min(cameraFrustum.max.z, intersectBounds.max.z);
            intersectBounds.max = max;

            Vector3 position = intersectBounds.center;
            position = position - axisZ * castersRadius * 1.2f;
            lightMatrix.SetColumn(3, new Vector4(position.x, position.y, position.z, 1f));
            castersRadius = intersectBounds.extents.magnitude;
            projMatrix = Matrix4x4.Ortho(-castersRadius, castersRadius, -castersRadius, castersRadius, 0.1f, 100);

            viewMatrix = lightMatrix;
            viewMatrix.SetColumn(2, new Vector4(-axisZ.x, -axisZ.y, -axisZ.z, 0f));
            viewMatrix = viewMatrix.inverse;
        }

        public static bool ExtractSpotLightMatrix(ref CullingResults cullResults, ref ShadowData shadowData, int shadowLightIndex, out Matrix4x4 shadowMatrix, out Matrix4x4 viewMatrix, out Matrix4x4 projMatrix)
        {
            ShadowSplitData splitData;
            bool success = cullResults.ComputeSpotShadowMatricesAndCullingPrimitives(shadowLightIndex, out viewMatrix, out projMatrix, out splitData);
            shadowMatrix = GetShadowTransform(projMatrix, viewMatrix);
            return success;
        }

        public static void RenderShadowSlice(CommandBuffer cmd, ref ScriptableRenderContext context,
            ref ShadowSliceData shadowSliceData, ref ShadowDrawingSettings settings,
            Matrix4x4 proj, Matrix4x4 view)
        {
            cmd.SetViewport(new Rect(shadowSliceData.offsetX, shadowSliceData.offsetY, shadowSliceData.resolution, shadowSliceData.resolution));
            cmd.EnableScissorRect(new Rect(shadowSliceData.offsetX + 4, shadowSliceData.offsetY + 4, shadowSliceData.resolution - 8, shadowSliceData.resolution - 8));

            cmd.SetViewProjectionMatrices(view, proj);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            context.DrawShadows(ref settings);
            cmd.DisableScissorRect();
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }

        public static void SetupCustomShadow(CommandBuffer cmd,
            ref ScriptableRenderContext context,
            Rect shadowmapRerct,
            Matrix4x4 view,
            Matrix4x4 proj)
        {
            cmd.SetViewport(shadowmapRerct);
            cmd.EnableScissorRect(new Rect(4, 4, shadowmapRerct.width - 8, shadowmapRerct.height - 8));

            cmd.SetViewProjectionMatrices(view, proj);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            //context.DrawShadows(ref settings);
            
            
            //context.ExecuteCommandBuffer(cmd);
            //cmd.Clear();
        }

        public static void RenderShadowSlice(CommandBuffer cmd, ref ScriptableRenderContext context,
            ref ShadowSliceData shadowSliceData, ref ShadowDrawingSettings settings)
        {
            RenderShadowSlice(cmd, ref context, ref shadowSliceData, ref settings,
                shadowSliceData.projectionMatrix, shadowSliceData.viewMatrix);
        }

        public static int GetMaxTileResolutionInAtlas(int atlasWidth, int atlasHeight, int tileCount)
        {
            int resolution = Mathf.Min(atlasWidth, atlasHeight);
            int currentTileCount = atlasWidth / resolution * atlasHeight / resolution;
            while (currentTileCount < tileCount)
            {
                resolution = resolution >> 1;
                currentTileCount = atlasWidth / resolution * atlasHeight / resolution;
            }
            return resolution;
        }

        public static void ApplySliceTransform(ref ShadowSliceData shadowSliceData, int atlasWidth, int atlasHeight)
        {
            Matrix4x4 sliceTransform = Matrix4x4.identity;
            float oneOverAtlasWidth = 1.0f / atlasWidth;
            float oneOverAtlasHeight = 1.0f / atlasHeight;
            sliceTransform.m00 = shadowSliceData.resolution * oneOverAtlasWidth;
            sliceTransform.m11 = shadowSliceData.resolution * oneOverAtlasHeight;
            sliceTransform.m03 = shadowSliceData.offsetX * oneOverAtlasWidth;
            sliceTransform.m13 = shadowSliceData.offsetY * oneOverAtlasHeight;

            // Apply shadow slice scale and offset
            shadowSliceData.shadowTransform = sliceTransform * shadowSliceData.shadowTransform;
        }

        public static Vector4 GetShadowBias(ref VisibleLight shadowLight, int shadowLightIndex, ref ShadowData shadowData, Matrix4x4 lightProjectionMatrix, float shadowResolution)
        {
            if (shadowLightIndex < 0 || shadowLightIndex >= shadowData.bias.Count)
            {
                Debug.LogWarning(string.Format("{0} is not a valid light index.", shadowLightIndex));
                return Vector4.zero;
            }

            float frustumSize;
            if (shadowLight.lightType == LightType.Directional)
            {
                // Frustum size is guaranteed to be a cube as we wrap shadow frustum around a sphere
                frustumSize = 2.0f / lightProjectionMatrix.m00;
            }
            else if (shadowLight.lightType == LightType.Spot)
            {
                // For perspective projections, shadow texel size varies with depth
                // It will only work well if done in receiver side in the pixel shader. Currently UniversalRP
                // do bias on caster side in vertex shader. When we add shader quality tiers we can properly
                // handle this. For now, as a poor approximation we do a constant bias and compute the size of
                // the frustum as if it was orthogonal considering the size at mid point between near and far planes.
                // Depending on how big the light range is, it will be good enough with some tweaks in bias
                frustumSize = Mathf.Tan(shadowLight.spotAngle * 0.5f * Mathf.Deg2Rad) * shadowLight.range;
            }
            else
            {
                Debug.LogWarning("Only spot and directional shadow casters are supported in universal pipeline");
                frustumSize = 0.0f;
            }

            // depth and normal bias scale is in shadowmap texel size in world space
            float texelSize = frustumSize / shadowResolution;
            float depthBias = -shadowData.bias[shadowLightIndex].x * texelSize;
            float normalBias = -shadowData.bias[shadowLightIndex].y * texelSize;

            if (shadowData.supportsSoftShadows)
            {
                // TODO: depth and normal bias assume sample is no more than 1 texel away from shadowmap
                // This is not true with PCF. Ideally we need to do either
                // cone base bias (based on distance to center sample)
                // or receiver place bias based on derivatives.
                // For now we scale it by the PCF kernel size (5x5)
                const float kernelRadius = 2.5f;
                depthBias *= kernelRadius;
                normalBias *= kernelRadius;
            }

            return new Vector4(depthBias, normalBias, 0.0f, 0.0f);
        }

        public static void SetupShadowCasterConstantBuffer(CommandBuffer cmd, ref VisibleLight shadowLight, Vector4 shadowBias)
        {
            Vector3 lightDirection = -shadowLight.localToWorldMatrix.GetColumn(2);
            cmd.SetGlobalVector("_ShadowBias", shadowBias);
            cmd.SetGlobalVector("_LightDirection", new Vector4(lightDirection.x, lightDirection.y, lightDirection.z, 0.0f));
        }

        public static RenderTexture GetTemporaryShadowTexture(int width, int height, int bits)
        {
            var shadowTexture = RenderTexture.GetTemporary(width, height, bits, m_ShadowmapFormat);
            shadowTexture.filterMode = m_ForceShadowPointSampling ? FilterMode.Point : FilterMode.Bilinear;
            shadowTexture.wrapMode = TextureWrapMode.Clamp;

            return shadowTexture;
        }

        static public Matrix4x4 GetShadowTransform(Matrix4x4 proj, Matrix4x4 view)
        {
            // Currently CullResults ComputeDirectionalShadowMatricesAndCullingPrimitives doesn't
            // apply z reversal to projection matrix. We need to do it manually here.
            if (SystemInfo.usesReversedZBuffer)
            {
                proj.m20 = -proj.m20;
                proj.m21 = -proj.m21;
                proj.m22 = -proj.m22;
                proj.m23 = -proj.m23;
            }

            Matrix4x4 worldToShadow = proj * view;

            var textureScaleAndBias = Matrix4x4.identity;
            textureScaleAndBias.m00 = 0.5f;
            textureScaleAndBias.m11 = 0.5f;
            textureScaleAndBias.m22 = 0.5f;
            textureScaleAndBias.m03 = 0.5f;
            textureScaleAndBias.m23 = 0.5f;
            textureScaleAndBias.m13 = 0.5f;

            // Apply texture scale and offset to save a MAD in shader.
            return textureScaleAndBias * worldToShadow;
        }
    }
}
