////
//// from google filament https://github.com/google/filament/
////

#define PI (3.14159265358979)
#define MIN_ROUGHNESS 0.06

float D_GGX(float roughness, float NoH, const vec3 h) {
    float a = NoH * roughness;
    float k = roughness / ((1.0 - NoH * NoH) + a * a);
    float d = k * k * (1.0 / PI);
    return clamp(d, 0, 65504.0);
}

float V_SmithGGXCorrelated(float roughness, float NoV, float NoL) {
    float a2 = roughness * roughness;
    float lambdaV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float lambdaL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
    float v = 0.5 / (lambdaV + lambdaL);
    return clamp(v, 0, 65504.0);
}

float V_SmithGGXCorrelated_Fast(float roughness, float NoV, float NoL) {
	// Hammon 2017, "PBR Diffuse Lighting for GGX+Smith Microsurfaces"
	float v = 0.5 / mix(2.0 * NoL * NoV, NoL + NoV, roughness);
	return clamp(v, 0, 65504.0);
}

// float pow5(float x) {
//     float x2 = x * x;
//     return x2 * x2 * x;
// }

vec3 F_Schlick(const vec3 f0, float f90, float VoH) {
    // return f0 + (f90 - f0) * pow5(1.0 - VoH);
	return f0 + (f90 - f0) * pow(2.0, (-5.55473 * VoH - 6.98316) * VoH);
}

float F_Schlick(float f0, float f90, float VoH) {
    // return f0 + (f90 - f0) * pow5(1.0 - VoH);
	return f0 + (f90 - f0) * pow(2.0, (-5.55473 * VoH - 6.98316) * VoH);
}

vec3 Irradiance_SphericalHarmonics(const vec3 shCoeffs[9], const vec3 n) {
    return max(
          shCoeffs[0]
        + shCoeffs[1] * (n.y)
        + shCoeffs[2] * (n.z)
        + shCoeffs[3] * (n.x)
        + shCoeffs[4] * (n.y * n.x)
        + shCoeffs[5] * (n.y * n.z)
        + shCoeffs[6] * (3.0 * n.z * n.z - 1.0)
        + shCoeffs[7] * (n.z * n.x)
        + shCoeffs[8] * (n.x * n.x - n.y * n.y)
        , 0.0);
}

////

float distribution(float roughness, float NoH, const vec3 h) {
	return D_GGX(roughness, NoH, h);
}

float visibility(float roughness, float NoV, float NoL) {
	return V_SmithGGXCorrelated_Fast(roughness, NoV, NoL);
}

vec3 fresnel(const vec3 f0, float LoH) {
    float f90 = saturate(dot(f0, vec3(50.0 * 0.33)));
    return F_Schlick(f0, f90, LoH);
}

float diffuse(float roughness, float NoV, float NoL, float LoH) {
	return 1 / PI;
}

vec3 specular(float roughness, vec3 f0, const vec3 h,
		float NoV, float NoL, float NoH, float LoH) {
	float D = distribution(roughness, NoH, h);
	float V = visibility(roughness, NoV, NoL);
	vec3 F = fresnel(f0, LoH);
	return vec3(D * V) * F;
}

vec3 diffuseIrradiance(const vec3 shCoeffs[9], const vec3 n) {
    return Irradiance_SphericalHarmonics(shCoeffs, n);
}

////

struct PBRMaterial {
	vec3 baseColor;
	vec3 diffuseColor;
	float roughness;
	float perceptualRoughness;
	float metallic;
	float reflectance;
	vec3 emission;
	vec3 f0;
	float ao;
};

vec3 evaluateDirectLighting(int index, const vec3 P, const vec3 V, const vec3 N, const PBRMaterial material) {
	TDLight LightParams = uTDLights[index];

	if (length(LightParams.diffuse) < 1e-4)
		return vec3(0);

	vec3 lightColor = LightParams.diffuse;
	float attenuation = 1;
	vec3 lightVector;
	vec3 L;

	if (LightParams.position.xyz == LightParams.direction)
	{
		// distant light

		lightVector = -LightParams.direction.xyz;
		L = normalize(lightVector);
	}
	else
	{
		// point and cone light

		lightVector = LightParams.position.xyz - P;
		L = normalize(lightVector);

		float lightDistance = length(lightVector);

#ifdef TD_PICKING_ACTIVE
		// calc distant falloff
		{
			float lightAtten = lightDistance * LightParams.attenScaleBiasRoll.x;
			lightAtten += LightParams.attenScaleBiasRoll.y;
			lightAtten = clamp(lightAtten, 0.0, 1.0) * 1.57079633;
			lightAtten = sin(lightAtten);
			attenuation *= pow(lightAtten, LightParams.attenScaleBiasRoll.z);
		}
#endif

		// calc cone falloff
		if (LightParams.coneLookupScaleBias.x > 0.0)
		{
			float spotEffect = dot(LightParams.direction, -L);
			spotEffect = (spotEffect * LightParams.coneLookupScaleBias.x) + LightParams.coneLookupScaleBias.y;
			spotEffect = texture(sTDConeLookups[index], spotEffect).r;
			attenuation *= spotEffect;
		}
	}

	attenuation *= (1 - TDShadow(index, P));

	if (abs(attenuation) <= 1e-4)
		return vec3(0);
	
	vec3 H = normalize(L + V);
	float NoV = saturate(dot(N, V));
	float NoL = saturate(dot(N, L));
	float NoH = saturate(dot(N, H));
	float LoH = saturate(dot(L, H));

	vec3 Fd = material.diffuseColor * diffuse(material.roughness, NoV, NoL, LoH);
	vec3 Fr = specular(material.roughness, material.f0, H, NoV, NoL, NoH, LoH);
	vec3 Lo = (Fd + Fr) * lightColor * NoL * attenuation;

	return Lo;
}

