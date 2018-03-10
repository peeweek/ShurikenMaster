/////////////////////////////////////////////////////////////////////////////////
// UNIFORMS
/////////////////////////////////////////////////////////////////////////////////

#if defined(VFX_LIGHTING) || defined(VFX_LIGHTING_SH) || defined(VFX_LIGHTING_VERTEX)
	#define SKM_REQUIRE_NORMAL
#endif

#if (defined(VFX_LIGHTING) || defined(VFX_LIGHTING_SH)) && defined(VFX_USENORMALMAP)
	#define SKM_REQUIRE_TANGENT
#endif

#if (defined(SOFTPARTICLES_ON) && defined(VFX_DEPTHFADING)) || (defined(VFX_CAMERAFADING))
	#define SKM_REQUIRE_PROJPOS
#endif

#if defined(SOFTPARTICLES_ON) && defined(VFX_DEPTHFADING)
	#define SKM_REQUIRE_ZBUFFER
#endif

#if defined(VFX_LIGHTING) || defined(VFX_LIGHTING_SH)
	#define SKM_REQUIRE_4LIGHTCBUFFER
#endif

/////////////////////////////////////////////////////////////////////////////////
// UNIFORMS
/////////////////////////////////////////////////////////////////////////////////

UNITY_DECLARE_TEX2D(_MainTex);
int _BlendMode;

int _PremultiplyRGBbyA;
float _Brightness;

#ifdef COLORSOURCE_ALTERNATEALPHA
UNITY_DECLARE_TEX2D(_AlphaTex);
#endif

#ifdef SKM_REQUIRE_ZBUFFER
float _SoftParticleDistance;
sampler2D_float _CameraDepthTexture;
#endif

#ifdef VFX_CAMERAFADING
float _CameraFadeNear; 
float _CameraFadeFar;
#endif

#ifdef _ALPHATEST_ON
float _Cutoff;
#endif

#ifdef VFX_USENORMALMAP
UNITY_DECLARE_TEX2D(_NormalMap);
#endif

#ifdef VFX_FLIPBOOKBLEND_OFLOW
UNITY_DECLARE_TEX2D(_OFlowMap);
float _OFlowMorphIntensity;
#endif

/////////////////////////////////////////////////////////////////////////////////
// FEATURE DECLARATIONS
/////////////////////////////////////////////////////////////////////////////////

#define SKM_V_DECLARE_POSITION float4 vertex : POSITION;
#define SKM_V2F_DECLARE_POSITION float4 vertex : SV_POSITION;
#define SKM_VS_SETUP_POSITION o.vertex = UnityObjectToClipPos(v.vertex);

#define SKM_V_DECLARE_COLOR fixed4 color : COLOR;
#define SKM_V2F_DECLARE_COLOR half4 color : COLOR;
#define SKM_VS_SETUP_COLOR o.color = v.color;


#ifdef VFX_FLIPBOOKBLEND
	#ifdef SKM_REQUIRE_CUSTOM1
		#define SKM_V_DECLARE_TEXCOORD	float4 texcoord : TEXCOORD0;	float4 texcoordBlendFrame : TEXCOORD1;
		#define SKM_V2F_DECLARE_TEXCOORD float4 texcoord : TEXCOORD0;	nointerpolation float blend : TEXCOORD1; nointerpolation float custom1 : TEXCOORD2;
		#define SKM_VS_SETUP_TEXCOORD	o.texcoord.xy = v.texcoord;	o.texcoord.zw = v.texcoord.zw;	o.blend = v.texcoordBlendFrame.x; o.custom1 = v.texcoordBlendFrame.y;
	#else
		#define SKM_V_DECLARE_TEXCOORD float4 texcoord : TEXCOORD0; float4 texcoordBlendFrame : TEXCOORD1;
		#define SKM_V2F_DECLARE_TEXCOORD float4 texcoord : TEXCOORD0; nointerpolation float blend : TEXCOORD1;
		#define SKM_VS_SETUP_TEXCOORD o.texcoord.xy = v.texcoord; o.texcoord.zw = v.texcoord.zw; o.blend = v.texcoordBlendFrame.x;
	#endif
