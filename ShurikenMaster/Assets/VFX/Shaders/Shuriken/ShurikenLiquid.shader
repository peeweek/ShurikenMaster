Shader "VFX/Shuriken Liquid"
{
	Properties
	{
		_MainTex ("Particle Texture", 2D) = "white" {}
		_AlphaTex("Alt Alpha Texture", 2D) = "white" {}
		_NormalMap ("_NormalMap", 2D) = "white" {}	
		_Murkiness("_Murkiness", Float) = 0.0
		_Refraction ("_Refraction", Float) = 0.0
		_Brightness ("RGB Brightness", Float) = 1.0

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
		[ToggleOff] _PremultiplyRGBbyA ("Premultiply Color", Int) = 0

		// Lighting state
		_LightDirectionality ("LightDirectionality", Range(0.0,1.0)) = 0.25
		// BlendModes: 
		// ==========
		// 			Cutout = 0
		// 			AlphaBlend = 1
		//			Additive = 2
		//			PremultipliedAlpha = 3
		//			Dithered = 4
		//			Modulate = 5
		[HideInInspector] _BlendMode ("__mode", Int) = 1
		[HideInInspector] _LightMode ("__lightmode", Int) = 0
		[HideInInspector] _BlendOp ("__blendop", Int) = 0		
		[HideInInspector] _SrcBlend ("__src", Int) = 1
		[HideInInspector] _DstBlend ("__dst", Int) = 0
		[HideInInspector] _ZWrite ("__zw", Int) = 0
		[HideInInspector] _ColorSetup ("_ColorSetup", Int) = 0	
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "LightMode"="ForwardBase" }

		LOD 100

        GrabPass
        {
            "_SceneColor"
        }		

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
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHATEST_DITHERED
			#pragma shader_feature COLORSOURCE_RGBA COLORSOURCE_ALPHA COLORSOURCE_ALTERNATEALPHA
			#pragma shader_feature _ VFX_LIGHTING VFX_LIGHTING_SH VFX_LIGHTING_VERTEX
			#pragma shader_feature _ VFX_USENORMALMAP		
			#pragma shader_feature _ VFX_DEPTHFADING
			#pragma shader_feature _ VFX_CAMERAFADING
			#pragma shader_feature _ VFX_FLIPBOOKBLEND

			// Defines for ShurikenMaster.cginc
			#define SKM_REQUIRE_SPECCUBE
			#define SKM_REQUIRE_GRABTEXTURE
			#define SKM_REQUIRE_NORMAL
			#define SKM_REQUIRE_TANGENT
			#define SKM_REFRACTION

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityStandardUtils.cginc"
			#include "ShurikenMaster.cginc"


			/////////////////////////////////////////////////////////////////////////////////
			// UNIFORMS
			/////////////////////////////////////////////////////////////////////////////////

			float _Murkiness;


			/////////////////////////////////////////////////////////////////////////////////
			// DATA STRUCTURES
			/////////////////////////////////////////////////////////////////////////////////

			struct appdata_t {

				SKM_V_DECLARE_POSITION
				SKM_V_DECLARE_COLOR
				SKM_V_DECLARE_TEXCOORD
				SKM_V_DECLARE_NORMAL
				SKM_V_DECLARE_TANGENT
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				SKM_V2F_DECLARE_POSITION
				SKM_V2F_DECLARE_COLOR
				SKM_V2F_DECLARE_TEXCOORD
				SKM_V2F_DECLARE_PROJPOS
				SKM_V2F_DECLARE_NORMAL
				SKM_V2F_DECLARE_TANGENT
				SKM_V2F_DECLARE_GRABPOS				
				UNITY_FOG_COORDS(8)
				UNITY_VERTEX_OUTPUT_STEREO
				#ifdef VFX_LIGHTING_VERTEX
				fixed3 lightingColor : TEXCOORD9;
				#endif
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
				SKM_VS_SETUP_NORMAL
				SKM_VS_SETUP_TANGENT
				SKM_VS_SETUP_GRABPOS

				#ifdef VFX_LIGHTING_VERTEX
					// Vertex Lighting
					o.lightingColor = SKM_GET_VERTEX_LIGHTING;
				#endif		

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

				// Remap Color 
				half4 smp_remapped = SKM_COLOR_SOURCE;

				// Apply Vertex Color and HDR Brightness 
				half4 col = i.color;

				col.a *= smp_remapped.a;

				// Calculate Normal Map
				half3 normal = SKN_PARTICLE_NORMAL;				

				float3 troubleColor = smp_remapped.rgb;
				
				#ifdef VFX_LIGHTING_VERTEX
					troubleColor *= i.lightingColor * _Brightness;
				#endif	

				troubleColor *= SKM_GET_FRAGMENT_LIGHTING(normal) * _Brightness;

				// Sample SceneColor : Transparency
				float3 refractedColor = SKN_REFRACT_SCENECOLOR;

				#ifdef VFX_USENORMALMAP
				refractedColor *= 1-pow(saturate(dot(normal, -normalize(i.worldPos - _WorldSpaceCameraPos))),12)*0.6;
				#endif
				
				col.rgb *= lerp(refractedColor * smp_remapped.rgb, troubleColor , _Murkiness);

				// Approximate reflection
				col.rgb += SKM_FastEnvironmentReflection(i.worldPos, normal);

				// Blend-mode specific stuff
				SKM_APPLY_PREMULTIPLY_ALPHA(col, smp.a);
				SKM_APPLY_FADE(col,fade);

				// Pixel Culling (cutout and dithered)
				SKM_CULL_CUTOUT(col.a);
				SKM_CULL_DITHERED(col.a);

				// Apply Fog	
				UNITY_APPLY_FOG_COLOR(i.fogCoord, col, SKM_FOG_COLOR(col.a));

				// Remap modulate
				SKM_APPLY_MODULATE(col);

				return col; 
			}
			ENDCG 
		}
	}
	CustomEditor "ShurikenLiquidGUI"	
}
