def onCook(scriptOp):
	scriptOp.copy(scriptOp.inputs[0])

	args = {}
	co = op.ShaderBuilder.Context()

	for i in range(1, len(scriptOp.inputs)):
		s = scriptOp.inputs[i].text
		k = 'in%i' % i

		if not s:
			args[k] = ''
			continue

		c = op.ShaderBuilder.Context.fromJson(s)
		args[k] = c.expression
		co.update(c)

	exp = scriptOp.inputs[0].text
	co.expression = exp.format(**args)

	scriptOp.text = co.toJson()
	scriptOp.store('output', co.expression)
