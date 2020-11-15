import platform

class MATGenerator:
	def __init__(self, ownerComp):
		self.ownerComp = ownerComp
		self.OUT_glsl_struct = ''
		self.OUT_pixel = ''
		self.OUT_vertex = ''
		self.use_alpha_hashed = False

		self.Update(self.ownerComp.op('in1'))

	def eval_template(self, tmpl_dat_name, ctx):
		t = op.ShaderBuilder.Template(self.ownerComp.op(tmpl_dat_name).text)
		return t(ctx)

	def Update(self, dat):
		c = op.ShaderBuilder.Context.fromJson(dat.text)

		self.updateParameters(c)

		ctx = c.__dict__.copy()
		ctx['shader_builder_path'] = op.ShaderBuilder.path
		ctx['alpha_hashed'] = self.use_alpha_hashed

		ctx['camera_index_type'] = 'int'
		ctx['geom_def'] = self.eval_template('tmpl_geom_def', ctx)
		self.OUT_glsl_struct = self.eval_template('tmpl_glsl_struct', ctx)

		ctx['camera_index_type'] = 'flat int'
		ctx['geom_def'] = self.eval_template('tmpl_geom_def', ctx)
		self.OUT_vertex = self.eval_template('tmpl_vertex', ctx)
		self.OUT_pixel = self.eval_template('tmpl_pixel', ctx)

		return 'ok'

	def updateParameters(self, ctx):
		o = op('glsl')

		# reset all params
		for x in o.pars('uniname*'):
			x.val = x.default

		for x in o.pars('value*'):
			x.val = x.default

		for x in o.pars('sampler*'):
			x.val = x.default

		for x in o.pars('top*'):
			x.val = x.default

		dim = 'xyzw'

		for i, k in enumerate(ctx.vector_uniforms):
			u = ctx.vector_uniforms[k]

			p = o.pars('uniname%i' % i)[0]
			p.val = u['name']
			
			for k, x in enumerate(u['pars']):
				p = o.pars('value%i%s' % (i, dim[k]))[0]
				p.expr = x
				
		for i, k in enumerate(ctx.sampler_uniforms):
			u = ctx.sampler_uniforms[k]

			p = o.pars('sampler%i' % i)[0]
			p.val = u['name']

			p = o.pars('top%i' % i)[0]
			p.expr = u['top']

		### blendmode etc

		if ctx.blending:
			blendmode = ctx.blending['blendmode']
			self.use_alpha_hashed = False

			m = blendmode['mode']
			if m == 'Disable':
				o.par.alphatest = 0
				o.par.blending = 0
			elif m == 'Alphablend':
				o.par.alphatest = 0
				o.par.blending = 1
				o.par.srcblend = 'sa'
				o.par.destblend = 'omsa'
			elif m == 'Add':
				o.par.alphatest = 0
				o.par.blending = 1
				o.par.srcblend = 'sa'
				o.par.destblend = 'one'
			elif m == 'Multiply':
				o.par.alphatest = 0
				o.par.blending = 1
				o.par.srcblend = 'zero'
				o.par.destblend = 'scol'
			elif m == 'Alphaclip':
				o.par.alphatest = 1
				o.par.blending = 0
				o.par.alphathreshold = blendmode['threshold']
			elif m == 'Alphahashed':
				o.par.alphatest = 0
				o.par.blending = 0
				self.use_alpha_hashed = True

			o.par.depthtest = ctx.blending['depthtest']
			o.par.depthwriting = ctx.blending['depthwriting']

		else:
			names = ["alphatest", "blending", "srcblend", "destblend", "alphathreshold", "depthtest", "depthwriting"]

			for x in names:
				p = o.pars(x)[0]
				p.val = p.default

		if ctx.settings:
			o.par.cullface = ctx.settings['cullface']
			o.par.polygonoffset = ctx.settings['polygonoffset']
			o.par.polygonoffsetfactor = ctx.settings['polygonoffsetfactor']
			o.par.polygonoffsetunits = ctx.settings['polygonoffsetunits']

			o.par.wireframe = ctx.settings['wireframe']
			o.par.wirewidth = ctx.settings['wirewidth']

		else:
			names = ["cullface", "polygonoffset", "polygonoffsetfactor", "polygonoffsetunits", "wireframe", "wirewidth"]

			for x in names:
				p = o.pars(x)[0]
				p.val = p.default
				
		### deform

		names = ['dodeform', 'deformdata', 'targetsop', 'pcaptpath', 'pcaptdata', 'skelrootpath', 'mat']
		for x in names:
			p = o.pars(x)[0]
			p.val = p.default
			
		if ctx.deform:
			o.par.dodeform = True
			for k in ctx.deform:
				p = o.pars(k)[0]
				p.val = ctx.deform[k]
