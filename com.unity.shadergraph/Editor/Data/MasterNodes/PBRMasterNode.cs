using System;
using System.Linq;
using System.Collections.Generic;
using UnityEditor.Graphing;
using UnityEditor.ShaderGraph.Drawing;
using UnityEditor.ShaderGraph.Drawing.Controls;
using UnityEditor.ShaderGraph.Internal;
using UnityEngine;
using UnityEngine.UIElements;

namespace UnityEditor.ShaderGraph
{
    [Serializable]
    [Title("Master", "PBR")]
    class PBRMasterNode : MaterialMasterNode<IPBRSubShader>, IMayRequirePosition, IMayRequireNormal, IMayRequireTangent
    {
        public const string AlbedoSlotName = "Albedo";
        public const string NormalSlotName = "Normal";
        public const string EmissionSlotName = "Emission";
        public const string MetallicSlotName = "Metallic";
        public const string SpecularSlotName = "Specular";
        public const string SmoothnessSlotName = "Smoothness";
        public const string OcclusionSlotName = "Occlusion";
        public const string AlphaSlotName = "Alpha";
        public const string AlphaClipThresholdSlotName = "AlphaClipThreshold";
        public const string StyleScaleSlotName = "StyleScale";
        public const string RimWidthSlotName = "RimWidth";
        public const string SpecularSizeSlotName = "SpecularSize";
        public const string SpecularIntensitySlotName = "SpecularIntensity";
        public const string SpecularColorSlotName = "SpecularColor";
        public const string TestColorScaleSlotName = "TestColorScale";
        public const string TestColorSlotName = "TestColor";
        public const string StyleNdotLSlotName = "StyleNdotL";
        public const string PositionName = "Vertex Position";
        public const string NormalName = "Vertex Normal";
        public const string TangentName = "Vertex Tangent";

        public const int AlbedoSlotId = 0;
        public const int NormalSlotId = 1;
        public const int MetallicSlotId = 2;
        public const int SpecularSlotId = 3;
        public const int EmissionSlotId = 4;
        public const int SmoothnessSlotId = 5;
        public const int OcclusionSlotId = 6;
        public const int AlphaSlotId = 7;
        public const int AlphaThresholdSlotId = 8;
        public const int PositionSlotId = 9;
        public const int VertNormalSlotId = 10;
        public const int VertTangentSlotId = 11;
        public const int StyleScaleSlotId = 12;
        public const int RimWidthSlotId = 13;
        public const int SpecularSizeSlotId = 14;
        public const int SpecularIntensitySlotId = 15;
        public const int SpecularColorSlotId = 16;
        public const int TestColorScaleSlotId = 17;
        public const int TestColorSlotId = 18;
        public const int StyleNdotLSlotId = 19;

        public enum Model
        {
            Specular,
            Metallic
        }

        [SerializeField]
        Model m_Model = Model.Metallic;

        public Model model
        {
            get { return m_Model; }
            set
            {
                if (m_Model == value)
                    return;

                m_Model = value;
                UpdateNodeAfterDeserialization();
                Dirty(ModificationScope.Topological);
            }
        }

        [SerializeField]
        SurfaceType m_SurfaceType;

        public SurfaceType surfaceType
        {
            get { return m_SurfaceType; }
            set
            {
                if (m_SurfaceType == value)
                    return;

                m_SurfaceType = value;
                Dirty(ModificationScope.Graph);
            }
        }

        [SerializeField]
        AlphaMode m_AlphaMode;

        public AlphaMode alphaMode
        {
            get { return m_AlphaMode; }
            set
            {
                if (m_AlphaMode == value)
                    return;

                m_AlphaMode = value;
                Dirty(ModificationScope.Graph);
            }
        }

        [SerializeField]
        PBRStyle m_PBRStyle;

        public PBRStyle pbrStyle
        {
            get { return m_PBRStyle; }
            set
            {
                if (m_PBRStyle == value)
                    return;

                m_PBRStyle = value;
                UpdateNodeAfterDeserialization();
                Dirty(ModificationScope.Topological);
                Dirty(ModificationScope.Graph);
            }
        }

        [SerializeField]
        bool m_TwoSided;

        public ToggleData twoSided
        {
            get { return new ToggleData(m_TwoSided); }
            set
            {
                if (m_TwoSided == value.isOn)
                    return;
                m_TwoSided = value.isOn;
                Dirty(ModificationScope.Graph);
            }
        }

        [SerializeField]
        NormalDropOffSpace m_NormalDropOffSpace;
        public NormalDropOffSpace normalDropOffSpace
        {
            get { return m_NormalDropOffSpace; }
            set
            {
                if (m_NormalDropOffSpace == value)
                    return;

                m_NormalDropOffSpace = value;
                if (!IsSlotConnected(NormalSlotId))
                    updateNormalSlot = true;
                UpdateNodeAfterDeserialization();
                Dirty(ModificationScope.Topological);
            }
        }
        bool updateNormalSlot;

        public PBRMasterNode()
        {
            UpdateNodeAfterDeserialization();
        }