#else
	#ifdef SKM_REQUIRE_CUSTOM1
		#define SKM_V_DECLARE_TEXCOORD float3 texcoord : TEXCOORD0;
		#define SKM_V2F_DECLARE_TEXCOORD float2 texcoord : TEXCOORD0; float custom1 : TEXCOORD1;
#define SKM_VS_SETUP_TEXCOORD o.texcoord.xy = v.texcoord.xy; o.custom1.x = v.texcoord.z;
	#else
		#define SKM_V_DECLARE_TEXCOORD float2 texcoord : TEXCOORD0;
		#define SKM_V2F_DECLARE_TEXCOORD float2 texcoord : TEXCOORD0;
		#define SKM_VS_SETUP_TEXCOORD o.texcoord.xy = v.texcoord;
	#endif
#endif

#ifdef SKM_REQUIRE_NORMAL
	#define SKM_V_DECLARE_NORMAL float3 normal : NORMAL;
	#define SKM_V2F_DECLARE_NORMAL	float3 worldPos : TEXCOORD4; float3 normal : TEXCOORD5;
	#define SKM_VS_SETUP_NORMAL o.worldPos = mul(v.vertex, unity_ObjectToWorld); o.normal = mul( float4(v.normal, 0) , unity_ObjectToWorld);			
#else
	#define SKM_V_DECLARE_NORMAL 
	#define SKM_V2F_DECLARE_NORMAL
	#define SKM_VS_SETUP_NORMAL
#endif

#ifdef SKM_REQUIRE_TANGENT
	#define SKM_V_DECLARE_TANGENT float4 tangent : TANGENT;
	#define SKM_V2F_DECLARE_TANGENT	float4 tangent : TEXCOORD6;
	#define SKM_VS_SETUP_TANGENT o.tangent = mul(v.tangent, unity_ObjectToWorld);
#else
	#define SKM_V_DECLARE_TANGENT 
	#define SKM_V2F_DECLARE_TANGENT
	#define SKM_VS_SETUP_TANGENT
#endif

#ifdef SKM_REQUIRE_PROJPOS
	#define SKM_V2F_DECLARE_PROJPOS float4 projPos : TEXCOORD3;
	#define SKM_VS_SETUP_PROJPOS o.projPos = ComputeScreenPos (o.vertex); COMPUTE_EYEDEPTH(o.projPos.z);
#else
	#define SKM_V2F_DECLARE_PROJPOS
	#define SKM_VS_SETUP_PROJPOS
#endif

#ifdef VFX_CAMERAFADING
	#define SKM_VS_SETUP_CAMERAFADING if(o.projPos.z < _CameraFadeNear) o.vertex.xyz = float3(-1,-1,-1); // Cull near vertices when camera fading.
#else
	#define SKM_VS_SETUP_CAMERAFADING
#endif

#ifdef SKM_REQUIRE_GRABTEXTURE
	#define SKM_V2F_DECLARE_GRABPOS float4 grabPos : TEXCOORD7;
	#define SKM_VS_SETUP_GRABPOS o.grabPos = ComputeGrabScreenPos(o.vertex);
#else
	#define SKM_V2F_DECLARE_GRABPOS
	#define SKM_VS_SETUP_GRABPOS
#endif

/////////////////////////////////////////////////////////////////////////////////
// FADING (DEPTH & CAMERA)
/////////////////////////////////////////////////////////////////////////////////

#if (defined(SOFTPARTICLES_ON) && defined(VFX_DEPTHFADING) ) || defined(VFX_CAMERAFADING)

	#define SKM_COMPUTE_PARTICLE_FADING ComputeFading(i.projPos)

	float ComputeFading(float4 projPos)
	{
		float fade = 1.0f;

		// Sample Scene Depth and apply soft particles
		float partZ = projPos.z;

		#if defined(SOFTPARTICLES_ON) && defined(VFX_DEPTHFADING)
		float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(projPos)));
		fade *= saturate ((sceneZ-partZ)/_SoftParticleDistance);
		fade *= fade; // Squared attenuation produces better results
		#endif

		// Apply Camera Fade
		#ifdef VFX_CAMERAFADING
		fade *= saturate((partZ - _CameraFadeNear) / (_CameraFadeFar - _CameraFadeNear));
		#endif

		return fade;
	}

