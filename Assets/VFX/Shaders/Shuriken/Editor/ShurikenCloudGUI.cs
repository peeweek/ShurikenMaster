using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor
{
    public class ShurikenCloudGUI : ShurikenMasterGUIBase
    {
        public enum CloudLightMode
        {
            FakeDirectional = 0,
            DynamicPerPixel = 3,
            Raymarch2D = 4
        }


        MaterialProperty cloudAttenuationRamp = null;
        MaterialProperty cloudBackScattering = null;

        MaterialProperty fakeLightDirection = null;
        MaterialProperty fakeLightColor = null;
        MaterialProperty fakeLightIntensity = null;

        protected override void FindAdditionalProperties(MaterialProperty[] props) { }

        protected override void FindLightingProperties(MaterialProperty[] props)
        {
            cloudAttenuationRamp = FindProperty("_CloudAttenuationRamp", props);
            cloudBackScattering = FindProperty("_CloudBackScattering", props);
            fakeLightDirection = FindProperty("_FakeLightDirection", props);
            fakeLightColor = FindProperty("_FakeLightColor", props);
            fakeLightIntensity = FindProperty("_FakeLightIntensity", props);
        }

        protected override void Initialize()
        {
            Capabilities =
                ShurikenMaster.Capabilities.CameraFading |
                ShurikenMaster.Capabilities.FlipbookBlending |
                ShurikenMaster.Capabilities.Lighting |
                ShurikenMaster.Capabilities.SoftParticles |
                ShurikenMaster.Capabilities.UseNormalMap |
                ShurikenMaster.Capabilities.PremultiplyRGBbyA |
                ShurikenMaster.Capabilities.SwitchColorSource;
        }

        public override void ShaderPropertiesLightingGUI(Material material)
        {
            CloudLightMode light = (CloudLightMode)material.GetInt("_LightMode");

            lightMode.floatValue = (float)(CloudLightMode)EditorGUILayout.EnumPopup("Lighting Mode", light);
            m_MaterialEditor.TexturePropertySingleLine(CustomContent.cloudAttenuationRamp, cloudAttenuationRamp);
            if (lightMode.floatValue == (float)CloudLightMode.FakeDirectional)
            {
                EditorGUILayout.LabelField(CustomContent.fakeLightHeader, EditorStyles.boldLabel);
                using (new IndentScope(1))
                {
                    fakeLightDirection.vectorValue = EditorGUILayout.Vector3Field(CustomContent.fakeLightDirection, fakeLightDirection.vectorValue);
                    fakeLightColor.colorValue = EditorGUILayout.ColorField(CustomContent.fakeLightColor, fakeLightColor.colorValue);
                    fakeLightIntensity.floatValue = EditorGUILayout.FloatField(CustomContent.fakeLightIntensity, fakeLightIntensity.floatValue);
                }
            }

            if (light == CloudLightMode.DynamicPerPixel || light == CloudLightMode.FakeDirectional)
                m_MaterialEditor.TexturePropertySingleLine(Content.normalMap, normalMap, null);
            else
                EditorGUILayout.LabelField(Content.vertexNormals);

            cloudBackScattering.floatValue = EditorGUILayout.Slider(CustomContent.cloudBackScattering, cloudBackScattering.floatValue, 0.0f, 1.0f);

        }
        protected override void ShaderPropertiesCustomOptionsGUI(Material material)
        {
            // Nothing here, as the options are mostly lighting
        }

        public override void SetLightingMaterialKeywords(Material material)
        {
            CloudLightMode lightMode = (CloudLightMode)material.GetInt("_LightMode");
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING", lightMode == CloudLightMode.DynamicPerPixel);
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING_FAKEDIRECTIONAL", lightMode == CloudLightMode.FakeDirectional);
            ShurikenMaster.SetKeyword(material, "VFX_LIGHTING_RAYMARCH2D", lightMode == CloudLightMode.Raymarch2D);
        }

        protected override float GetShaderComplexity(Material material)
        {
            float c = 0.0f;
            bool useNormalMap = material.GetTexture("_NormalMap") != null;
            // Light Mode 0 .. 45%
            switch((ShurikenMaster.LightMode)material.GetFloat("_LightMode"))
            {
                case ShurikenMaster.LightMode.Unlit: c += 0.00f; break;
                case ShurikenMaster.LightMode.DynamicPerVertex: c += 0.05f; break;
                case ShurikenMaster.LightMode.LightProbeProxyVolume: c += 0.1f;
                    c += useNormalMap ? 0.15f : 0.0f;
                    break;
                case ShurikenMaster.LightMode.DynamicPerPixel: c += 0.30f;
                    c += useNormalMap ? 0.15f : 0.0f;
                    break;
            }

            // Features 0 .. 25%
            c += material.GetFloat("_SoftParticle") == 1.0f ? 0.10f : 0.0f ;
            c += material.GetFloat("_CameraFade") == 1.0f ? 0.02f : 0.0f ;
            c += material.GetFloat("_EnableFlipbookBlending") == 1.0f ? 0.10f : 0.0f ;

            // Blend Mode 0 .. 35%
            switch((ShurikenMaster.ShaderBlendMode)material.GetInt("_BlendMode"))
            {
                case ShurikenMaster.ShaderBlendMode.Cutout: c += 0.05f; break;
                case ShurikenMaster.ShaderBlendMode.Dithered: c += 0.35f; break;
                case ShurikenMaster.ShaderBlendMode.Additive:
                case ShurikenMaster.ShaderBlendMode.AlphaBlend:
                case ShurikenMaster.ShaderBlendMode.Modulate:
                case ShurikenMaster.ShaderBlendMode.PremultipliedAlpha:
                    c += 0.25f; break;
            }
            return Mathf.Clamp01(c);
        }


        private static class CustomContent
        {

            public static GUIContent cloudAttenuationRamp = new GUIContent("Attenuation Ramp", "Gradient containing the filtered frequences of the cloud");
            public static GUIContent cloudBackScattering = new GUIContent("Scattering");

            public static GUIContent fakeLightHeader = new GUIContent("Fake Directional Light Properties");
            public static GUIContent fakeLightDirection = new GUIContent("Direction", "");
            public static GUIContent fakeLightColor = new GUIContent("Color", "");
            public static GUIContent fakeLightIntensity = new GUIContent("Intensity", "");
        }
    }
}

