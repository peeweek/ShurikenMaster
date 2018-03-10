UNITY_DECLARE_TEX2D(_CloudAttenuationRamp);

/////////////////////////////////////////////////////////////////////////////////
// CLOUD LIGHTING
/////////////////////////////////////////////////////////////////////////////////

float _CloudBackScattering;

half3 SKM_ShadeCloudDirectional(float3 worldPos, half3 normal, half3 lightDirection, half3 lightColor, float thickness)
{
	// Directional
	half diffDirectional = (dot(normal.xyz, lightDirection))*0.5f + 0.5f;
	half3 color = lightColor * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(diffDirectional, 0.0));

	// BackScattering
	if (_CloudBackScattering > 0.0f)
	{
		half3 view = normalize(worldPos - _WorldSpaceCameraPos);
		thickness = pow(thickness, 0.45454f);
		color += _CloudBackScattering * lightColor * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(pow(saturate(dot(view, lightDirection)), lerp(2, 8, thickness)) * 1 - thickness, 0));
	}

	// Ambient term
	color += ShadeSH9(half4(lerp(half3(0, 1, 0), normal, 0.5), 1));
	return color;
}


#if defined(VFX_LIGHTING)

half3 SKM_Cloud_ShadeDynamicLighting (float3 pos, half3 normal, float thickness)
{
	LightingInfo info = GetLightingInfo(pos);

	// 4 Pointlights (Cloud Atenuation only, no backscattering)
	half3 col = 0;
	col += info.pointLight1.color * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(LambertNdotL(normal, info.pointLight1.direction),0.0)) * info.pointLight1.attenuation;
	col += info.pointLight2.color * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(LambertNdotL(normal, info.pointLight2.direction),0.0)) * info.pointLight2.attenuation;
	col += info.pointLight3.color * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(LambertNdotL(normal, info.pointLight3.direction),0.0)) * info.pointLight3.attenuation;
	col += info.pointLight4.color * UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, float2(LambertNdotL(normal, info.pointLight4.direction),0.0)) * info.pointLight4.attenuation;

	if(info.directional.direction.x + info.directional.direction.y + info.directional.direction.z != 0)
	{	
		// Additional Directional light
		col += SKM_ShadeCloudDirectional(pos, normal, info.directional.direction, info.directional.color, thickness);
	}
	return col;
}
#endif

#if defined(VFX_LIGHTING_FAKEDIRECTIONAL)

float3 _FakeLightDirection;
float3 _FakeLightColor;
float _FakeLightIntensity;

half3 SKM_Cloud_ShadeFakeLighting(float3 worldPos, half3 normal, float thickness)
{
	return SKM_ShadeCloudDirectional(worldPos, normal, normalize(-_FakeLightDirection), _FakeLightColor * _FakeLightIntensity, thickness);
}
#endif

#if defined(VFX_LIGHTING_RAYMARCH2D)

#define SKM_REQUIRE_BAYER
#define NUM_STEPS 8

half3 shadeLightRM(float3 worldPos, float2 uv, float3 lightDir, float3 normal, float3 tangent, float3 binormal, float2 screenPos)
{
	float3 marchStep = 0.6f * float3(dot(tangent, lightDir), dot(binormal, lightDir), dot(-normal, -lightDir)) / (float)NUM_STEPS;
	float3 pos = float3(uv, UNITY_SAMPLE_TEX2D(_MainTex, uv).a/2);

	half contrib = 1.0f;

	for(uint i = NUM_STEPS; i > 0; i--)
	{
		float3 readPos = pos + marchStep * ((float)i + SKM_Bayer(screenPos)-0.5f);
		readPos.xy = saturate(readPos.xy);

		float s = UNITY_SAMPLE_TEX2D(_MainTex, readPos).a;
		
		float v = saturate((abs(readPos.z)-(s*0.5))*-5.0);


		contrib *= 1.0 - (v*(12*_CloudBackScattering / NUM_STEPS));
	}
	
	return UNITY_SAMPLE_TEX2D(_CloudAttenuationRamp, contrib);
}

half3 SKM_Cloud_ShadeRaymarch2D(float3 worldPos, half2 uv, half3 worldNormal, half3 worldTangent, float2 screenPos)
{
	LightingInfo info = GetLightingInfo(worldPos);
	half3 worldBinormal = cross(worldTangent,worldNormal);
	half3 color = half3(0, 0, 0);
	color += shadeLightRM(worldPos, uv, info.directional.direction, worldNormal, worldTangent, worldBinormal, screenPos);
	return color * info.directional.color + ShadeSH9(half4(lerp(half3(0, 1, 0), worldNormal, 0.5), 1));;
}
#endif


////////////////////////////////////
// Redefine lighting

// Per pixel
#if defined(VFX_LIGHTING) || defined(VFX_LIGHTING_FAKEDIRECTIONAL) || defined(VFX_LIGHTING_RAYMARCH2D)

	#ifdef VFX_LIGHTING
		#define SKM_GET_FRAGMENT_THICK_LIGHTING(normal, thickness) SKM_Cloud_ShadeDynamicLighting (i.worldPos, normal, thickness)
	#endif

	#ifdef VFX_LIGHTING_FAKEDIRECTIONAL
		#define SKM_GET_FRAGMENT_THICK_LIGHTING(normal, thickness) SKM_Cloud_ShadeFakeLighting(i.worldPos, normal, thickness)
	#endif

	#ifdef VFX_LIGHTING_RAYMARCH2D
		#define SKM_GET_FRAGMENT_THICK_LIGHTING(normal, thickness) SKM_Cloud_ShadeRaymarch2D(i.worldPos, i.texcoord, normal, SKN_PARTICLE_TANGENT, i.vertex.xy)
	#endif

	#define SKM_GET_CLOUD_LIGHTING(thickness) SKM_GET_FRAGMENT_THICK_LIGHTING(SKN_PARTICLE_NORMAL, thickness)
#else
	#define SKM_GET_CLOUD_LIGHTING(thickness) 1
#endif