#else

	#define SKM_COMPUTE_PARTICLE_FADING 1.0f

#endif

/////////////////////////////////////////////////////////////////////////////////
// TEXTURE SAMPLING (BASED ON FLIPBOOK BLEND)
/////////////////////////////////////////////////////////////////////////////////

#ifdef VFX_FLIPBOOKBLEND

#ifdef VFX_FLIPBOOKBLEND_OFLOW

//float4 OpticalFlowSample(sampler2D smp, float4 texcoord, float blend)
//{
//	float2 morph1 = UNITY_SAMPLE_TEX2D(_OFlowMap, texcoord.xy).xy - 0.5;
//	float2 morph2 = UNITY_SAMPLE_TEX2D(_OFlowMap, texcoord.zw).xy - 0.5;
//	float2 uv1 = texcoord.xy + morph1 * (blend) * _OFlowMorphIntensity;
//	float2 uv2 = texcoord.zw - morph2 * (1-blend) * _OFlowMorphIntensity;
//	return float4(1,1,0,1);
//	return  lerp(tex2D(smp, uv1), tex2D(smp, uv2), blend);
//}
//		#define SKM_SAMPLE_FLIPBOOK(smp,texcoord) OpticalFlowSample(smp, texcoord, i.blend)
	
		#define SKM_SAMPLE_FLIPBOOK(smp,texcoord) lerp(UNITY_SAMPLE_TEX2D(smp, texcoord.xy - (UNITY_SAMPLE_TEX2D(_OFlowMap, texcoord.xy).xy - 0.5) * (i.blend) * _OFlowMorphIntensity), UNITY_SAMPLE_TEX2D(smp, texcoord.zw + (UNITY_SAMPLE_TEX2D(_OFlowMap, texcoord.zw).xy - 0.5) * (1-i.blend) * _OFlowMorphIntensity), i.blend)
	#else
		#define SKM_SAMPLE_FLIPBOOK(smp,texcoord) lerp(UNITY_SAMPLE_TEX2D(smp, texcoord.xy), UNITY_SAMPLE_TEX2D(smp, texcoord.zw), i.blend)
	#endif
#else
	#define SKM_SAMPLE_FLIPBOOK(smp,texcoord) UNITY_SAMPLE_TEX2D(smp, texcoord)
#endif



/////////////////////////////////////////////////////////////////////////////////
// COLOR SAMPLING 
/////////////////////////////////////////////////////////////////////////////////

#if defined(COLORSOURCE_RGBA) || defined(COLORSOURCE_ALPHA)
	#define SKM_SAMPLE_COLOR half4 smp = SKM_SAMPLE_FLIPBOOK(_MainTex, i.texcoord)
#endif

#if defined(COLORSOURCE_ALTERNATEALPHA)
	#define SKM_SAMPLE_COLOR half4 smp = SKM_SAMPLE_FLIPBOOK(_MainTex, i.texcoord); half4 smp_altAlpha = SKM_SAMPLE_FLIPBOOK(_AlphaTex, i.texcoord);
#endif


/////////////////////////////////////////////////////////////////////////////////
// COLOR MAPPING (COLOR MAP TYPE)
/////////////////////////////////////////////////////////////////////////////////

#ifdef COLORSOURCE_RGBA
	#define SKM_COLOR_SOURCE smp
#endif

#ifdef COLORSOURCE_ALPHA
	#define SKM_COLOR_SOURCE float4(1,1,1,smp.a)
#endif

#ifdef COLORSOURCE_ALTERNATEALPHA
	#define SKM_COLOR_SOURCE float4(smp.rgb, smp_altAlpha.a)
#endif

/////////////////////////////////////////////////////////////////////////////////
// NORMALMAP COMPUTATION
/////////////////////////////////////////////////////////////////////////////////

