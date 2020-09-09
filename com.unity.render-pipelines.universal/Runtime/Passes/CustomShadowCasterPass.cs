using System;
using System.Collections.Generic;

namespace UnityEngine.Rendering.Universal.Internal
{
    /// <summary>
    /// Renders a shadow map for the main Light.
    /// </summary>
    public class CustomShadowCasterPass : ScriptableRenderPass
    {
        private static class CustomShadowConstantBuffer
        {
            public static int _ShadowmapSize;
            public static int _CustomWorldToShadow;
            public static int _ShadowOffset0;
            public static int _ShadowOffset1;
            public static int _ShadowOffset2;
            public static int _ShadowOffset3;
        }

        const int k_ShadowmapBufferBits = 16;
        int m_ShadowmapWidth;
        int m_ShadowmapHeight;
        bool m_SupportsBoxFilterForShadows;
        bool m_NeedRenderShadow;
        public bool RenderCustomShadow { get { return m_NeedRenderShadow; } }

        Matrix4x4 m_ViewMatrix;
        Matrix4x4 m_ProjMatrix;

        RenderTargetHandle m_CustomShadowmap;
        RenderTargetHandle m_CustomShadowAlpha;
        RenderTexture m_CustomShadowmapTexture;
        RenderTexture m_ShadowAlphaTexture;

        Matrix4x4 m_CustomShadowMatrices;

        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();
        FilteringSettings m_FilteringSettings;

        const string m_ProfilerTag = "Render Custom Shadowmap";
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler(m_ProfilerTag);

        public CustomShadowCasterPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            m_ShaderTagIdList.Add(new ShaderTagId("CustomShadowCaster"));
            m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);

            m_CustomShadowMatrices = new Matrix4x4();

            //MainLightShadowConstantBuffer._WorldToShadow = Shader.PropertyToID("_MainLightWorldToShadow");
            CustomShadowConstantBuffer._CustomWorldToShadow = Shader.PropertyToID("_CustomWorldToShadow");
            CustomShadowConstantBuffer._ShadowmapSize = Shader.PropertyToID("_CustomShadowmapSize");
            CustomShadowConstantBuffer._ShadowOffset0 = Shader.PropertyToID("_CustomShadowOffset0");
            CustomShadowConstantBuffer._ShadowOffset1 = Shader.PropertyToID("_CustomShadowOffset1");
            CustomShadowConstantBuffer._ShadowOffset2 = Shader.PropertyToID("_CustomShadowOffset2");
            CustomShadowConstantBuffer._ShadowOffset3 = Shader.PropertyToID("_CustomShadowOffset3");
            m_CustomShadowmap.Init("_CustomShadowmapTexture");
            m_CustomShadowAlpha.Init("_CustomShadowAlphaTexture");
            m_SupportsBoxFilterForShadows = Application.isMobilePlatform || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Switch;

