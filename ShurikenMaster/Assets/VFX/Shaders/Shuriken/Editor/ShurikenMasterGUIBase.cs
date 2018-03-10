using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor
{
    public abstract class ShurikenMasterGUIBase : ShaderGUI
    {
        protected ShurikenMaster.Capabilities Capabilities;

        protected MaterialProperty colorMap = null;
        protected MaterialProperty alternateAlphaMap = null;

        protected MaterialProperty normalMap = null;
        protected MaterialProperty rgbBrightness = null;

        protected MaterialProperty lightMode = null;
        protected MaterialProperty lightDirectionality = null;

        protected MaterialProperty colorSetup = null;
        protected MaterialProperty blendMode = null;
        protected MaterialProperty alphaCutoff = null;
        protected MaterialProperty premultiplyRGBbyA = null;

        protected MaterialProperty flipbookBlend = null;
        protected MaterialProperty flipbookOflow = null;

        protected MaterialProperty oFlowMap = null;
        protected MaterialProperty oFlowIntensity = null;

        protected MaterialProperty cameraFade = null;
        protected MaterialProperty cameraFadeNear = null;
        protected MaterialProperty cameraFadeFar = null;

        protected MaterialProperty softParticle = null;
        protected MaterialProperty softParticleDistance = null;

        protected MaterialEditor m_MaterialEditor;
        protected MiniLog m_MiniLog;

        protected bool m_FirstTimeApply = true;
        protected ProgressBar m_ProgressBar;

        protected abstract void Initialize();
        protected abstract float GetShaderComplexity(Material material);
        protected abstract void FindAdditionalProperties(MaterialProperty[] props);
        protected virtual void FindLightingProperties(MaterialProperty[] props)
        {
            lightDirectionality = FindProperty("_LightDirectionality", props);
        }

        protected abstract void ShaderPropertiesCustomOptionsGUI(Material material);

        protected bool GetCapability(ShurikenMaster.Capabilities capability)
        {
            return (Capabilities & capability) != 0;
        }

        public void FindProperties(MaterialProperty[] props)
        {
            colorMap = FindProperty("_MainTex", props);

            if (GetCapability(ShurikenMaster.Capabilities.SwitchColorSource))
                alternateAlphaMap = FindProperty("_AlphaTex", props);

            if (GetCapability(ShurikenMaster.Capabilities.UseNormalMap))
                normalMap = FindProperty("_NormalMap", props);

            alphaCutoff = FindProperty("_Cutoff", props);
            rgbBrightness = FindProperty("_Brightness", props);
            blendMode = FindProperty("_BlendMode", props);

            if(GetCapability(ShurikenMaster.Capabilities.PremultiplyRGBbyA))
                premultiplyRGBbyA = FindProperty("_PremultiplyRGBbyA", props);

            colorSetup = FindProperty("_ColorSetup", props);


            if(GetCapability(ShurikenMaster.Capabilities.FlipbookBlending))
            {
                flipbookBlend = FindProperty("_EnableFlipbookBlending", props);
                flipbookOflow = FindProperty("_EnableOFlowBlending", props);
                oFlowMap = FindProperty("_OFlowMap", props);
                oFlowIntensity = FindProperty("_OFlowMorphIntensity", props);
            }

            if (GetCapability(ShurikenMaster.Capabilities.Lighting))
            {
                lightMode = FindProperty("_LightMode", props);
                FindLightingProperties(props);
            }

            if(GetCapability(ShurikenMaster.Capabilities.CameraFading))
            {
                cameraFade = FindProperty("_CameraFade", props);
                cameraFadeNear = FindProperty("_CameraFadeNear", props);
                cameraFadeFar = FindProperty("_CameraFadeFar", props);
            }

            if(GetCapability(ShurikenMaster.Capabilities.SoftParticles))
            {
                softParticle = FindProperty("_SoftParticle", props);
                softParticleDistance = FindProperty("_SoftParticleDistance", props);
            }

            FindAdditionalProperties(props);
        }

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            if (m_ProgressBar == null)
                m_ProgressBar = new ProgressBar(Content.shaderComplexityHeader, new Vector3(0.4f, 0.666f, 0.9f));

            if (m_MiniLog == null)
                m_MiniLog = new MiniLog();

            Initialize();

            FindProperties(props); // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly

            m_MaterialEditor = materialEditor;
            Material material = materialEditor.target as Material;

            // Make sure that needed setup (ie keywords/renderqueue) are set up if we're switching some existing
            // material to a standard shader.
            // Do this before any GUI code has been issued to prevent layout issues in subsequent GUILayout statements (case 780071)
            if (m_FirstTimeApply)
            {
                MaterialChanged(material);
                HandleMiniLog(material);
                m_FirstTimeApply = false;
            }

            ShaderPropertiesGUI(material);
        }

        public void ShaderPropertiesGUI(Material material)
        {
            bool changed = false;

            m_ProgressBar.DoProgressBar(GetShaderComplexity(material));

            EditorGUILayout.Space();

            EditorGUI.BeginChangeCheck();


            ShurikenMaster.ShaderBlendMode blend = (ShurikenMaster.ShaderBlendMode)material.GetInt("_BlendMode");

            // Blending Options
            ShurikenMaster.DrawHeader(Content.blendingHeader, EditorGUIUtility.IconContent("SceneViewFx").image);

            using (new IndentScope(1))
            {
                blendMode.floatValue = (float)(ShurikenMaster.ShaderBlendMode)EditorGUILayout.EnumPopup("Blend Mode", blend);
                if (blend == ShurikenMaster.ShaderBlendMode.Cutout)
                    alphaCutoff.floatValue = EditorGUILayout.Slider(Content.alphaCutoff, alphaCutoff.floatValue, 0.0f, 1.0f);

                if (GetCapability(ShurikenMaster.Capabilities.PremultiplyRGBbyA) && blend == ShurikenMaster.ShaderBlendMode.PremultipliedAlpha)
                    premultiplyRGBbyA.floatValue = EditorGUILayout.Toggle(Content.premultiplyRGBbyA, premultiplyRGBbyA.floatValue == 1.0f) ? 1.0f : 0.0f;
            }

            EditorGUILayout.Space();

            // Lighting Options
            if(GetCapability(ShurikenMaster.Capabilities.Lighting))
            {
                ShurikenMaster.DrawHeader(Content.lightingHeader, EditorGUIUtility.IconContent("SceneViewLighting").image);

                using (new IndentScope(1))
                {
                    ShaderPropertiesLightingGUI(material);
                }

                EditorGUILayout.Space();
            }

            // Shader Options
            ShurikenMaster.DrawHeader(Content.configHeader, EditorGUIUtility.IconContent("PreTextureRGB").image);

            using (new IndentScope(1))
            {
                m_MaterialEditor.TexturePropertySingleLine(Content.colorMap, colorMap, null);

                if (GetCapability(ShurikenMaster.Capabilities.SwitchColorSource))
                {
                    ShurikenMaster.ColorSetup colorsetup = (ShurikenMaster.ColorSetup)material.GetInt("_ColorSetup");
                    if (colorsetup == ShurikenMaster.ColorSetup.RGBFromColorMapAndAlternateAlpha)
                        m_MaterialEditor.TexturePropertySingleLine(Content.alphaMap, alternateAlphaMap, null);
                    colorSetup.floatValue = (float)(ShurikenMaster.ColorSetup)EditorGUILayout.EnumPopup("Color Map Type", colorsetup);
                }

                rgbBrightness.floatValue = Mathf.Max(0, EditorGUILayout.FloatField(Content.rgbBrightness, rgbBrightness.floatValue));

                ShaderPropertiesCustomOptionsGUI(material);
            }

            EditorGUILayout.Space();

            // Other Options
            ShurikenMaster.DrawHeader(Content.optionsHeader, EditorGUIUtility.IconContent("Lighting").image);

            using (new IndentScope(1))
            {
                softParticle.floatValue = material.IsKeywordEnabled("VFX_DEPTHFADING") ? 1.0f : 0.0f;
                cameraFade.floatValue = material.IsKeywordEnabled("VFX_CAMERAFADING") ? 1.0f : 0.0f;

                softParticle.floatValue = EditorGUILayout.Toggle(Content.softParticle, softParticle.floatValue == 1.0f) ? 1.0f : 0.0f;
                if (softParticle.floatValue == 1.0f)
                    using (new IndentScope(1))
                    {
                        softParticleDistance.floatValue = EditorGUILayout.FloatField(Content.softParticleDistance, softParticleDistance.floatValue);
                    }

                cameraFade.floatValue = EditorGUILayout.Toggle(Content.cameraFade, cameraFade.floatValue == 1.0f) ? 1.0f : 0.0f;

                if (cameraFade.floatValue == 1.0f)
                {
                    using (new IndentScope(1))
                    {
                        cameraFadeNear.floatValue = EditorGUILayout.FloatField(Content.cameraFadeNear, cameraFadeNear.floatValue);
                        cameraFadeFar.floatValue = EditorGUILayout.FloatField(Content.cameraFadeFar, cameraFadeFar.floatValue);
                    }
                }
                flipbookBlend.floatValue = material.IsKeywordEnabled("VFX_FLIPBOOKBLEND") ? 1.0f : 0.0f;
                flipbookBlend.floatValue = EditorGUILayout.Toggle(Content.flipbookBlend, flipbookBlend.floatValue == 1.0f) ? 1.0f : 0.0f;

                if (flipbookBlend.floatValue == 1.0f)
                {
                    flipbookOflow.floatValue = material.IsKeywordEnabled("VFX_FLIPBOOKBLEND_OFLOW") ? 1.0f : 0.0f;
                    flipbookOflow.floatValue = EditorGUILayout.Toggle(Content.flipbookOflowBlend, flipbookOflow.floatValue == 1.0f) ? 1.0f : 0.0f;
                    if (flipbookOflow.floatValue == 1.0f)
                    {
                        using (new IndentScope(1))
                        {
                            m_MaterialEditor.TexturePropertySingleLine(Content.oFlowMap, oFlowMap, null);
                            oFlowIntensity.floatValue = EditorGUILayout.FloatField(Content.oFlowIntensity, oFlowIntensity.floatValue);
                        }
                    }
                }

            }

            // Info
            EditorGUILayout.Space();

            if (EditorGUI.EndChangeCheck())
            {
                HandleMiniLog(material);
                changed = true;
            }

            ShaderPropertiesVertexStreamsGUI(material);

            // Log
            ShurikenMaster.DrawHeader(Content.logHeader, EditorGUIUtility.ObjectContent(null, typeof(UnityEngine.UI.Text)).image);

            m_MiniLog.DoLog(80);

            if (changed)
                MaterialChanged(material);
        }

        public virtual void ShaderPropertiesLightingGUI(Material material)
        {
            ShurikenMaster.LightMode light = (ShurikenMaster.LightMode)material.GetInt("_LightMode");

            lightMode.floatValue = (float)(ShurikenMaster.LightMode)EditorGUILayout.EnumPopup("Lighting Mode", light);
            if (light == ShurikenMaster.LightMode.DynamicPerPixel || light == ShurikenMaster.LightMode.DynamicPerVertex)
            {
                if (light == ShurikenMaster.LightMode.DynamicPerPixel)
                    m_MaterialEditor.TexturePropertySingleLine(Content.normalMap, normalMap, null);
                else
                    EditorGUILayout.LabelField(Content.vertexNormals);

                using (new IndentScope(1))
                {
                    lightDirectionality.floatValue = EditorGUILayout.Slider(Content.lightDirectionality, lightDirectionality.floatValue, 0, 1);
                }
            }
        }
        protected void ShaderPropertiesVertexStreamsGUI(Material material)
        {
            bool useLighting = false;
            bool useTangents = false;
            bool useFlipbookBlending = false;
            bool useCustom1 = false;

            if (GetCapability(ShurikenMaster.Capabilities.Lighting))
            {
                ShurikenMaster.LightMode lightMode = (ShurikenMaster.LightMode)material.GetInt("_LightMode");
                useLighting = lightMode != ShurikenMaster.LightMode.Unlit;
                useTangents = lightMode != ShurikenMaster.LightMode.DynamicPerVertex && material.GetTexture("_NormalMap") != null && useLighting;
            }
            if (GetCapability(ShurikenMaster.Capabilities.FlipbookBlending))
                useFlipbookBlending = flipbookBlend.floatValue == 1.0f;

            ShurikenMaster.DrawHeader(Content.vertexStreamHeader, EditorGUIUtility.ObjectContent(null, typeof(Mesh)).image);

            if(material.IsKeywordEnabled("SKM_REQUIRE_CUSTOM1"))
                useCustom1 = false;

            using (new GUILayout.HorizontalScope())
            {
                GUILayout.FlexibleSpace();

                // Set the streams on all systems using this material
                if (GUILayout.Button(Content.streamApplyToAllSystemsText, EditorStyles.miniButton, GUILayout.Width(120)))
                {
                    List<ParticleSystemVertexStream> streams = new List<ParticleSystemVertexStream>();
                    streams.Add(ParticleSystemVertexStream.Position);

                    if (useLighting)
                        streams.Add(ParticleSystemVertexStream.Normal);

                    streams.Add(ParticleSystemVertexStream.Color);
                    streams.Add(ParticleSystemVertexStream.UV);

                    if (useFlipbookBlending)
                    {
                        streams.Add(ParticleSystemVertexStream.UV2);
                        streams.Add(ParticleSystemVertexStream.AnimBlend);
                    }

                    if(useCustom1)
                    {
                        streams.Add(ParticleSystemVertexStream.Custom1X);
                    }

                    if (useTangents)
                        streams.Add(ParticleSystemVertexStream.Tangent);

                    ParticleSystemRenderer[] renderers = UnityEngine.Object.FindObjectsOfType(typeof(ParticleSystemRenderer)) as ParticleSystemRenderer[];
                    foreach (ParticleSystemRenderer renderer in renderers)
                    {
                        if (renderer.sharedMaterial == material)
                            renderer.SetActiveVertexStreams(streams);
                    }
                }
            }

            // Display list of streams required to make this shader work
            EditorGUI.indentLevel++;
            EditorGUILayout.LabelField(Content.streamPositionText, EditorStyles.label);

            if (useLighting)
                EditorGUILayout.LabelField(Content.streamNormalText, EditorStyles.label);

            EditorGUILayout.LabelField(Content.streamColorText, EditorStyles.label);
            EditorGUILayout.LabelField(Content.streamUVText, EditorStyles.label);

            if (useFlipbookBlending)
            {
                EditorGUILayout.LabelField(Content.streamUV2Text, EditorStyles.label);
                EditorGUILayout.LabelField(Content.streamAnimBlendText, EditorStyles.label);
            }

            if (useTangents)
                EditorGUILayout.LabelField(Content.streamTangentText, EditorStyles.label);

            EditorGUI.indentLevel--;
            EditorGUILayout.Space();
        }

        protected void HandleMiniLog(Material material)
        {
            m_MiniLog.Clear();

            if(GetCapability(ShurikenMaster.Capabilities.Lighting))
            {
                ShurikenMaster.LightMode lightMode = (ShurikenMaster.LightMode)material.GetInt("_LightMode");

                if (lightMode != ShurikenMaster.LightMode.Unlit)
                {
                    m_MiniLog.Log("Ensure shuriken vertex stream declares NORMALS", MessageType.Info);
                    if (lightMode != ShurikenMaster.LightMode.DynamicPerVertex && material.GetTexture("_NormalMap") != null)
                        m_MiniLog.Log("Ensure shuriken vertex stream declares TANGENT", MessageType.Info);
                }
            }

            if (!QualitySettings.softParticles && material.GetFloat("_SoftParticle") == 1.0f)
                m_MiniLog.Log("Soft Particles needs to be enabled in your quality settings", MessageType.Warning);

        }

        public void MaterialChanged(Material material)
        {
            ShurikenMaster.SetupMaterialWithBlendMode(material, (ShurikenMaster.ShaderBlendMode)material.GetInt("_BlendMode"));
            SetMaterialKeywords(material);
        }

        public virtual void SetMaterialKeywords(Material material)
        {
            // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
            // (MaterialProperty value might come from renderer material property block)
            if(GetCapability(ShurikenMaster.Capabilities.Lighting))
            {
                // For custom lighting models
                SetLightingMaterialKeywords(material);
            }

            if (GetCapability(ShurikenMaster.Capabilities.FlipbookBlending))
            {
                ShurikenMaster.SetKeyword(material, "VFX_FLIPBOOKBLEND", material.GetFloat("_EnableFlipbookBlending") == 1.0f);
                ShurikenMaster.SetKeyword(material, "VFX_FLIPBOOKBLEND_OFLOW", material.GetFloat("_EnableOFlowBlending") == 1.0f);
            }

            if (GetCapability(ShurikenMaster.Capabilities.SoftParticles))
            {
                ShurikenMaster.SetKeyword(material, "VFX_DEPTHFADING", material.GetFloat("_SoftParticle") == 1.0f);
            }

            if (GetCapability(ShurikenMaster.Capabilities.CameraFading))
            {
                ShurikenMaster.SetKeyword(material, "VFX_CAMERAFADING", material.GetFloat("_CameraFade") == 1.0f);
            }

            if (GetCapability(ShurikenMaster.Capabilities.UseNormalMap))
            {
                ShurikenMaster.SetKeyword(material, "VFX_USENORMALMAP", material.GetTexture("_NormalMap") != null);
            }
            if (GetCapability(ShurikenMaster.Capabilities.SwitchColorSource))
            {
                ShurikenMaster.SetKeyword(material, "COLORSOURCE_RGBA", material.GetInt("_ColorSetup") == 0);
                ShurikenMaster.SetKeyword(material, "COLORSOURCE_ALPHA", material.GetInt("_ColorSetup") == 1);
                ShurikenMaster.SetKeyword(material, "COLORSOURCE_ALTERNATEALPHA", material.GetInt("_ColorSetup") == 2);
            }

        }

        public virtual void SetLightingMaterialKeywords(Material material)
        {
            ShurikenMaster.LightMode lightMode = (ShurikenMaster.LightMode)material.GetInt("_LightMode");
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING", lightMode == ShurikenMaster.LightMode.DynamicPerPixel);
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING_VERTEX", lightMode == ShurikenMaster.LightMode.DynamicPerVertex);
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING_SH", lightMode == ShurikenMaster.LightMode.LightProbeProxyVolume);
        }

        #region UI Elements
        protected static class Styles
        {
            public static GUIStyle optionsButton = new GUIStyle("PaneOptions");
        }

        protected static class Content
        {
            public static GUIContent shaderComplexityHeader = new GUIContent("Shader Complexity", "Indicates the complexity of the shader, it is totally relative and will depend on your target hardware.");
            public static GUIContent blendingHeader = new GUIContent("Blending", "Controls how the shader will blend.");
            public static GUIContent lightingHeader = new GUIContent("Lighting", "Controls how the lighting will be applied");
            public static GUIContent configHeader = new GUIContent("Configuration", "Main Options for the Shader");
            public static GUIContent optionsHeader = new GUIContent("Other Options", "Special Features");
            public static GUIContent logHeader = new GUIContent("Log", "");
            public static GUIContent vertexStreamHeader = new GUIContent("Shuriken Vertex Streams", "How the shuriken component needs to be configured");

            public static GUIContent colorMap = new GUIContent("Color Map", "Color Map");
            public static GUIContent alphaMap = new GUIContent("Alternate Alpha Map", "Alternate Alpha map : need to be configured as single channel");
            public static GUIContent normalMap = new GUIContent("Normal Map", "Normal Map");
            public static GUIContent vertexNormals = new GUIContent("Vertex Normals");
            public static GUIContent flipbookBlend = new GUIContent("Flipbook Blending", "Flipbook Texture Sheet Blending");
            public static GUIContent flipbookOflowBlend = new GUIContent("Optical Flow Blending", "Blending based on an OFlow Map");
            public static GUIContent oFlowMap = new GUIContent("Optical Flow Map", "OFlow Map used for morphing");
            public static GUIContent oFlowIntensity = new GUIContent("Optical Flow Intensity", "Morph intensity");


            public static GUIContent premultiplyRGBbyA = new GUIContent("Premultiply Color", "Premultiply Color by Alpha");

            public static GUIContent alphaCutoff = new GUIContent("Alpha Threshold", "Cutout alpha threshold");
            public static GUIContent rgbBrightness = new GUIContent("Brightness (HDR)", "Multiplier applied to RGB");
            public static GUIContent lightDirectionality = new GUIContent("Directionality", "Light Directionality Factor");
            public static GUIContent softParticle = new GUIContent("Soft Particles", "Particles fade when close to geometry behind them.");
            public static GUIContent softParticleDistance = new GUIContent("Distance", "Soft Particle fade distance, in world units");
            public static GUIContent cameraFade = new GUIContent("Camera Fade", "Particles fade when close to camera");
            public static GUIContent cameraFadeNear = new GUIContent("Near Distance", "Distance at which the particle will be invisible");
            public static GUIContent cameraFadeFar = new GUIContent("Far Distance", "Distance at which the particle will be at its top opacity");

            public static string streamPositionText = "Position (POSITION.xyz)";
            public static string streamNormalText = "Normal (NORMAL.xyz)";
            public static string streamColorText = "Color (COLOR.xyzw)";
            public static string streamUVText = "UV (TEXCOORD0.xy)";
            public static string streamUV2Text = "UV2 (TEXCOORD0.zw)";
            public static string streamAnimBlendText = "AnimBlend (TEXCOORD1.x)";
            public static string streamTangentText = "Tangent (TANGENT.xyzw)";

            public static GUIContent streamApplyToAllSystemsText = new GUIContent("Apply to Systems", "Apply the vertex stream layout to all Particle Systems using this material");

        }

        #endregion
    }
}
