import binascii

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

	string_as = str(me.parent().par.Stringas)
	if string_as == 'template':
		tmpl = scriptOp.inputs[0].text
		code = tmpl.format(**args)
	elif string_as == 'raw':
		code = scriptOp.inputs[0].text
	
	section_name = me.parent().par.Section.val
	if not section_name in co.codeblock:
		co.codeblock[section_name] = {}

	code = ('// >>> codeblock: `%s` %s\n\n' % (me.parent().par.Codeblockid.eval(), me.parent().path)) + code
	code += '\n// <<<\n'

	if me.parent().par.Codeblockid:
		co.codeblock[section_name][me.parent().par.Codeblockid.eval()] = code
	else:
		hashkey = '{:x}'.format(binascii.crc32(me.parent().path.encode('utf8')))
		hashname = '%s_%s' % (me.parent().name, hashkey)
		co.codeblock[section_name][hashname] = code

	scriptOp.text = co.toJson()

	scriptOp.store('output', code)
