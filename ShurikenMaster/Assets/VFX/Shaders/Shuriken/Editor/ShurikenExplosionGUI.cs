using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor
{
    public class ShurikenExplosionGUI : ShurikenMasterGUIBase
    {
        MaterialProperty gradientMap = null;
        MaterialProperty temperatureScale = null;
        MaterialProperty alphaScale = null;

        protected override void Initialize()
        {
            Capabilities =
                ShurikenMaster.Capabilities.CameraFading |
                ShurikenMaster.Capabilities.FlipbookBlending |
                ShurikenMaster.Capabilities.Lighting |
                ShurikenMaster.Capabilities.SoftParticles |
                ShurikenMaster.Capabilities.UseNormalMap |
                ShurikenMaster.Capabilities.PremultiplyRGBbyA;
        }

        protected override void FindAdditionalProperties(MaterialProperty[] props)
        {
            gradientMap = FindProperty("_GradientTex", props);
            temperatureScale = FindProperty("_TemperatureScale", props);
            alphaScale = FindProperty("_AlphaScale", props);
        }

        protected override void ShaderPropertiesCustomOptionsGUI(Material material)
        {
            using (new IndentScope(1))
            {
                temperatureScale.floatValue = EditorGUILayout.Slider(CustomContent.temperatureScale, temperatureScale.floatValue, 0.0f, 100.0f);
            }

            EditorGUILayout.Space();

            m_MaterialEditor.TexturePropertySingleLine(CustomContent.gradientMap, gradientMap, null);
            using (new IndentScope(1))
            {
                alphaScale.floatValue = EditorGUILayout.Slider(CustomContent.alphaScale, alphaScale.floatValue, 0.0f, 10.0f);
            }
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
            public static GUIContent temperatureMap = new GUIContent("Temperature Map", "Temperature Map");
            public static GUIContent gradientMap = new GUIContent("Fire Gradient Map", "Fire Gradient Map");
            public static GUIContent temperatureScale = new GUIContent("Scale", "Multiplier applied to temperature");
            public static GUIContent alphaScale = new GUIContent("Alpha Scale", "Multiplier applied to alpha");
        }

    }
}

