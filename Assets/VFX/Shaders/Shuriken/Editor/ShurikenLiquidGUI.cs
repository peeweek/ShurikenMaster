using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor
{
    public class ShurikenLiquidGUI : ShurikenMasterGUIBase
    {

        MaterialProperty murkiness = null;
        MaterialProperty refraction = null;


        protected override void Initialize()
        {
            Capabilities = ShurikenMaster.Capabilities.CameraFading |
                ShurikenMaster.Capabilities.FlipbookBlending |
                ShurikenMaster.Capabilities.SoftParticles |
                ShurikenMaster.Capabilities.Distortion |
                ShurikenMaster.Capabilities.UseNormalMap |
                ShurikenMaster.Capabilities.Lighting |
                ShurikenMaster.Capabilities.SwitchColorSource;
        }

        protected override void FindAdditionalProperties(MaterialProperty[] props)
        {
            murkiness = FindProperty("_Murkiness", props);
            refraction = FindProperty("_Refraction", props);
        }

        protected override void ShaderPropertiesCustomOptionsGUI(Material material)
        {
            murkiness.floatValue = EditorGUILayout.Slider(CustomContent.murkiness, murkiness.floatValue, 0.0f, 1.0f);
            refraction.floatValue = Mathf.Pow(EditorGUILayout.Slider(CustomContent.refraction, Mathf.Pow(refraction.floatValue,0.2f), 0.0f, 1.0f), 5.0f);
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
            public static GUIContent murkiness = new GUIContent("Murkiness", "Opacity of the medium");
            public static GUIContent refraction = new GUIContent("Refraction", "Intensity of the refraction effect");
        }
    }
}
