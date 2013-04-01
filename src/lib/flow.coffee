# Import
typeChecker = require('typechecker')
TaskGroup = require('taskgroup')
getsetdeep = require('getsetdeep')
extendr = require('extendr')
ambi = require('ambi')
eachr = require('eachr')
safeCallback = require('safecallback')


# =====================================
# Flow

balUtilFlow = extendr.extend {}, extendr, getsetdeep, {

	# Each
	each: eachr

	# Ambi
	fireWithOptionalCallback: ambi

	# Safe Callback
	safeCallback: safeCallback

	# Wait a certain amount of milliseconds before firing the function
	wait: (delay,fn) ->
		setTimeout(fn,delay)

	# Extract the correct options and completion callback from the passed arguments
	extractOptsAndCallback: (opts,next) ->
		if typeChecker.isFunction(opts) and next? is false
			next = opts
			opts = {}
		else
			opts or= {}
		next or= opts.next or null
		return [opts,next]

	# Flow through a series of actions on an object
	# next(err)
	flow: (args...) ->
		# Extract
		if args.length is 1
			{object,actions,action,args,tasks,next} = args[0]
		else if args.length is 4
			[object,action,args,next] = args
		else if args.length is 3
			[actions,args,next] = args

		# Check
		if action? is false and actions? is false
			throw new Error('balUtilFlow.flow called without any action')

		# Create tasks group and cycle through it
		actions ?= action.split(/[,\s]+/g)
		object ?= global
		tasks or= new balUtilFlow.Group(next)
		balUtilFlow.each actions, (action) -> tasks.push (complete) ->
			# Prepare callback
			argsClone = (args or []).slice()
			argsClone.push(complete)

			# Fire the action with the next helper
			fn = if typeChecker.isFunction(action) then action else object[action]
			fn.apply(object,argsClone)

		# Fire the tasks synchronously
		tasks.sync()

		# Chain
		@

	# Create snore
	createSnore: (message,opts) ->
		# Prepare
		opts or= {}
		opts.delay ?= 5000

		# Create snore object
		snore =
			snoring: false
			timer: setTimeout(
				->
					snore.clear()
					snore.snoring = true
					message?()
				opts.delay
			)
			clear: ->
				if snore.timer
					clearTimeout(snore.timer)
					snore.timer = false

		# Return
		return snore

	# Suffix an array
	suffixArray: (suffix, args...) ->
		result = []
		for arg in args
			arg = [arg]  unless typeChecker.isArray(arg)
			for item in arg
				result.push(item+suffix)
		return result

}



# =====================================
# Group
# Easily group together asynchronmous functions and run them synchronously or asynchronously

balUtilFlow.Group = TaskGroup


# =====================================
# Block
# Block together a series of tasks

# Block
balUtilFlow.Block = class extends balUtilFlow.Group

	# Events
	blockBefore: (block) ->
	blockAfter: (block,err) ->
	blockTaskBefore: (block,task,err) ->
	blockTaskAfter: (block,task,err) ->

	# Create a new block and run it
	# fn(block.block, block.task, block.exit)
	# complete(err)
	constructor: (opts) ->
		# Prepare
		block = @
		{name, fn, parentBlock, complete} = opts

		# Apply options
		block.blockName = name
		block.parentBlock = parentBlock  if parentBlock?
		block.mode = 'sync'
		block.fn = fn

		# Create group
		super (err) ->
			block.blockAfter(block,err)
			complete?(err)

		# Event
		block.blockBefore(block)

		# If we have an fn
		if block.fn?
			# If our fn has a completion callback
			# then set the total tasks to infinity
			# so we wait for the competion callback instead of completeling automatically
			if block.fn.length is 3
				block.total = Infinity

			# Fire the init function
			try
				block.fn(
					# Create sub block
					(name,fn) -> block.block(name,fn)
					# Create sub task
					(name,fn) -> block.task(name,fn)
					# Complete
					(err) -> block.exit(err)
				)

				# If our fn completion callback is synchronous
				# then fire our tasks right away
				if block.fn.length isnt 3
					block.run()
			catch err
				block.exit(err)
		else
			# We don't have an fn
			# So lets set our total tasks to infinity
			block.total = Infinity

		# Chain
		@

	# Create a sub block
	# fn(subBlock, subBlock.task, subBlock.exit)
	block: (name,fn) ->
		# Push the creation of our subBlock to our block's queue
		block = @
		pushBlock = (fn) ->
			if block.total is Infinity
				block.pushAndRun(fn)
			else
				block.push(fn)
		pushBlock (complete) ->
			subBlock = block.createSubBlock({name,fn,complete})
		@

	# Create a sub block
	createSubBlock: (opts) ->
		opts.parentBlock = @
		new balUtilFlow.Block(opts)

	# Create a task for our current block
	# fn(complete)
	task: (name,fn) ->
		# Prepare
		block = @
		pushTask = (fn) ->
			if block.total is Infinity
				block.pushAndRun(fn)
			else
				block.push(fn)

		# Push the task to the correct place
		pushTask (complete) ->
			# Prepare
			preComplete = (err) ->
				block.blockTaskAfter(block,name,err)
				complete(err)

			# Event
			block.blockTaskBefore(block,name)

			# Fire the task, treating the callback as optional
			balUtilFlow.fireWithOptionalCallback(fn,[preComplete])

		# Chain
		@

# =====================================
# Runner
# Run a series of tasks as a block

balUtilFlow.Runner = class
	runnerBlock: null
	constructor: ->
		@runnerBlock ?= new balUtilFlow.Block()
	getRunnerBlock: ->
		@runnerBlock
	block: (args...) ->
		@getRunnerBlock().block(args...)
	task: (args...) ->
		@getRunnerBlock().task(args...)


# =====================================
# Export

module.exports = balUtilFlow