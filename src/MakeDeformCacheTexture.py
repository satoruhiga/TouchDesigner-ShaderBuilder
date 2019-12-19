class Node:
	def __init__(self):
		self.name = ''
		self.parent = None
		self.t = [0, 0, 0]
		self.r = [0, 0, 0]
		self.s = [1, 1, 1]
		self.local_transform = tdu.Matrix()
		self.world_transform = tdu.Matrix()
		self.offset_matrix = tdu.Matrix()

class MakeDeformCacheTexture:
	def __init__(self, ownerComp):
		self.ownerComp = ownerComp
		self.COMP = None
		self.BONES_MAT = None
		self.CAPT_PATH = None
		self.CAPT_DATA = None

		self.nodes = []
		self.nodes_dict = {}
		self.ROOT_NODE = None

	def updateNodeList(self, root):
		nodes = []
		nodes_dict = {}

		def walk_nodes(node, parent):
			n = Node()
			n.parent = parent
			n.name = self.COMP.relativePath(node).strip('./')
			n.local_transform = node.localTransform.copy()
			n.s, n.r, n.t = [list(x) for x in n.local_transform.decompose()]
			n.world_transform = node.worldTransform.copy()

			nodes.append(n)
			nodes_dict[n.name] = n
			
			for x in node.outputCOMPs:
				walk_nodes(x, n)

		walk_nodes(root, None)

		return nodes, nodes_dict

	def initBonesMatChannels(self):
		self.BONES_MAT = op('BONES_MAT')
		self.CAPT_PATH = op('CAPT_PATH')
		self.CAPT_DATA = op('CAPT_DATA')

		self.BONES_MAT.clear()

		for i in range(1, self.CAPT_PATH.numRows):
			name = self.CAPT_PATH[i, 0].val

			for k in range(16):
				self.BONES_MAT.appendChan('%s:m%i%i' % (name, k / 4, k % 4))

			arr = []
			for k in range(16):
				arr.append(float(self.CAPT_DATA[(i - 1) * 20 + k + 1, 0].val))

			self.nodes_dict[name].offset_matrix = tdu.Matrix(arr)

	def updateWorldTransform(self):
		for n in self.nodes:
			m = tdu.Matrix()
			m.scale(n.s[0], n.s[1], n.s[2])
			m.rotate(n.r[0], n.r[1], n.r[2])
			m.translate(n.t[0], n.t[1], n.t[2])
			n.local_transform = m

			if n.parent:
				n.world_transform = n.parent.world_transform * n.local_transform
			else:
				n.world_transform = n.local_transform.copy()

	def updateBonesMat(self, sidx):
		idx = 0

		for i in range(1, self.CAPT_PATH.numRows):
			name = self.CAPT_PATH[i, 0].val
			node = self.nodes_dict[name]

			if not node:
				raise
			
			m = node.world_transform * node.offset_matrix
			m = m.vals
			for x in range(16):
				self.BONES_MAT[idx][sidx] = m[x]
				idx += 1

	def Update(self):
		self.ROOT_NODE = me.parent().par.Rootnode.eval()
		self.COMP = me.parent().par.Comp.eval()
		self.nodes, self.nodes_dict = self.updateNodeList(self.ROOT_NODE)

		self.initBonesMatChannels()

		ANIMATION = op('ANIMATION')

		self.BONES_MAT.numSamples = ANIMATION.numSamples

		def set_par(dim, o, ch, sidx):
			if dim == 'x':
				o[0] = ch[sidx]
			elif dim == 'y':
				o[1] = ch[sidx]
			if dim == 'z':
				o[2] = ch[sidx]

		for sidx in range(ANIMATION.numSamples):

			for cidx in range(ANIMATION.numChans):
				ch = ANIMATION[cidx]

				ns = ch.name.split(':')
				name = ns[0]
				parname = ns[1]

				node = self.nodes_dict[name]

				par = parname[0]
				dim = parname[1]

				if par == 't':
					set_par(dim, node.t, ch, sidx)
				elif par == 'r':
					set_par(dim, node.r, ch, sidx)
				elif par == 's':
					set_par(dim, node.s, ch, sidx)

			self.updateWorldTransform()
			self.updateBonesMat(sidx)