            m_ShadowmapWidth = 1024;
            m_ShadowmapHeight = 1024;
        }

        public bool Setup(ref RenderingData renderingData)
        {
            if (!renderingData.shadowData.supportsMainLightShadows)
                return false;

            Clear();
            int shadowLightIndex = renderingData.lightData.mainLightIndex;
            if (shadowLightIndex == -1)
                return false;

            VisibleLight shadowLight = renderingData.lightData.visibleLights[shadowLightIndex];
            Light light = shadowLight.light;
            if (light.shadows == LightShadows.None)
                return false;

            if (shadowLight.lightType != LightType.Directional)
            {
                Debug.LogWarning("Only directional lights are supported as main light.");
            }

            m_NeedRenderShadow = false;
            Bounds bounds;
            if (!UnityEngine.Rendering.Universal.ShadowManager.Instance.GetCasterBounds(out bounds))
            {
                return false;
            }
            m_NeedRenderShadow = true;

            int shadowResolution = ShadowUtils.GetMaxTileResolutionInAtlas(renderingData.shadowData.mainLightShadowmapWidth,
                renderingData.shadowData.mainLightShadowmapHeight, 1);
            m_ShadowmapWidth = 1024;
            m_ShadowmapHeight = 1024;

            ShadowUtils.CalcualteDirectionalLightMatrixEx(bounds,
                light,
                renderingData.cameraData.camera,
                m_ShadowmapWidth,
                m_ShadowmapHeight,
                out m_ViewMatrix,
                out m_ProjMatrix);

            m_CustomShadowMatrices = ShadowUtils.GetShadowTransform(m_ProjMatrix, m_ViewMatrix);
            return true;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            m_CustomShadowmapTexture = ShadowUtils.GetTemporaryShadowTexture(m_ShadowmapWidth,
                    m_ShadowmapHeight, k_ShadowmapBufferBits);
            m_ShadowAlphaTexture = ShadowUtils.GetTemporaryShadowAlphaTexture(m_ShadowmapWidth,
                m_ShadowmapHeight, 8);
            ConfigureTarget(new RenderTargetIdentifier(m_ShadowAlphaTexture),
                new RenderTargetIdentifier(m_CustomShadowmapTexture));
            ConfigureClear(ClearFlag.All, Color.black);
        }

        /// <inheritdoc/>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_NeedRenderShadow)
            {
                RenderMainLightCascadeShadowmap(ref context,
                    ref renderingData,
                    ref renderingData.cullResults,
                    ref renderingData.lightData,
                    ref renderingData.shadowData);
            }
        }

        /// <inheritdoc/>
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
                throw new ArgumentNullException("cmd");

            if (m_CustomShadowmapTexture)
            {
                RenderTexture.ReleaseTemporary(m_CustomShadowmapTexture);
                m_CustomShadowmapTexture = null;
            }
            if (m_ShadowAlphaTexture)
            {
                RenderTexture.ReleaseTemporary(m_ShadowAlphaTexture);
                m_ShadowAlphaTexture = null;
            }
        }

        void Clear()
        {
            m_CustomShadowmapTexture = null;
            m_ShadowAlphaTexture = null;
            m_CustomShadowMatrices = Matrix4x4.identity;
        }

        void RenderMainLightCascadeShadowmap(ref ScriptableRenderContext context,
            ref RenderingData renderingData,
            ref CullingResults cullResults,
            ref LightData lightData,
            ref ShadowData shadowData)
        {
            int shadowLightIndex = lightData.mainLightIndex;
            if (shadowLightIndex == -1)
                return;

            VisibleLight shadowLight = lightData.visibleLights[shadowLightIndex];

            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                var settings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortFlags);

                Vector4 shadowBias = ShadowUtils.GetShadowBias(ref shadowLight,
                    shadowLightIndex,
                    ref shadowData,
                    m_ProjMatrix,
                    m_ShadowmapWidth);
                ShadowUtils.SetupShadowCasterConstantBuffer(cmd, ref shadowLight, shadowBias);
                ShadowUtils.SetupCustomShadow(cmd,
                    ref context,
                    new Rect(0, 0, m_ShadowmapWidth, m_ShadowmapHeight),
                    m_ViewMatrix,
                    m_ProjMatrix);

                bool softShadows = shadowLight.light.shadows == LightShadows.Soft && shadowData.supportsSoftShadows;
                SetupMainLightShadowReceiverConstants(cmd, shadowLight, softShadows);
                context.DrawRenderers(renderingData.cullResults, ref settings, ref m_FilteringSettings);
                cmd.DisableScissorRect();
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        void SetupMainLightShadowReceiverConstants(CommandBuffer cmd, VisibleLight shadowLight, bool softShadows)
        {
            Light light = shadowLight.light;
            cmd.SetGlobalTexture(m_CustomShadowmap.id, m_CustomShadowmapTexture);
            cmd.SetGlobalTexture(m_CustomShadowAlpha.id, m_ShadowAlphaTexture);
            cmd.SetGlobalMatrix(CustomShadowConstantBuffer._CustomWorldToShadow, m_CustomShadowMatrices);

            if (softShadows)
            {
                float invShadowAtlasWidth = 1.0f / m_ShadowmapWidth;
                float invShadowAtlasHeight = 1.0f / m_ShadowmapHeight;
                float invHalfShadowAtlasWidth = 0.5f * invShadowAtlasWidth;
                float invHalfShadowAtlasHeight = 0.5f * invShadowAtlasHeight;
                if (m_SupportsBoxFilterForShadows)
                {
                    cmd.SetGlobalVector(CustomShadowConstantBuffer._ShadowOffset0,
                        new Vector4(-invHalfShadowAtlasWidth, -invHalfShadowAtlasHeight, 0.0f, 0.0f));
                    cmd.SetGlobalVector(CustomShadowConstantBuffer._ShadowOffset1,
                        new Vector4(invHalfShadowAtlasWidth, -invHalfShadowAtlasHeight, 0.0f, 0.0f));
                    cmd.SetGlobalVector(CustomShadowConstantBuffer._ShadowOffset2,
                        new Vector4(-invHalfShadowAtlasWidth, invHalfShadowAtlasHeight, 0.0f, 0.0f));
                    cmd.SetGlobalVector(CustomShadowConstantBuffer._ShadowOffset3,
                        new Vector4(invHalfShadowAtlasWidth, invHalfShadowAtlasHeight, 0.0f, 0.0f));
                }
                // Currently only used when !SHADER_API_MOBILE but risky to not set them as it's generic
                // enough so custom shaders might use it.
                cmd.SetGlobalVector(CustomShadowConstantBuffer._ShadowmapSize, new Vector4(invShadowAtlasWidth,
                    invShadowAtlasHeight,
                    m_ShadowmapWidth, m_ShadowmapHeight));
            }
        }
    };
}
