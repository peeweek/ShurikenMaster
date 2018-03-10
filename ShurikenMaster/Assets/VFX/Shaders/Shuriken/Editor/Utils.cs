using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

namespace UnityEditor
{
    public class IndentScope : GUI.Scope
    {
        int m_indentLevel;

        public IndentScope(int indentLevel)
        {
            m_indentLevel = indentLevel;
            EditorGUI.indentLevel += m_indentLevel;
        }

        protected override void CloseScope()
        {
            EditorGUI.indentLevel -= m_indentLevel;
        }
    }

    public class ProgressBar
    {
        GUIContent m_Label;
        Vector3 m_Thresholds;
        public ProgressBar(GUIContent content, Vector3 thresholds)
        {
            m_Label = new GUIContent(content);
            m_Thresholds = thresholds;
        }

        public void DoProgressBar(float progress)
        {
            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUILayout.LabelField(m_Label, EditorStyles.boldLabel, GUILayout.Width(EditorGUIUtility.labelWidth));
                Rect toolbarRect = GUILayoutUtility.GetRect(EditorGUIUtility.fieldWidth, EditorGUIUtility.singleLineHeight);

                GUI.Box(toolbarRect, GUIContent.none, EditorStyles.textField);

                Rect fillRect = new Rect(toolbarRect.position, new Vector2(toolbarRect.width * progress, toolbarRect.height));
                fillRect = new RectOffset(2, 2, 2, 2).Remove(fillRect);

                Color barColor;
                if (progress < m_Thresholds.x)
                    barColor = new Color(0.4f, 1, 0.1f);
                else if (progress < m_Thresholds.y)
                    barColor = new Color(1, 1, 0.1f);
                else if (progress < m_Thresholds.z)
                    barColor = new Color(1, 0.5f, 0.1f);
                else
                    barColor = new Color(1, 0.1f, 0.1f);
                EditorGUI.DrawRect(fillRect, barColor);
            }
        }
    }

    public class MiniLog
    {
        private List<GUIContent> m_infos;
        private Vector2 m_scroll;

        public MiniLog()
        {
            m_infos = new List<GUIContent>();
            m_scroll = new Vector2();
        }

        public void Clear()
        {
            m_infos.Clear();
        }

        public void Log(string text, MessageType type, string tooltip = "")
        {
            Texture icon = null;
            switch(type)
            {
                case MessageType.Info: icon = Styles.infoIcon; break;
                case MessageType.Warning: icon = Styles.warningIcon; break;
                case MessageType.Error: icon = Styles.errorIcon; break;
            }
            m_infos.Add(new GUIContent(text, icon, tooltip));
        }

        public void DoLog(float height)
        {
            using (new GUILayout.ScrollViewScope(m_scroll, EditorStyles.textArea, GUILayout.Height(height)))
            {
                foreach (GUIContent c in m_infos)
                {
                    GUILayout.Label(c, EditorStyles.label, GUILayout.ExpandWidth(true));
                }
                GUILayout.FlexibleSpace();
            }
        }

        private static class Styles
        {
              public static Texture errorIcon = EditorGUIUtility.IconContent("console.erroricon.sml").image;
              public static Texture warningIcon = EditorGUIUtility.IconContent("console.warnicon.sml").image;
              public static Texture infoIcon = EditorGUIUtility.IconContent("console.infoicon.sml").image;
        }
    }

    public class ShurikenMaster
    {

        public enum ShaderBlendMode
        {
            Cutout = 0,
            AlphaBlend = 1,
            Additive = 2,
            PremultipliedAlpha = 3,
            Dithered = 4,
            Modulate = 5
        }

        public enum LightMode
        {
            Unlit = 0,
            DynamicPerVertex = 1,
            LightProbeProxyVolume = 2,
            DynamicPerPixel = 3
        }

        public enum ColorSetup
        {
            RGBAFromColorMap = 0,
            AlphaFromColorMap = 1,
            RGBFromColorMapAndAlternateAlpha = 2
        }

        public enum TemperatureSourceChannel
        {
            LinearLuma = 0,
            sRGBLuma = 1,
            Alpha = 2
        }

        public enum Capabilities
        {
            Lighting            = 1 << 0,
            SoftParticles       = 1 << 1,
            CameraFading        = 1 << 2,
            FlipbookBlending    = 1 << 3,
            UseNormalMap        = 1 << 4,
            Distortion          = 1 << 5,
            PremultiplyRGBbyA   = 1 << 6,
            SwitchColorSource   = 1 << 7
        }

        public static void SetupMaterialBlendStates(Material mat, BlendOp blendop, BlendMode src, BlendMode dst, bool blend, bool dither)
        {
            mat.SetOverrideTag("RenderType", blend ? "Transparent" : "TransparentCutout");
            mat.SetInt("_BlendOp", (int)blendop);
            mat.SetInt("_SrcBlend", (int)src);
            mat.SetInt("_DstBlend", (int)dst);
            mat.SetInt("_ZWrite", blend ? 0 : 1);
            SetKeyword(mat, "_ALPHATEST_ON", !blend && !dither);
            SetKeyword(mat, "_ALPHABLEND_ON", blend);
            SetKeyword(mat, "_ALPHATEST_DITHERED", !blend && dither);
            mat.renderQueue = (int) (blend? RenderQueue.Transparent: RenderQueue.AlphaTest);
        }

        public static void SetupMaterialWithBlendMode(Material material, ShurikenMaster.ShaderBlendMode blendMode)
        {
            switch (blendMode)
            {
                case ShurikenMaster.ShaderBlendMode.Cutout:
                    SetupMaterialBlendStates(material, BlendOp.Add, BlendMode.One, BlendMode.Zero, false, false);
                    break;
                case ShurikenMaster.ShaderBlendMode.Additive:
                    SetupMaterialBlendStates(material, BlendOp.Add, BlendMode.SrcAlpha, BlendMode.One, true, false);
                    break;
                case ShurikenMaster.ShaderBlendMode.AlphaBlend:
                    SetupMaterialBlendStates(material, BlendOp.Add, BlendMode.SrcAlpha, BlendMode.OneMinusSrcAlpha, true, false);
                    break;
                case ShurikenMaster.ShaderBlendMode.PremultipliedAlpha:
                    SetupMaterialBlendStates(material, BlendOp.Add, BlendMode.One, BlendMode.OneMinusSrcAlpha, true, false);
                    break;
                case ShurikenMaster.ShaderBlendMode.Dithered:
                    SetupMaterialBlendStates(material, BlendOp.Add, BlendMode.One, BlendMode.Zero, false, true);
                    break;
                case ShurikenMaster.ShaderBlendMode.Modulate:
                    SetupMaterialBlendStates(material, BlendOp.Multiply, BlendMode.DstColor, BlendMode.OneMinusSrcAlpha, true, false);
                    break;
            }
        }

        public static void SetKeyword(Material m, string keyword, bool state)
        {
            if (state)
                m.EnableKeyword (keyword);
            else
                m.DisableKeyword (keyword);
        }

        public static void DrawHeader(GUIContent title, Texture icon = null)
        {
            EditorGUILayout.Space();
            var backgroundRect = GUILayoutUtility.GetRect(1f, 24f);

            var labelRect = backgroundRect;
            labelRect.xMin += 16f;
            labelRect.xMax -= 20f;
            labelRect.yMin += 2;

            // Background rect should be full-width
            backgroundRect.xMin = 0f;
            backgroundRect.width += 4f;
            backgroundRect.yMax -= 4f;

            // Background
            float backgroundTint = EditorGUIUtility.isProSkin ? 0.1f : 1f;
            EditorGUI.DrawRect(backgroundRect, new Color(backgroundTint, backgroundTint, backgroundTint, 0.2f));

            // Title
            EditorGUI.LabelField(labelRect, title, EditorStyles.boldLabel);

            if (icon != null)
            {
                var iconRect = backgroundRect;
                iconRect.xMin += 8;
                iconRect.width = 16;
                iconRect.yMin += 2;
                GUI.Label(iconRect, icon);
            }

            // Top Line
            backgroundTint = EditorGUIUtility.isProSkin ? 0.6f : 0.2f;
            backgroundRect.height = 1;
            EditorGUI.DrawRect(backgroundRect, new Color(backgroundTint, backgroundTint, backgroundTint, 0.2f));

        }

    }

}