#ifdef VFX_USENORMALMAP

	#define SKN_PARTICLE_NORMAL SKM_ComputeWorldNormalMap(SKM_SAMPLE_FLIPBOOK(_NormalMap, i.texcoord), i.normal, i.tangent)

	half3 SKM_ComputeWorldNormalMap(half4 sampledNormal, float3 normal, float4 tangent )
	{
		half3 binormal = cross( normalize(normal), normalize(tangent.xyz) ) * tangent.w;
		half3x3 tbn = float3x3( tangent.xyz, binormal, normal );
		return normalize(mul(UnpackNormal(sampledNormal), tbn));
	}

#else
	#define SKN_PARTICLE_NORMAL i.normal
#endif

/////////////////////////////////////////////////////////////////////////////////
// TANGENT COMPUTATION
/////////////////////////////////////////////////////////////////////////////////

#ifdef SKM_REQUIRE_TANGENT
	#define SKN_PARTICLE_TANGENT i.tangent
#else
	#define SKN_PARTICLE_TANGENT float3(0,0,0)
#endif

/////////////////////////////////////////////////////////////////////////////////
// FOG COMPUTATION
/////////////////////////////////////////////////////////////////////////////////

#define SKM_FOG_COLOR(opacity) SKM_GetFogColor(opacity)

fixed4 SKM_GetFogColor(float opacity)
{
	fixed4 fogColor = unity_FogColor;

	switch((int)_BlendMode)
	{					
		case 2:	//	Additive = 2		
			fogColor = fixed4(0,0,0,0); // fog towards black due to our blend mode
			break;					
		case 3: //	Premultiplied = 3
			fogColor =  unity_FogColor * opacity;
			break;
		case 5:	//	Modulate = 5				
			fogColor = fixed4(0,0,0,0);				
			break;																							
	}

	return fogColor;
}

/////////////////////////////////////////////////////////////////////////////////
// CUTOUT
/////////////////////////////////////////////////////////////////////////////////

#ifdef _ALPHATEST_ON
	#define SKM_CULL_CUTOUT(alpha) clip(alpha - _Cutoff)
#else
	#define SKM_CULL_CUTOUT(alpha)
#endif


/////////////////////////////////////////////////////////////////////////////////
// BLEND MODE SPECIFIC
/////////////////////////////////////////////////////////////////////////////////

#define SKM_BLEND_CUTOUT 0
#define SKM_BLEND_ALPHABLEND 1
#define SKM_BLEND_ADDITIVE 2
#define SKM_BLEND_PREMULTIPLIEDALPHA 3
#define SKM_BLEND_DITHERED 4
#define SKM_BLEND_MODULATE 5

#define SKM_APPLY_PREMULTIPLY_ALPHA(color, alpha) if(_PremultiplyRGBbyA && _BlendMode == 3) color.rgb *= alpha;
#define SKM_APPLY_FADE(color, fade) if(_BlendMode < SKM_BLEND_PREMULTIPLIEDALPHA) color.a *= fade; else color *= fade;
#define SKM_APPLY_MODULATE(color) if((int)_BlendMode == SKM_BLEND_MODULATE) color = half4(lerp(half3(1,1,1),color.rgb,color.a),1);

/////////////////////////////////////////////////////////////////////////////////
// LIGHTING UTILITY
/////////////////////////////////////////////////////////////////////////////////

#ifdef SKM_REQUIRE_4LIGHTCBUFFER

struct DirectionalLightInfo
{
	float3 direction;
	float3 color;
};

struct PointLightInfo
{
	float3 position;
	float attenuation;
	float3 direction;
	float3 color;
};

struct LightingInfo
{
	DirectionalLightInfo directional;
	PointLightInfo pointLight1;
	PointLightInfo pointLight2;
	PointLightInfo pointLight3;
	PointLightInfo pointLight4;
};

