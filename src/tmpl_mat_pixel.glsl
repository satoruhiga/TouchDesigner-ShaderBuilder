{%
import textwrap
def indent(text, amount, ch='\t'):
	return textwrap.indent(text, amount * ch)
%}

#define PIXEL_SHADER

#include <glsl_struct>
#include <{% emit(shader_builder_path) %}/glsl_common>
#include <{% emit(shader_builder_path) %}/glsl_PBR>

{%
if alpha_hashed:
	emit('#define ALPHA_HASHED')
%}

in _Geometry {% emit(geom_def) %} iGeom;

out vec4 fragColor;

// global uniforms
{%
if 'global_uniforms' in codeblock:
	c = codeblock['global_uniforms']
	for x in sorted(c.keys()): emit(c[x] + '\n')
%}

// global define
{%
if 'global_define' in codeblock:
	c = codeblock['global_define']
	for x in sorted(c.keys()): emit(c[x])
%}

// pixel derine
{%
if 'pixel_define' in codeblock:
	c = codeblock['pixel_define']
	for x in sorted(c.keys()): emit(c[x])
%}

void main()
{
	Geometry geom;
	geom.P = iGeom.P;
	geom.localP = iGeom.localP;
	geom.N = iGeom.N;
	geom.localN = iGeom.localN;
	geom.uv = iGeom.uv;
	geom.Cd = iGeom.Cd;
	geom.cameraIndex = iGeom.cameraIndex;

	// custon attributes
	{%
	for x in custom_attributes:
		emit('geom.{name} = iGeom.{name};'.format(**custom_attributes[x]))
	%}

	TDCheckDiscard();

	// update normals
	{
{%
if 'pixel_update_normal' in codeblock:
	emit(indent('vec3 uvw = vec3(0.0, 0.0, 1);\nvec3 out_uvw = vec3(0.0, 0.0, 1);\n\n', 2));
	c = codeblock['pixel_update_normal']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}' % indent(c[x].strip(), 1), 2))
		emit(indent('\nout_uvw = blend_normal(out_uvw, uvw);\n\n', 2))

	emit(indent('// apply tangent rotation\nout_uvw = vTM * out_uvw;\ngeom.N = normalize(out_uvw);', 2))
%}
	}

	PBRMaterial mat;
	
	// initialize material parameters
	{
		mat.baseColor = geom.Cd.rgb;
		mat.metallic = 0;
		mat.roughness = 0.5;
		mat.reflectance = 0.5;
		mat.ao = 1;
		mat.emission = vec3(0);
	}

	// update PBR material parameters
	{
{%
if 'pixel_update_material' in codeblock:
	c = codeblock['pixel_update_material']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}' % indent(c[x].strip(), 1), 2))
%}
	}

{%
if 'pixel_update_alpha' in codeblock:
	c = codeblock['pixel_update_alpha']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}' % indent(c[x].strip(), 1), 2))
%}

#if defined(ALPHA_HASHED)
	if (rand(gl_FragCoord.xy + vec2(uTime.x, 0)) >= geom.Cd.a)
		discard;
	geom.Cd.a = 1;
#endif

	// calclate some parameters
	{
		mat.perceptualRoughness = mat.roughness;
		mat.roughness = mat.perceptualRoughness * mat.perceptualRoughness;
		mat.roughness = clamp(mat.roughness, MIN_ROUGHNESS, 1.0);
		mat.diffuseColor = mat.baseColor.rgb * (1 - mat.metallic);

		float reflectance = clamp(mat.reflectance, 0, 2);
		reflectance = 0.16 * reflectance * reflectance;
		mat.f0 = mat.baseColor.rgb * mat.metallic + (reflectance * (1.0 - mat.metallic));
	}

	if (!TDFrontFacing(geom.P, iGeom.N))
		geom.N = -geom.N;

	TDMatrix M = uTDMats[iGeom.cameraIndex];
	vec3 V = normalize(M.camInverse[3].xyz - geom.P);

	vec4 color = vec4(0, 0, 0, 1);
	color.rgb += evaluatePBR(geom.P, V, geom.N, mat);
	color.rgb += mat.emission;
	color.a = geom.Cd.a;

{%
if 'pixel_update_final' in codeblock:
	c = codeblock['pixel_update_final']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}' % indent(c[x].strip(), 1), 2))
%}

	TDAlphaTest(color.a);

	color.rgb = pow(color.rgb, vec3(1/2.2));
	fragColor = TDOutputSwizzle(color);
}
