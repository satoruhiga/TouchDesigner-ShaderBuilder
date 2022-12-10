#define DEG_TO_RAD 0.0174533

float saturate(in float value) {
	return clamp(value, 0.0, 1.0);
}

float rand(vec2 p){
	p  = fract( p*0.3183099+.1 );
	p *= 17.0;
	return fract( p.x*p.y*(p.x+p.y) );
}

float map(float value, float inMin, float inMax, float outMin, float outMax) {
	return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

vec2 map(vec2 value, vec2 inMin, vec2 inMax, vec2 outMin, vec2 outMax) {
	return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

vec3 map(vec3 value, vec3 inMin, vec3 inMax, vec3 outMin, vec3 outMax) {
	return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

vec4 map(vec4 value, vec4 inMin, vec4 inMax, vec4 outMin, vec4 outMax) {
	return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

///////////////////////////////////////////////////////////////////////////////

mat4 make_scale(vec3 S)
{
	mat4 m = mat4(1);
	m[0][0] = S.x;
	m[1][1] = S.y;
	m[2][2] = S.z;
	return m;
}

mat4 make_rotationXYZ(vec3 Rxyz)
{
	mat4 m = mat4(1);
	vec3 r = Rxyz * -vec3(DEG_TO_RAD);

	float cx = cos(r.x);
	float cy = cos(r.y);
	float cz = cos(r.z);
	
	float sx = sin(r.x);
	float sy = sin(r.y);
	float sz = sin(r.z);

	m[0] = vec4(cy * cz, 
		-cy * sz, 
		sy, 0);
	m[1] = vec4(cz * sx * sy + cx * sz, 
		cx * cz - sx * sy * sz, 
		-cy * sx, 0);
	m[2] = vec4(-cx * cz * sy + sx * sz,
		cz * sx + cx * sy * sz, 
		cx * cy, 0);
	m[3] = vec4(0, 0, 0, 1);

	return m;
}

mat4 make_translate(vec3 T)
{
	mat4 m = mat4(1);
	m[3] = vec4(T, 1);
	return m;
}

mat4 make_transformSRT(vec3 T, vec3 Rxyz, vec3 S)
{
	return make_translate(T) * make_rotationXYZ(Rxyz) * make_scale(S);
}

///////////////////////////////////////////////////////////////////////////////

float sRGB_to_linear(float v) {
	return pow(v, 2.2);
}

vec3 sRGB_to_linear(vec3 v) {
	return pow(v, vec3(2.2));
}

vec4 sRGB_to_linear(vec4 v) {
	return pow(v, vec4(2.2));
}

///////////////////////////////////////////////////////////////////////////////

vec3 blend_normal(vec3 n1, vec3 n2, float mix) {
	float m = (mix - 0.5) * 2;
	return normalize(
		vec3(n1.xy * clamp(1 - m, 0, 1)
			+ n2.xy * clamp(1 + m, 0, 1),
			 n1.z * n2.z)
	);
}

vec3 blend_normal(vec3 n1, vec3 n2) {
	return blend_normal(n1, n2, 0.5);
}

///////////////////////////////////////////////////////////////////////////////

vec4 sampler_projection_uv(sampler2D tex, vec2 uv) {
	return texture(tex, uv);
}

vec4 sampler_projection_box(sampler2D tex, vec3 P, vec3 N, float blend_feather, float box_scale) {
	vec3 blend = vec3(0);
	blend.x = abs(dot(vec3(1, 0, 0), N));
	blend.y = abs(dot(vec3(0, 1, 0), N));
	blend.z = abs(dot(vec3(0, 0, 1), N));

	float a = blend_feather;
	float eps = 1e-6;

	float m = max(max(blend.x, blend.y), blend.z);
	blend.x = smoothstep(a + eps, 0, (m - blend.x));
	blend.y = smoothstep(a + eps, 0, (m - blend.y));
	blend.z = smoothstep(a + eps, 0, (m - blend.z));
	// blend = normalize(blend);

	vec4 color = vec4(0, 0, 0, 1);

	P *= box_scale;
	P = P - 0.5;

	color = mix(color, texture(tex, P.yz), blend.x);
	color = mix(color, texture(tex, P.zx), blend.y);
	color = mix(color, texture(tex, P.xy), blend.z);

	return color;
}

vec4 sampler_projection_box_normal(sampler2D tex, vec3 P, vec3 N, float blend_feather, float box_scale) {
	vec3 blend = vec3(0);
	blend.x = abs(dot(vec3(1, 0, 0), N));
	blend.y = abs(dot(vec3(0, 1, 0), N));
	blend.z = abs(dot(vec3(0, 0, 1), N));

	float a = blend_feather;
	float eps = 1e-6;

	float m = max(max(blend.x, blend.y), blend.z);
	blend.x = smoothstep(a + eps, 0, (m - blend.x));
	blend.y = smoothstep(a + eps, 0, (m - blend.y));
	blend.z = smoothstep(a + eps, 0, (m - blend.z));
	// blend = normalize(blend);

	P *= box_scale;
	P = P - 0.5;

	vec3 uvw = vec3(0, 0, 1);

	uvw = blend_normal(uvw, texture(tex, P.yz).xyz - vec3(0.5, 0.5, 0), blend.x);
	uvw = blend_normal(uvw, texture(tex, P.zx).xyz - vec3(0.5, 0.5, 0), blend.y);
	uvw = blend_normal(uvw, texture(tex, P.xy).xyz - vec3(0.5, 0.5, 0), blend.z);
	
	uvw += vec3(0.5, 0.5, 0);
	return vec4(uvw, 1);
}

///////////////////////////////////////////////////////////////////////////////

float fresnel(vec3 N, vec3 V, float strength){
	float border = 1.0 - (abs(dot(-normalize(V), normalize(N))));
	return clamp(border * (1.0 + strength) - strength, 0.0, 1.0);
}

float fresnel(Geometry geom, float strength){
	TDMatrix M = uTDMats[int(geom.cameraIndex)];
	vec3 V = normalize(M.camInverse[3].xyz - geom.P);
	return fresnel(V, geom.N, strength);
}

#ifdef PIXEL_SHADER

vec3 flatNormal(vec3 vPosition){
	vec3 dx = dFdy(vPosition.xyz);    
	vec3 dy = dFdx(vPosition.xyz);
	
	vec3 n = normalize(cross(normalize(dx), normalize(dy)));
	if(gl_FrontFacing == true)
		n = normalize(cross(normalize(dy), normalize(dx)));
		
	return n;
}

#endif
