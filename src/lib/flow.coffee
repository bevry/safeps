# Import
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
eachr = require('eachr')


# =====================================
# Flow

balUtilFlow =

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
		tasks or= new TaskGroup().once('complete',next)
		eachr actions, (action) -> tasks.addTask (complete) ->
			# Prepare callback
			argsClone = (args or []).slice()
			argsClone.push(complete)

			# Fire the action with the next helper
			fn = if typeChecker.isFunction(action) then action else object[action]
			fn.apply(object,argsClone)

		# Fire the tasks synchronously
		tasks.run()

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



# =====================================
# Export

module.exports = balUtilFlow