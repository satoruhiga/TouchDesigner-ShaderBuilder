import json
from template import Template

class Context:
	def __init__(self):
		self.vector_uniforms = {}
		self.sampler_uniforms = {}
		self.custom_attributes = {}
		self.expression = ''
		self.codeblock = {}
		self.settings = {}
		self.blending = {}
		self.deform = {}

	@staticmethod
	def fromJson(json_str):
		try:
			o = json.loads(json_str)
			c = Context()
			c.__dict__.update(o)
			return c
		except:
			return None

	def toJson(self):
		return json.dumps(self.__dict__, indent=1)

	def update(self, other):
		self.vector_uniforms.update(other.vector_uniforms)
		self.sampler_uniforms.update(other.sampler_uniforms)
		self.custom_attributes.update(other.custom_attributes)

		# deep update
		for x in other.codeblock:
			if not x in self.codeblock:
				self.codeblock[x] = {}
			self.codeblock[x].update(other.codeblock[x])

		self.settings.update(other.settings)
		self.blending.update(other.blending)
		self.deform.update(other.deform)

class ShaderBuilder:
	def __init__(self, ownerComp):
		self.ownerComp = ownerComp

		self.Template = Template
		self.Context = Context