        public sealed override void UpdateNodeAfterDeserialization()
        {
            base.UpdateNodeAfterDeserialization();
            name = "PBR Master";
            AddSlot(new PositionMaterialSlot(PositionSlotId, PositionName, PositionName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot(new NormalMaterialSlot(VertNormalSlotId, NormalName, NormalName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot(new TangentMaterialSlot(VertTangentSlotId, TangentName, TangentName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot(new ColorRGBMaterialSlot(AlbedoSlotId, AlbedoSlotName, AlbedoSlotName, SlotType.Input, Color.grey.gamma, ColorMode.Default, ShaderStageCapability.Fragment));
            //switch drop off delivery space for normal values   
            var coordSpace = CoordinateSpace.Tangent;
            if (updateNormalSlot)
            {
                RemoveSlot(NormalSlotId);
                switch (m_NormalDropOffSpace)
                {
                    case NormalDropOffSpace.Tangent:
                        coordSpace = CoordinateSpace.Tangent;
                        break;
                    case NormalDropOffSpace.World:
                        coordSpace = CoordinateSpace.World;
                        break;
                    case NormalDropOffSpace.Object:
                        coordSpace = CoordinateSpace.Object;
                        break;
                }
                updateNormalSlot = false;
            }
            AddSlot(new NormalMaterialSlot(NormalSlotId, NormalSlotName, NormalSlotName, coordSpace, ShaderStageCapability.Fragment));
            AddSlot(new ColorRGBMaterialSlot(EmissionSlotId, EmissionSlotName, EmissionSlotName, SlotType.Input, Color.black, ColorMode.Default, ShaderStageCapability.Fragment));
            if (model == Model.Metallic)
                AddSlot(new Vector1MaterialSlot(MetallicSlotId, MetallicSlotName, MetallicSlotName, SlotType.Input, 0, ShaderStageCapability.Fragment));
            else
                AddSlot(new ColorRGBMaterialSlot(SpecularSlotId, SpecularSlotName, SpecularSlotName, SlotType.Input, Color.grey, ColorMode.Default, ShaderStageCapability.Fragment));
            AddSlot(new Vector1MaterialSlot(SmoothnessSlotId, SmoothnessSlotName, SmoothnessSlotName, SlotType.Input, 0.5f, ShaderStageCapability.Fragment));
            AddSlot(new Vector1MaterialSlot(OcclusionSlotId, OcclusionSlotName, OcclusionSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
            AddSlot(new Vector1MaterialSlot(AlphaSlotId, AlphaSlotName, AlphaSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
            AddSlot(new Vector1MaterialSlot(AlphaThresholdSlotId, AlphaClipThresholdSlotName, AlphaClipThresholdSlotName, SlotType.Input, 0.0f, ShaderStageCapability.Fragment));

            if (pbrStyle == PBRStyle.Toon)
            {
                AddSlot(new Vector1MaterialSlot(StyleScaleSlotId, StyleScaleSlotName, StyleScaleSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
                AddSlot(new Vector1MaterialSlot(RimWidthSlotId, RimWidthSlotName, RimWidthSlotName, SlotType.Input, 0.716f, ShaderStageCapability.Fragment));
                AddSlot(new Vector1MaterialSlot(SpecularSizeSlotId, SpecularSizeSlotName, SpecularSizeSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
                AddSlot(new Vector1MaterialSlot(SpecularIntensitySlotId, SpecularIntensitySlotName, SpecularIntensitySlotName, SlotType.Input, 4f, ShaderStageCapability.Fragment));
                AddSlot(new ColorRGBMaterialSlot(SpecularColorSlotId, SpecularColorSlotName, SpecularColorSlotName, SlotType.Input, Color.white, ColorMode.Default, ShaderStageCapability.Fragment));
                AddSlot(new Vector1MaterialSlot(TestColorScaleSlotId, TestColorScaleSlotName, TestColorScaleSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
                AddSlot(new ColorRGBMaterialSlot(TestColorSlotId, TestColorSlotName, TestColorSlotName, SlotType.Input, Color.black, ColorMode.Default, ShaderStageCapability.Fragment));
                AddSlot(new Vector1MaterialSlot(StyleNdotLSlotId, StyleNdotLSlotName, StyleNdotLSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
            }

            // clear out slot names that do not match the slots
            // we support
            RemoveSlotsNameNotMatching(
                new[]
            {
                PositionSlotId,
                VertNormalSlotId,
                VertTangentSlotId,
                AlbedoSlotId,
                NormalSlotId,
                EmissionSlotId,
                model == Model.Metallic ? MetallicSlotId : SpecularSlotId,
                SmoothnessSlotId,
                OcclusionSlotId,
                AlphaSlotId,
                AlphaThresholdSlotId,
                StyleScaleSlotId,
                RimWidthSlotId,
                SpecularSizeSlotId,
                SpecularIntensitySlotId,
                SpecularColorSlotId,
                TestColorScaleSlotId,
                TestColorSlotId,
                StyleNdotLSlotId,
            }, true);
        }

        protected override VisualElement CreateCommonSettingsElement()
        {
            return new PBRSettingsView(this);
        }

        public NeededCoordinateSpace RequiresNormal(ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot>();
            GetSlots(slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot>();
            for (int i = 0; i < slots.Count; i++)
            {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add(slots[i]);
            }
            return validSlots.OfType<IMayRequireNormal>().Aggregate(NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresNormal(stageCapability));
        }

        public NeededCoordinateSpace RequiresPosition(ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot>();
            GetSlots(slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot>();
            for (int i = 0; i < slots.Count; i++)
            {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add(slots[i]);
            }
            return validSlots.OfType<IMayRequirePosition>().Aggregate(NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresPosition(stageCapability));
        }

        public NeededCoordinateSpace RequiresTangent(ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot>();
            GetSlots(slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot>();
            for (int i = 0; i < slots.Count; i++)
            {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add(slots[i]);
            }
            return validSlots.OfType<IMayRequireTangent>().Aggregate(NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresTangent(stageCapability));
        }
    }
}
