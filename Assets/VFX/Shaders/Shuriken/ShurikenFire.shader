Shader "VFX/Shuriken Fire" 
{
	Properties 
	{
		_MainTex ("Particle Texture", 2D) = "white" {}
		_AlphaTex("Alt Alpha Texture", 2D) = "white" {}
		_GradientTex ("Gradient Map", 2D) = "white" {}	
		[Enum(LinearLuma,0,sRGBLuma,1,Alpha,2)] _TempMapSource("TemperatureMapSource", Int) = 1
		_Brightness ("RGB Brightness Scale", Float) = 1.0
		_TemperatureScale ("Temperature Scale", Float) = 1.0	
		_AlphaScale ("Opacity Scale", Float) = 1.0

		// FLIPBOOK Blending
		[ToggleOff] _EnableFlipbookBlending("Enable Flipbook Blending", Float) = 0.0

		// Optical Flow Specific
		[ToggleOff] _EnableOFlowBlending("Enable OFlow Blending", Float) = 0.0
		_OFlowMap("OpticalFlowMap", 2D) = "white" {}
		_OFlowMorphIntensity("OpticalFlowIntensity", Float) = 1.0

		// SOFT_PARTICLES
		[ToggleOff] _SoftParticle("SoftParticle", Int) = 0
		_SoftParticleDistance ("SoftParticleDistance", Float) = 1.0

		// CAMERA_FADE
		[ToggleOff] _CameraFade ("CameraFade", Int) = 0
		_CameraFadeNear ("CameraFadeNear", Float) = 1.0
		_CameraFadeFar ("CameraFadeFar", Float) = 2.0

		// BlendMode Specific
		_Cutoff ("Cutout Treshold", Range(0.0,1.0)) = 0.25

		// Blending state

		// BlendModes: 
		// ==========
		// 			Cutout = 0
		// 			AlphaBlend = 1
		//			Additive = 2
		//			PremultipliedAlpha = 3
		//			Dithered = 4
		//			Modulate = 5
		[HideInInspector] _BlendMode ("__mode", Int) = 1
		[HideInInspector] _BlendOp ("__blendop", Int) = 0		
		[HideInInspector] _SrcBlend ("__src", Int) = 1
		[HideInInspector] _DstBlend ("__dst", Int) = 0
		[HideInInspector] _ZWrite ("__zw", Int) = 0
		[HideInInspector] _ColorSetup ("_ColorSetup", Int) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" }

		LOD 100

		Pass
		{
			Name "Main" 		
			BlendOp [_BlendOp]	
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment frag

			// multi compiles
			#pragma multi_compile_fog
			#pragma multi_compile_particles

			// SKN Master Features
			#pragma shader_feature _ALPHATEST_ON _ALPHABLEND_ON _ALPHATEST_DITHERED
			#pragma shader_feature COLORSOURCE_RGBA COLORSOURCE_ALPHA COLORSOURCE_ALTERNATEALPHA
			#pragma shader_feature VFX_DEPTHFADING
			#pragma shader_feature VFX_CAMERAFADING
			#pragma shader_feature VFX_FLIPBOOKBLEND

			#include "UnityCG.cginc"
			#include "ShurikenMaster.cginc"
			#include "ShurikenColorMap.cginc"
			
			int _TempMapSource;

			/////////////////////////////////////////////////////////////////////////////////
			// DATA STRUCTURES
			/////////////////////////////////////////////////////////////////////////////////

			struct appdata_t {

				SKM_V_DECLARE_POSITION
				SKM_V_DECLARE_COLOR
				SKM_V_DECLARE_TEXCOORD
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {

				SKM_V2F_DECLARE_POSITION
				SKM_V2F_DECLARE_COLOR
				SKM_V2F_DECLARE_TEXCOORD
				SKM_V2F_DECLARE_PROJPOS
				UNITY_FOG_COORDS(7)
				UNITY_VERTEX_OUTPUT_STEREO
			};

			/////////////////////////////////////////////////////////////////////////////////
			// VERTEX SHADER
			/////////////////////////////////////////////////////////////////////////////////

			v2f vert (appdata_t v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				SKM_VS_SETUP_POSITION
				SKM_VS_SETUP_COLOR
				SKM_VS_SETUP_PROJPOS
				SKM_VS_SETUP_CAMERAFADING
				SKM_VS_SETUP_TEXCOORD

				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			/////////////////////////////////////////////////////////////////////////////////
			// FRAGMENT SHADER
			/////////////////////////////////////////////////////////////////////////////////

			fixed4 frag (v2f i) : SV_Target
			{
				float fade = SKM_COMPUTE_PARTICLE_FADING;

				// Sample Texture / Flipbook and optionally blend 
				SKM_SAMPLE_COLOR;
				smp = SKM_COLOR_SOURCE;

				float temp;

				if (_TempMapSource < 2)
				{
					temp = dot(smp.rgb, half3(0.2126, 0.7152, 0.0722));
					if (_TempMapSource == 1)
					{
						temp = LinearToGammaSpace(temp);
					}
				}
				else
					temp = smp.a;

				temp *= i.color.a;
				temp *= fade;

				half3 color = i.color.rgb * tex2Dlod(_GradientTex, float4(temp * _TemperatureScale ,0,0,0)).rgb * _Brightness;

				float alpha = saturate(temp * i.color.a * _AlphaScale);

				UNITY_APPLY_FOG_COLOR(i.fogCoord, color, SKM_FOG_COLOR(alpha));

				// Pixel Culling (cutout and dithered)
				SKM_CULL_CUTOUT(alpha);
				SKM_CULL_DITHERED(alpha);

				
				return fixed4(color,alpha);
			}
			ENDCG 
		}
	}
	CustomEditor "ShurikenFireGUI"
}