LightingInfo GetLightingInfo(float3 pos)
{
	LightingInfo o;
	DirectionalLightInfo directional;
	PointLightInfo pointLight1;
	PointLightInfo pointLight2;
	PointLightInfo pointLight3;
	PointLightInfo pointLight4;

	// Directional Light
	directional.direction = _WorldSpaceLightPos0.xyz;
	directional.color = _LightColor0;

	// 4-PointLight
	float4 lightPosX = unity_4LightPosX0;
	float4 lightPosY = unity_4LightPosY0;
	float4 lightPosZ = unity_4LightPosZ0;
	float4 lightAttenSq = unity_4LightAtten0;

	// to light vectors
	float4 toLightX = lightPosX - pos.x;
	float4 toLightY = lightPosY - pos.y;
	float4 toLightZ = lightPosZ - pos.z;

	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;
	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001); 

	half4 atten = pow(1 - saturate(lightAttenSq*lengthSq*0.03), 2);

	pointLight1.position = float3(lightPosX.x, lightPosY.x, lightPosZ.x);
	pointLight2.position = float3(lightPosX.y, lightPosY.y, lightPosZ.y);
	pointLight3.position = float3(lightPosX.z, lightPosY.z, lightPosZ.z);
	pointLight4.position = float3(lightPosX.w, lightPosY.w, lightPosZ.w);

	pointLight1.attenuation = atten.x;
	pointLight2.attenuation = atten.y;
	pointLight3.attenuation = atten.z;
	pointLight4.attenuation = atten.w;

	pointLight1.direction = float3(toLightX.x, toLightY.x, toLightZ.x);
	pointLight2.direction = float3(toLightX.y, toLightY.y, toLightZ.y);
	pointLight3.direction = float3(toLightX.z, toLightY.z, toLightZ.z);
	pointLight4.direction = float3(toLightX.w, toLightY.w, toLightZ.w);

	pointLight1.color = unity_LightColor[0].rgb;
	pointLight2.color = unity_LightColor[1].rgb;
	pointLight3.color = unity_LightColor[2].rgb;
	pointLight4.color = unity_LightColor[3].rgb;

	o.directional = directional;
	o.pointLight1 = pointLight1;
	o.pointLight2 = pointLight2;
	o.pointLight3 = pointLight3;
	o.pointLight4 = pointLight4;

	return o;
}

float LambertNdotL(float3 n, float3 l)
{
	return dot(n, l)*0.5 + 0.5;
}

float NdotL(float3 n, float3 l)
{
	return saturate(dot(n, l));
}

#endif

/////////////////////////////////////////////////////////////////////////////////
// LIGHTING
/////////////////////////////////////////////////////////////////////////////////

#if defined(VFX_LIGHTING) || defined(VFX_LIGHTING_VERTEX)

float _LightDirectionality;

half3 SKM_ShadeDynamicLighting (float3 pos, half3 normal, half directionality)
{
	float4 lightPosX = unity_4LightPosX0; 
	float4 lightPosY = unity_4LightPosY0; 
	float4 lightPosZ = unity_4LightPosZ0;
	
	float3 lightColor0 = unity_LightColor[0].rgb; 
	float3 lightColor1 = unity_LightColor[1].rgb; 
	float3 lightColor2 = unity_LightColor[2].rgb; 
	float3 lightColor3 = unity_LightColor[3].rgb;
	float4 lightAttenSq = unity_4LightAtten0;

	// to light vectors
	float4 toLightX = lightPosX - pos.x;
	float4 toLightY = lightPosY - pos.y;
	float4 toLightZ = lightPosZ - pos.z;

	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;
	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001);

	// NdotL
	half4 ndotl = 0;
	ndotl += toLightX * normal.x;
	ndotl += toLightY * normal.y;
	ndotl += toLightZ * normal.z;

	// correct NdotL
	half4 corr = rsqrt(lengthSq);
	ndotl = (ndotl * corr)*0.5f+0.5f;
	ndotl *= ndotl;

	// attenuation
	half4 atten = pow(1-saturate(lightAttenSq*lengthSq*0.03),2);
	half4 diff = ndotl * atten;
	// final color
	half3 col = 0;
	col += lightColor0 * lerp(atten.x, diff.x, directionality);
	col += lightColor1 * lerp(atten.y, diff.y, directionality);
	col += lightColor2 * lerp(atten.z, diff.z, directionality);
	col += lightColor3 * lerp(atten.w, diff.w, directionality);

	// Additional Directional light
	half3 lightDirectionalDir = _WorldSpaceLightPos0.xyz;
	half4 lightDirectionalColor = _LightColor0;

	half diffDirectional = (dot(normal.xyz,lightDirectionalDir))*0.5f+0.5f;
	diffDirectional *= diffDirectional;

	col += lightDirectionalColor * lerp(1, diffDirectional, directionality);

	// Ambient
	col += ShadeSH9(half4(lerp(half3(0,1,0),normal,directionality),1));

	return col;
}

