using UnityEngine;
using UnityEngine.Experimental.UIElements;
using UnityEditor.Experimental.UIElements;
using UnityEngine.Experimental.UIElements.StyleEnums;


namespace UnityEditor.VFX.UIElements
{
    class ColorField : ValueControl<Color>
    {
        VisualElement m_ColorDisplay;

        VisualElement m_AlphaDisplay;
        VisualElement m_NotAlphaDisplay;
        VisualElement m_AlphaContainer;

        VisualElement m_HDRLabel;

        VisualElement m_Container;

        VisualElement CreateColorContainer()
        {
            m_Container = new VisualElement();

            m_Container.style.flexDirection = FlexDirection.Column;
            m_Container.style.alignItems = Align.Stretch;
            m_Container.style.flex = 1;
            m_Container.AddToClassList("colorcontainer");

            m_ColorDisplay = new VisualElement();
            m_ColorDisplay.style.height = 10;
            m_ColorDisplay.AddToClassList("colordisplay");

            m_AlphaDisplay = new VisualElement();
            m_AlphaDisplay.style.height = 3;
            m_AlphaDisplay.style.backgroundColor = Color.white;

            m_AlphaDisplay.AddToClassList("alphadisplay");

            m_NotAlphaDisplay = new VisualElement();
            m_NotAlphaDisplay.style.height = 3;
            m_NotAlphaDisplay.style.backgroundColor = Color.black;

            m_NotAlphaDisplay.AddToClassList("notalphadisplay");

            m_AlphaContainer = new VisualElement();
            m_AlphaContainer.style.flexDirection = FlexDirection.Row;
            m_AlphaContainer.style.height = 3;

            m_ColorDisplay.AddManipulator(new Clickable(OnColorClick));
            m_AlphaDisplay.AddManipulator(new Clickable(OnColorClick));


            m_HDRLabel = new Label() {
                pickingMode = PickingMode.Ignore,
                text = "HDR"
            };

            m_HDRLabel.style.textAlignment = TextAnchor.MiddleCenter;
            m_HDRLabel.style.positionType = PositionType.Absolute;
            m_HDRLabel.style.positionTop = 0;
            m_HDRLabel.style.positionBottom = 0;
            m_HDRLabel.style.positionLeft = 0;
            m_HDRLabel.style.positionRight = 0;

            m_HDRLabel.AddToClassList("hdr");

            m_Container.Add(m_ColorDisplay);
            m_Container.Add(m_AlphaContainer);
            m_Container.Add(m_HDRLabel);

            m_AlphaContainer.Add(m_AlphaDisplay);
            m_AlphaContainer.Add(m_NotAlphaDisplay);


            return m_Container;
        }

        bool m_ShowAlpha = true;

        public bool showAlpha
        {
            get { return m_ShowAlpha; }
            set
            {
                if (m_ShowAlpha != value)
                {
                    m_ShowAlpha = value;
                    if (m_ShowAlpha)
                    {
                        m_Container.Add(m_AlphaContainer);
                    }
                    else
                    {
                        m_AlphaContainer.RemoveFromHierarchy();
                    }
                }
            }
        }

        void OnColorClick()
        {
            if (enabledInHierarchy)
                ColorPicker.Show(OnColorChanged, m_Value, m_ShowAlpha, true);
        }

        VisualElement CreateEyeDropper()
        {
            Texture2D eyeDropperIcon = EditorGUIUtility.IconContent("EyeDropper.Large").image as Texture2D;
            VisualElement eyeDropper = new VisualElement();

            eyeDropper.style.backgroundImage = eyeDropperIcon;
            eyeDropper.style.width = eyeDropperIcon.width;
            eyeDropper.style.height = eyeDropperIcon.height;

            eyeDropper.RegisterCallback<MouseDownEvent>(OnEyeDropperStart);

            return eyeDropper;
        }

        IScheduledItem m_EyeDroppperScheduler;
        void OnEyeDropperStart(MouseDownEvent e)
        {
            EyeDropper.Start(OnColorChanged);
            m_EyeDroppperScheduler = (panel as BaseVisualElementPanel).scheduler.ScheduleUntil(OnEyeDropperMove, 10, 10, () => false);
            m_EyeDropper.UnregisterCallback<MouseDownEvent>(OnEyeDropperStart);
        }

        void OnEyeDropperMove(TimerState state)
        {
            Color pickerColor = EyeDropper.GetPickedColor();
            if (pickerColor != GetValue())
            {
                SetValue(pickerColor);
            }
        }

        VisualElement m_EyeDropper;

        public ColorField(string label) : base(label)
        {
            VisualElement container = CreateColorContainer();
            Add(container);

            m_EyeDropper = CreateEyeDropper();
            Add(m_EyeDropper);
        }

        public ColorField(Label existingLabel) : base(existingLabel)
        {
            VisualElement container = CreateColorContainer();
            Add(container);

            m_EyeDropper = CreateEyeDropper();
            Add(m_EyeDropper);
        }

        void OnColorChanged(Color color)
        {
            SetValue(color);

            if (m_EyeDroppperScheduler != null)
            {
                (panel as BaseVisualElementPanel).scheduler.Unschedule(m_EyeDroppperScheduler);
                m_EyeDroppperScheduler = null;
                m_EyeDropper.RegisterCallback<MouseDownEvent>(OnEyeDropperStart);
            }

            if (OnValueChanged != null)
                OnValueChanged();
        }

        protected override void ValueToGUI()
        {
            m_ColorDisplay.style.backgroundColor = new Color(m_Value.r, m_Value.g, m_Value.b, 1);
            m_AlphaDisplay.style.flex = m_Value.a;
            m_NotAlphaDisplay.style.flex = 1 - m_Value.a;

            bool hdr = m_Value.r > 1 || m_Value.g > 1 || m_Value.b > 1;
            if ((m_HDRLabel.parent != null) != hdr)
            {
                if (hdr)
                    m_Container.Add(m_HDRLabel);
                else
                    m_Container.Remove(m_HDRLabel);
            }
        }
    }
}
