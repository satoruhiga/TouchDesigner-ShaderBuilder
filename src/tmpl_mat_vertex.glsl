{%
import textwrap
def indent(text, amount, ch='\t'):
	return textwrap.indent(text, amount * ch)
%}

#define VERTEX_SHADER

#include <glsl_struct>
#include <{% emit(shader_builder_path) %}/glsl_common>

out _Geometry {% emit(geom_def) %} oGeom;

{%
for x in custom_attributes:
	emit('in {type} {name};'.format(**custom_attributes[x]))
%}

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

// vertex derine
{%
if 'vertex_define' in codeblock:
	c = codeblock['vertex_define']
	for x in sorted(c.keys()): emit(c[x])
%}

void main() 
{
	Geometry geom;
	geom.P = P;
	geom.localP = P;
	geom.N = N;
	geom.localN = N;
	geom.uv = uv[0].xy;
	geom.Cd = TDInstanceColor(Cd);
	geom.cameraIndex = TDCameraIndex();

	// custon attributes
	{%
	for x in custom_attributes:
		emit('geom.{name} = {name};'.format(**custom_attributes[x]))
	%}

	// vertex update local space
	{
{%
if 'vertex_update_local' in codeblock:
	c = codeblock['vertex_update_local']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}\n' % indent(c[x].strip(), 1), 2))
%}
	}

	// local to world vertex update
	{
		geom.P = TDDeform(geom.P).xyz;
		geom.N = normalize(TDDeformNorm(geom.N));
	}
	
	// vertex update world space
	{
{%
if 'vertex_update_world' in codeblock:
	c = codeblock['vertex_update_world']
	for x in sorted(c.keys()):
		emit(indent('{\n%s\n}\n' % indent(c[x].strip(), 1), 2))
%}
	}

	gl_Position = TDWorldToProj(geom.P.xyz);

	oGeom.cameraIndex = geom.cameraIndex;
	oGeom.P = geom.P;
	oGeom.localP = geom.localP;
	oGeom.N = geom.N;
	oGeom.localN = geom.localN;
	oGeom.uv = geom.uv;
	oGeom.Cd = geom.Cd;

	{%
	for x in custom_attributes:
		emit('oGeom.{name} = geom.{name};'.format(**custom_attributes[x]))
	%}
}