#endif

// Per vertex
#ifdef VFX_LIGHTING_VERTEX
	#define SKM_GET_VERTEX_LIGHTING SKM_ShadeDynamicLighting( mul(v.vertex, unity_ObjectToWorld) , mul(half4(v.normal,0), unity_ObjectToWorld), _LightDirectionality)
#else
	#define SKM_GET_VERTEX_LIGHTING 1
#endif

// Per pixel
#if defined(VFX_LIGHTING) || defined(VFX_LIGHTING_SH)

	#ifdef VFX_LIGHTING_SH
		#define SKM_GET_FRAGMENT_LIGHTING(normal) ShadeSHPerPixel( normal , 0.0f,i.worldPos)
	#endif

	#ifdef VFX_LIGHTING
		#define SKM_GET_FRAGMENT_LIGHTING(normal) SKM_ShadeDynamicLighting( i.worldPos, normal, _LightDirectionality)
	#endif

	#define SKM_GET_FRAGMENT_LIGHTING_NORMAL SKM_GET_FRAGMENT_LIGHTING(SKN_PARTICLE_NORMAL)

#else
	#ifdef SKM_REQUIRE_NORMAL
		#define SKM_GET_FRAGMENT_LIGHTING(normal) 1
	#endif
	#define SKM_GET_FRAGMENT_LIGHTING_NORMAL 1	
#endif

/////////////////////////////////////////////////////////////////////////////////
// DITHERING
/////////////////////////////////////////////////////////////////////////////////

#ifdef _ALPHATEST_DITHERED
	#define SKM_REQUIRE_BAYER
	#define SKM_CULL_DITHERED(alpha) SKM_Bayer_Clip(alpha, i.vertex.xy)
#else
	#define SKM_CULL_DITHERED(alpha)
#endif

#ifdef SKM_REQUIRE_BAYER

	static const half kernel[16] = {1,9,3,11,13,5,15,7,4,12,2,10,16,8,14,6};

	half SKM_Bayer_Clip(half a, float2 pos)
	{
		int kernelIndex = (((int)pos.y & 3) << 2) + ((int)pos.x & 3);
		clip(pow(a,0.454545)  - kernel[kernelIndex] / 17.0f);
		return kernel[kernelIndex] / 17.0f;
	}

	half SKM_Bayer(float2 pos)
	{
		int kernelIndex = (((int)pos.y & 3) << 2) + ((int)pos.x & 3);
		return kernel[kernelIndex] / 17.0f;
	}
#endif


/////////////////////////////////////////////////////////////////////////////////
// REFLECTION
/////////////////////////////////////////////////////////////////////////////////

#ifdef SKM_REQUIRE_SPECCUBE