vec3 evaluateIBL(int index, const vec3 P, const vec3 V, const vec3 N, const PBRMaterial material)
{
	TDEnvLight LightParams = uTDEnvLights[index];

	if (length(LightParams.color.rgb) < 1e-4)
		return vec3(0);

	float NoV = saturate(dot(N, V));
	vec3 H = normalize(N + V);
	float NoH = saturate(dot(N, H));

	vec3 lightColor = LightParams.color.rgb;
	mat3 envMapRotate = LightParams.rotate;
	vec3 R = (2.0 * dot(N, V) * N) - V;
	R = envMapRotate * R;
	R = normalize(R);
	vec2 mapCoord = TDCubeMapToEquirectangular(R);

	vec2 size = textureSize(sTDEnvLight2DMaps[index], 0);
	float mipCount = 1 + floor(log2(max(size.x, size.y)));
	float mipLevel = saturate(material.perceptualRoughness) * mipCount;
	vec3 prefilteredColor = textureLod(sTDPrefiltEnvLight2DMaps[index], mapCoord, mipLevel).rgb;
	prefilteredColor = sRGB_to_linear(prefilteredColor);

	vec2 dfg = texture(sTDBRDFLookup, vec2(NoV, material.perceptualRoughness)).xy;

	vec3 diffuse = vec3(0);

	// diffuse = diffuseIrradiance(LightParams.shCoeffs, R) / 1.5;

	// TODO: IBL diffuse term should be updated more
	{
		vec3 diffuseContrib = vec3(0);
		const float C1 = 0.429043;
		const float C2 = 0.511664;
		const float C3 = 0.743125;
		const float C4 = 0.886227;
		const float C5 = 0.247708;

		vec3 diffEnvMapCoord = envMapRotate * N;
		diffuseContrib += C1 * (diffEnvMapCoord.x * diffEnvMapCoord.x - diffEnvMapCoord.y * diffEnvMapCoord.y) *  LightParams.shCoeffs[8].rgb;
		diffuseContrib += C3 * diffEnvMapCoord.z * diffEnvMapCoord.z *  LightParams.shCoeffs[6].rgb;
		diffuseContrib += C4 *  LightParams.shCoeffs[0].rgb;
		diffuseContrib -= C5 *  LightParams.shCoeffs[6].rgb;
		diffuseContrib += 2.0 * C1 * (diffEnvMapCoord.x * diffEnvMapCoord.y * LightParams.shCoeffs[4].rgb + diffEnvMapCoord.x * diffEnvMapCoord.z * LightParams.shCoeffs[7].rgb + diffEnvMapCoord.y * diffEnvMapCoord.z * LightParams.shCoeffs[5].rgb);
		diffuseContrib += 2.0 * C2 * (diffEnvMapCoord.x *  LightParams.shCoeffs[3].rgb + diffEnvMapCoord.y *  LightParams.shCoeffs[1].rgb + diffEnvMapCoord.z * LightParams.shCoeffs[2].rgb);

		diffuseContrib /= 1.6;

		diffuse = diffuseContrib;
	}

	vec3 Fd = diffuse * material.diffuseColor * (1 / PI);
	vec3 Fr = (dfg.xxx * material.f0 + dfg.yyy) * prefilteredColor;
	// vec3 Fr = mix(dfg.yyy, dfg.xxx, material.f0) * prefilteredColor;
	// vec3 Fr = mix(dfg.yyy, dfg.xxx, F) * prefilteredColor;
	vec3 Lo = (Fd + Fr) * lightColor;

	return Lo;
}

vec3 evaluatePBR(const vec3 P, const vec3 V, const vec3 N, const PBRMaterial material)
{
	vec3 color = vec3(0);

	// direct lighting
	if (TD_NUM_LIGHTS > 0)
	{
		for (int i = 0; i < TD_NUM_LIGHTS; i++)
		{
			color.rgb += evaluateDirectLighting(i, P, V, N, material) * material.ao;
		}
	}

	// image based lighting
	if (TD_NUM_ENV_LIGHTS > 0)
	{
		for (int i = 0; i < TD_NUM_ENV_LIGHTS; i++)
		{
			color.rgb += evaluateIBL(i, P, V, N, material) * material.ao;
		}
	}

	return color;
}
