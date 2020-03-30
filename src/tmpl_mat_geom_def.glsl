{
	vec3 P;
	vec3 localP;
	vec3 N;
	vec3 localN;
	vec2 uv;
	vec4 Cd;
	{% emit(camera_index_type) %} cameraIndex;
	{%
	for x in custom_attributes:
		a = custom_attributes[x]
		if 'flat' in a and bool(a['flat']):
			emit('flat {type} {name};'.format(**a))
		else:
			emit('{type} {name};'.format(**a))
	%}
}