half3 SKM_FastEnvironmentReflection(float3 worldPos, half3 normal)
{
	half Smoothness = 0.90f;
	float3 view = normalize(worldPos - _WorldSpaceCameraPos);
	float3 r = reflect(view, normal);

	// Indirect
	UnityGIInput d;
	d.worldPos = worldPos;
	d.worldViewDir = view;
	d.probeHDR[0] = unity_SpecCube0_HDR;
	float blendDistance = unity_SpecCube1_ProbePosition.w; // will be set to blend distance for this probe

	#if UNITY_SPECCUBE_BOX_PROJECTION
	d.probePosition[0]	= unity_SpecCube0_ProbePosition;
	d.boxMin[0].xyz		= unity_SpecCube0_BoxMin - float4(blendDistance,blendDistance,blendDistance,0);
	d.boxMin[0].w		= 1;  // 1 in .w allow to disable blending in UnityGI_IndirectSpecular call
	d.boxMax[0].xyz		= unity_SpecCube0_BoxMax + float4(blendDistance,blendDistance,blendDistance,0);
	#endif

	Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(Smoothness, normalize(_WorldSpaceCameraPos-worldPos), normal, 0);
	half3 env0 = UnityGI_IndirectSpecular(d, 1, g);

	#ifdef VFX_LIGHTING // Infamous 4-PointLight Specular Reflection, hopefully you will figure out something someday, son.

	float4 lightAttenSq = unity_4LightAtten0;

	float4 lightPosX = unity_4LightPosX0;
	float4 lightPosY = unity_4LightPosY0;
	float4 lightPosZ = unity_4LightPosZ0;

	// to light vectors
	float4 toLightX = lightPosX - worldPos.x;
	float4 toLightY = lightPosY - worldPos.y;
	float4 toLightZ = lightPosZ - worldPos.z;

	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;

	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001);

	// NdotL
	half4 ndotl = 0;
	ndotl += toLightX * normal.x;
	ndotl += toLightY * normal.y;
	ndotl += toLightZ * normal.z;

	// attenuation
	half4 atten = pow(1 - saturate(lightAttenSq*lengthSq*0.03), 2);

	// Direct
	float3 lightPos0 = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x); 
	float3 lightPos1 = float3(unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y); 
	float3 lightPos2 = float3(unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z); 
	float3 lightPos3 = float3(unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w); 
	
	float3 lightColor0 = unity_LightColor[0].rgb; 
	float3 lightColor1 = unity_LightColor[1].rgb; 
	float3 lightColor2 = unity_LightColor[2].rgb; 
	float3 lightColor3 = unity_LightColor[3].rgb;

	half3 lightDir0 = normalize(worldPos-lightPos0);
	half3 lightDir1 = normalize(worldPos-lightPos1);
	half3 lightDir2 = normalize(worldPos-lightPos2);
	half3 lightDir3 = normalize(worldPos-lightPos3);

	half3 halfDir0 = Unity_SafeNormalize (view + lightDir0);
	half3 halfDir1 = Unity_SafeNormalize (view + lightDir1);
	half3 halfDir2 = Unity_SafeNormalize (view + lightDir2);
	half3 halfDir3 = Unity_SafeNormalize (view + lightDir3);

	float Gloss = 16.0f;
	env0 += (pow(abs(dot(r, -lightDir0)), Gloss)) * lightColor0 * atten.x;
	env0 += (pow(abs(dot(r, -lightDir1)), Gloss)) * lightColor1 * atten.y;
	env0 += (pow(abs(dot(r, -lightDir2)), Gloss)) * lightColor2 * atten.z;
	env0 += (pow(abs(dot(r, -lightDir3)), Gloss)) * lightColor3 * atten.w;
	#endif

	return env0 * saturate(1 - dot(-view, normal));
}

#endif

/////////////////////////////////////////////////////////////////////////////////
// REFRACTION
/////////////////////////////////////////////////////////////////////////////////

#ifdef SKM_REFRACTION

sampler2D _SceneColor;
float _Refraction;

#ifdef VFX_USENORMALMAP
	#define SKN_REFRACT_SCENECOLOR GetRefractedSceneColor(i.grabPos,  UnpackNormal(SKM_SAMPLE_FLIPBOOK(_NormalMap, i.texcoord)))
#else
	#define SKN_REFRACT_SCENECOLOR GetRefractedSceneColor(i.grabPos, i.grabPos.xyz * 2 - 1);
#endif

half3 GetRefractedSceneColor(half4 grabPos, half3 ScreenSpaceNormal)
{
	return tex2Dproj(_SceneColor, grabPos + (half4(ScreenSpaceNormal,0) *_Refraction)).xyz;
}

#endif
