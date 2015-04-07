# Import
safeps = null
TaskGroup = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
extractOptsAndCallback = require('extract-opts')

# Prepare
isWindows = process.platform?.indexOf('win') is 0


# =====================================
# Define Globals

# Prepare
global.safepsGlobal ?= {}

# Define Global Pool
# Create a pool with the concurrency of our max number of open processes
global.safepsGlobal.pool ?= new TaskGroup().setConfig({
	concurrency: process.env.NODE_MAX_OPEN_PROCESSES ? 100
	pauseOnError: false
}).run()


# =====================================
# Define Module

safeps =

	# =====================================
	# Open and Close Processes

	# Open a file
	# Pass your callback to fire when it is safe to open the process
	openProcess: (fn) ->
		# Add the task to the pool and execute it right away
		global.safepsGlobal.pool.addTask(fn)

		# Chain
		safeps


	# =================================
	# Environments
	# @TODO These should be abstracted out into their own packages

	# Is Windows
	# Returns whether or not we are running on a windows machine
	isWindows: ->
		return isWindows

	# Get Locale Code
	getLocaleCode: (lang=null) ->
		lang ?= (process.env.LANG or '')
		localeCode = lang.replace(/\..+/, '').replace('-', '_').toLowerCase() or null
		return localeCode

	# Get Language Code
	getLanguageCode: (localeCode=null) ->
		localeCode = safeps.getLocaleCode(localeCode) or ''
		languageCode = localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i, '$1').toLowerCase() or null
		return languageCode

	# Get Country Code
	getCountryCode: (localeCode=null) ->
		localeCode = safeps.getLocaleCode(localeCode) or ''
		countryCode = localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i, '$2').toLowerCase() or null
		return countryCode


	# =================================
	# Executeable Helpers

	# Has Spawn Sync
	hasSpawnSync: ->
		return require('child_process').spawnSync?

	# Has Exec Sync
	hasExecSync: ->
		return require('child_process').execSync?

	# Is Executable
	# next(err, executable)
	isExecutable: (path,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)

		# Sync?
		if opts.sync
			return safeps.isExecutableSync(path, opts, next)

		# Access (Node 0.12+)
		fs = require('fs')
		if fs.access
			fs.access path, fs.X_OK, (err) ->
				executable = !err
				return next(null, executable)

		# Shim
		else
			require('child_process').exec path+' --version', (err) ->
				executable = !err or (err.code isnt 127 and /EACCESS|Permission denied/.test(err.message) is false)
				return next(null, executable)

		# Chain
		@

	# Is Executable Sync
	# next(err, executable)
	isExecutableSync: (path,opts,next) ->
		# Access (Node 0.12+)
		fs = require('fs')
		if fs.accessSync
			try
				fs.accessSync(path, fs.X_OK)
				executable = true
			catch err
				executable = false

		# Shim
		else
			try
				require('child_process').execSync(path+' --version')
				executable = true
			catch err
				executable = err.code isnt 127 and /EACCESS|Permission denied/.test(err.message) is false

		# Return
		if next
			next(null, executable)
			return @
		else
			return executable

	# Internal: Prepare options for an execution
	prepareExecutableOptions: (opts) ->
		# Prepare
		opts or= {}
		opts.safe ?= true
		opts.env ?= process.env
		opts.stdin ?= null
		opts.stdio ?= null
		if opts.stdio
			opts.read = opts.output = false
			opts.outputPrefix = null
		else
			opts.read ?= true
			opts.output ?= !!opts.outputPrefix
			opts.outputPrefix ?= null

		# Prepare env
		delete opts.env  if opts.env is false

		# Return
		return opts

	###
	Internal: Prepare result of an execution
	result: Object
		pid Number Pid of the child process
		output Array Array of results from stdio output
		stdout Buffer|String The contents of output[1]
		stderr Buffer|String The contents of output[2]
		status Number The exit code of the child process
		signal String The signal used to kill the child process
		error Error The error object if the child process failed or timed out
	###
	prepareExecutableResult: (result, opts) ->
		# Output
		if opts.output
			safeps.outputData(result.stdout, 'stdout', opts.outputPrefix)
			safeps.outputData(result.stderr, 'stderr', opts.outputPrefix)

		# Error
		return result  if result.error

		# Check Code
		if result.status? and result.status isnt 0
			message = "Command exited with a non-zero status code."
			if result.stdout
				tmp = safeps.prefixData(result.stdout)
				message += "\nThe command's stdout output:\n"+tmp  if tmp
			if result.stderr
				tmp = safeps.prefixData(result.stderr)
				message += "\nThe command's stderr output:\n"+tmp  if tmp

			result.error = new Error(message)
			return result

		# Success
		return result

	# Internal: Prefix Data
	prefixData: (data, prefix='>\t') ->
		data = data?.toString?() or ''
		data = prefix+data.trim().replace(/\n/g, '\n'+prefix)+'\n'  if prefix and data
		return data

	# Internal: Output Data
	outputData: (data, mode='stdout', prefix) ->
		if data.toString().trim().length isnt 0
			data = safeps.prefixData(data, prefix)  if prefix
			process[mode].write(data)
		return null


	# =================================
	# Spawn

	# Spawn Sync
	# return {error, pid, output, stdout, stderr, status, signal}
	# next(error, stdout, stderr, status, signal)
	spawnSync: (command, opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts = safeps.prepareExecutableOptions(opts)
		opts.sync = true

		# Format the command: string to array
		command = command.split(' ')  if typeChecker.isString(command)

		# Get correct executable path
		if opts.safe
			wasSync = 0
			safeps.getExecPath command[0], opts, (err,execPath) ->
				return  if err
				command[0] = execPath
				wasSync = 1
			if wasSync is 0
				process.stderr.write('safeps.spawnSync: was unable to get the executable path synchronously')

		# Spawn Synchronously
		result = require('child_process').spawnSync(command[0], command.slice(1), opts)
		result = safeps.prepareExecutableResult(result, opts)

		# Complete
		if next
			next(result.error, result.stdout, result.stderr, result.status, result.signal)
		else
			return result

	# Spawn
	# Wrapper around node's spawn command for a cleaner and more powerful API
	# next(error, stdout, stderr, status, signal)
	spawn: (command, opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts = safeps.prepareExecutableOptions(opts)

		# Check if we want sync instead
		if opts.sync
			return safeps.spawnSync(command, opts, next)

		# Patience
		safeps.openProcess (closeProcess) ->
			# Format the command: string to array
			command = command.split(' ')  if typeChecker.isString(command)

			# Prepare
			result = {}
			exited = false

			# Tasks
			tasks = new TaskGroup().done (err) ->
				exited = true
				closeProcess()
				return next(err or result.error, result.stdout, result.stderr, result.status, result.signal)

			# Get correct executable path
			if opts.safe
				tasks.addTask (complete) ->
					safeps.getExecPath command[0], opts, (err,execPath) ->
						return complete(err)  if err
						command[0] = execPath
						return complete()

			# Spawn
			tasks.addTask (complete) ->
				# Spawn
				result.pid = require('child_process').spawn(command[0], command.slice(1), opts)

				# Write
				if opts.stdin
					result.pid.stdin?.write(opts.stdin)
					result.pid.stdin?.end()

				# Read
				if opts.read
					# Update our local globals to strings
					result.stdout = null
					result.stderr = null

					# Listen
					# Streams may be null if stdio is 'inherit'
					result.pid.stdout?.on 'data', (data) ->
						if opts.output
							safeps.outputData(data, 'stdout', opts.outputPrefix)
						if result.stdout
							result.stdout = Buffer.concat([result.stdout, data])
						else
							result.stdout = data
					result.pid.stderr?.on 'data', (data) ->
						if opts.output
							safeps.outputData(data, 'stderr', opts.outputPrefix)
						if result.stderr
							result.stderr = Buffer.concat([result.stderr, data])
						else
							result.stderr = data

				# Wait
				result.pid.on 'close', (status, signal) ->
					# Apply to local global
					result.status = status
					result.signal = signal

					# Check if we have already exited due to domains
					# as without this, then we will fire the completion callback twice
					# once for the domain error that will happen first
					# then again for the close error
					# if it happens the other way round, close, then error, we want to be alerted of that
					return  if exited is true

					# Check result and complete
					opts.output = false
					result = safeps.prepareExecutableResult(result, opts)
					return complete(result.error)


			# Run
			tasks.run()

		# Chain
		@

	# Spawn Multiple
	# next(err,results), results = [result...], result = [err,stdout,stderr,status,signal]
	spawnMultiple: (commands,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.concurrency ?= 1
		results = []

		# Make sure we send back the arguments
		tasks = new TaskGroup().setConfig({concurrency:opts.concurrency}).done (err) ->
			next(err, results)

		# Prepare tasks
		unless typeChecker.isArray(commands)
			commands = [commands]

		# Add tasks
		commands.forEach (command) ->  tasks.addTask (complete) ->
			safeps.spawn command, opts, (args...) ->
				err = args[0] or null
				results.push(args)
				complete(err)

		# Run the tasks
		tasks.run()

		# Chain
		@


	# =================================
	# Exec

	# Exec Sync
	# return {error, stdout}
	# next(error, stdout, stderr)
	# @NOTE:
	# stdout and stderr should be Buffers but they are strings unless encoding:null
	# for now, nothing we should do, besides wait for joyent to reply
	# https://github.com/joyent/node/issues/5833#issuecomment-82189525
	execSync: (command, opts) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts = safeps.prepareExecutableOptions(opts)
		opts.sync = true

		# Output
		if opts.output is true and !opts.outputPrefix
			opts.stdio = 'inherit'
			delete opts.output

		# Spawn Synchronously
		try
			stdout = require('child_process').execSync(command, opts)
		catch err
			error = err

		# Check result
		result = safeps.prepareExecutableResult({error, stdout}, opts)

		# Complete
		if next
			next(result.error, result.stdout, result.stderr)
		else
			return result

	# Exec
	# Wrapper around node's exec command for a cleaner and more powerful API
	# next(err, stdout, stderr)
	# @NOTE:
	# stdout and stderr should be Buffers but they are strings unless encoding:null
	# for now, nothing we should do, besides wait for joyent to reply
	# https://github.com/joyent/node/issues/5833#issuecomment-82189525
	exec: (command,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts = safeps.prepareExecutableOptions(opts)

		# Check if we want sync instead
		if opts.sync
			return safeps.execSync(command, opts, next)

		# Patience
		safeps.openProcess (closeProcess) ->
			# Output
			if opts.output is true and !opts.outputPrefix
				opts.stdio = 'inherit'
				delete opts.output

			# Execute command
			require('child_process').exec command, opts, (error,stdout,stderr) ->
				# Complete the task
				closeProcess()

				# Prepare result
				result = safeps.prepareExecutableResult({error, stdout, stderr}, opts)

				# Complete
				return next(result.error, result.stdout, result.stderr)

		# Chain
		@

	# Exec Multiple
	# next(err,results), results = [result...], result = [err,stdout,stderr]
	execMultiple: (commands,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.concurrency ?= 1
		results = []

		# Make sure we send back the arguments
		tasks = new TaskGroup().setConfig({concurrency: opts.concurrency}).done (err) ->
			next(err, results)

		# Prepare tasks
		unless typeChecker.isArray(commands)
			commands = [commands]

		# Add tasks
		commands.forEach (command) ->  tasks.addTask (complete) ->
			safeps.exec command, opts, (args...) ->
				err = args[0] or null
				results.push(args)
				complete(err)

		# Run the tasks
		tasks.run()

		# Chain
		@


	# =================================
	# Paths

	# Determine an executable path
	# next(err,execPath)
	determineExecPath: (possibleExecPaths,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.sync ?= false
		pathUtil = require('path')
		execPath = null

		# Group
		tasks = new TaskGroup(sync:opts.sync).done (err) ->
			return next(err, execPath)

		# Handle
		possibleExecPaths.forEach (possibleExecPath) ->
			return  unless possibleExecPath
			tasks.addTask (complete) ->
				# Check
				return complete()  if execPath

				# Resolve the path as it may be a virtual or relative path
				possibleExecPath = pathUtil.resolve(possibleExecPath)

				# Check if the executeable exists
				safeps.isExecutable possibleExecPath, opts, (err, executable) ->
					return complete()  if err or !executable
					execPath = possibleExecPath
					return complete()

		# Fire the tasks
		tasks.run()

		# Chain
		@

	# Get Environment Paths
	getEnvironmentPaths: ->
		# Prepare
		pathUtil = require('path')

		# Fetch system include paths with the correct delimiter for the system
		environmentPaths = process.env.PATH.split(pathUtil.delimiter)

		# Return
		return environmentPaths

	# Get Standard Paths
	getStandardExecPaths: (execName) ->
		# Prepare
		pathUtil = require('path')

		# Fetch
		standardExecPaths = [process.cwd()].concat(safeps.getEnvironmentPaths())

		# Get the possible exec paths
		if execName
			standardExecPaths = standardExecPaths.map (path) ->
				return pathUtil.join(path, execName)

		# Return
		return standardExecPaths

	# Get Possible Exec Paths
	getPossibleExecPaths: (execName) ->
		# Fetch available paths
		if isWindows and execName.indexOf('.') is -1
			# we are for windows add the paths for .exe as well
			standardExecPaths = safeps.getStandardExecPaths(execName)
			possibleExecPaths = []
			for standardExecPath in standardExecPaths
				possibleExecPaths.push(standardExecPath, standardExecPath+'.exe', standardExecPath+'.cmd', standardExecPath+'.bat')
		else
			# we are normal, try the paths
			possibleExecPaths = safeps.getStandardExecPaths(execName)

		# Return
		return possibleExecPaths

	# Exec Path Cache
	execPathCache: {}

	# Get an Exec Path
	# We should not absolute relative paths, as relative paths should be attempt at each possible path
	# next(err,foundPath)
	getExecPath: (execName,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Check for absolute path, as we would not be needed and would just currupt the output
		if execName.substr(0,1) is '/' or execName.substr(1,1) is ':'
			next(null, execName)
			return @

		# Prepare
		execNameCapitalized = execName[0].toUpperCase() + execName.substr(1)
		getExecMethodName = 'get'+execNameCapitalized+'Path'

		# Check for special case
		if safeps[getExecMethodName]?
			return safeps[getExecMethodName](opts, next)
		else
			# Check for cache
			if opts.cache and safeps.execPathCache[execName]?
				next(null, safeps.execPathCache[execName])
				return @

			# Fetch possible exec paths
			possibleExecPaths = safeps.getPossibleExecPaths(execName)

			# Forward onto determineExecPath
			# Which will determine which path it is out of the possible paths
			safeps.determineExecPath possibleExecPaths, opts, (err,execPath) ->
				# Check
				return next(err)  if err
				unless execPath
					err = new Error('Could not locate the '+execName+' executable path')
					return next(err)

				# Save to cache
				safeps.execPathCache[execName] = execPath  if opts.cache

				# Forward
				return next(null, execPath)

		# Chain
		@

	# Get Home Path
	# Based upon home function from: https://github.com/isaacs/osenv
	# next(err,homePath)
	getHomePath: (opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Cached
		if opts.cache and safeps.cachedHomePath?
			next(null, safeps.cachedHomePath)
			return @

		# Fetch
		homePath = process.env.USERPROFILE or process.env.HOME

		# Forward
		homePath or= null
		safeps.cachedHomePath = homePath  if opts.cache
		next(null, homePath)

		# Chain
		@

	# Get Tmp Path
	# Based upon tmpdir function from: https://github.com/isaacs/osenv
	# next(err,tmpPath)
	getTmpPath: (opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Cached
		if opts.cache and safeps.cachedTmpPath?
			next(null, safeps.cachedTmpPath)
			return @

		# Prepare
		pathUtil = require('path')
		tmpDirName =
			# Windows
			if isWindows
				'temp'
			# Everything else
			else
				'tmp'

		# Determine
		tmpPath = process.env.TMPDIR or process.env.TMP or process.env.TEMP

		# Fallback
		unless tmpPath
			safeps.getHomePath opts, (err,homePath) ->
				return next(err)  if err
				tmpPath = pathUtil.resolve(homePath, tmpDirName)

				# Fallback
				unless tmpPath
					tmpPath =
						# Windows
						if isWindows
							pathUtil.resolve(process.env.windir or 'C:\\Windows', tmpDirName)
						# Everything else
						else
							'/tmp'

		# Forward
		tmpPath or= null
		safeps.cachedTmpPath = tmpPath  if opts.cache
		next(null, tmpPath)

		# Chain
		@

	# Get Git Path
	# As `git` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,gitPath)
	getGitPath: (opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Cached
		if opts.cache and safeps.cachedGitPath?
			next(null, safeps.cachedGitPath)
			return @

		# Prepare
		execName = if isWindows then 'git.exe' else 'git'
		possibleExecPaths = []
		possibleExecPaths.push(process.env.GIT_PATH)  if process.env.GIT_PATH
		possibleExecPaths.push(process.env.GITPATH)   if process.env.GITPATH
		possibleExecPaths = possibleExecPaths
			.concat(safeps.getStandardExecPaths(execName))
			.concat(
				if isWindows
					[
						"/Program Files (x64)/Git/bin/#{execName}"
						"/Program Files (x86)/Git/bin/#{execName}"
						"/Program Files/Git/bin/#{execName}"
					]
				else
					[
						"/usr/local/bin/#{execName}"
						"/usr/bin/#{execName}"
						"~/bin/#{execName}"  # Rare occasion
					]
			)

		# Determine the right path
		safeps.determineExecPath possibleExecPaths, opts, (err,execPath) ->
			# Cache
			safeps.cachedGitPath = execPath  if opts.cache

			# Check
			return next(err)  if err
			unless execPath
				err = new Error('Could not locate git binary')
				return next(err)

			# Forward
			return next(null, execPath)

		# Chain
		@

	# Get Node Path
	# As `node` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,nodePath)
	getNodePath: (opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Cached
		if opts.cache and safeps.cachedNodePath?
			next(null, safeps.cachedNodePath)
			return @

		# Prepare
		execName = if isWindows then 'node.exe' else 'node'
		possibleExecPaths = []
		possibleExecPaths.push(process.env.NODE_PATH)  if process.env.NODE_PATH
		possibleExecPaths.push(process.env.NODEPATH)   if process.env.NODEPATH
		possibleExecPaths.push(process.execPath)       if /node(.exe)?$/.test(process.execPath)
		possibleExecPaths = possibleExecPaths
			.concat(safeps.getStandardExecPaths(execName))
			.concat(
				if isWindows
					[
						"/Program Files (x64)/nodejs/#{execName}"
						"/Program Files (x86)/nodejs/#{execName}"
						"/Program Files/nodejs/#{execName}"
					]
				else
					[
						"/usr/local/bin/#{execName}"
						"/usr/bin/#{execName}"
						"~/bin/#{execName}"  # Heroku
					]
			)

		# Determine the right path
		safeps.determineExecPath possibleExecPaths, opts, (err,execPath) ->
			# Cache
			safeps.cachedNodePath = execPath  if opts.cache

			# Check
			return next(err)  if err
			unless execPath
				err = new Error('Could not locate node binary')
				return next(err)

			# Forward
			return next(null, execPath)

		# Chain
		@


	# Get Npm Path
	# As `npm` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,npmPath)
	getNpmPath: (opts, next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.cache ?= true

		# Cached
		if opts.cache and safeps.cachedNpmPath?
			next(null, safeps.cachedNpmPath)
			return @

		# Prepare
		execName = if isWindows then 'npm.cmd' else 'npm'
		possibleExecPaths = []
		possibleExecPaths.push(process.env.NPM_PATH)  if process.env.NPM_PATH
		possibleExecPaths.push(process.env.NPMPATH)   if process.env.NPMPATH
		possibleExecPaths.push(process.execPath.replace(/node(.exe)?$/, execName))  if /node(.exe)?$/.test(process.execPath)
		possibleExecPaths = possibleExecPaths
			.concat(safeps.getStandardExecPaths(execName))
			.concat(
				if isWindows
					[
						"/Program Files (x64)/nodejs/#{execName}"
						"/Program Files (x86)/nodejs/#{execName}"
						"/Program Files/nodejs/#{execName}"
					]
				else
					[
						"/usr/local/bin/#{execName}"
						"/usr/bin/#{execName}"
						"~/node_modules/.bin/#{execName}" # Heroku
					]
			)

		# Determine the right path
		safeps.determineExecPath possibleExecPaths, opts, (err,execPath) ->
			# Cache
			safeps.cachedNpmPath = execPath  if opts.cache

			# Check
			return next(err)  if err
			unless execPath
				err = new Error('Could not locate npm binary')
				return next(err)

			# Forward
			return next(null, execPath)

		# Chain
		@


	# =================================
	# Special Commands
	# @TODO These should be abstracted out into their own packages

	# Initialize a Git Repository
	# Requires internet access
	# opts = {path,remote,url,branch,log,output}
	# next(err)
	initGitRepo: (opts,next) ->
		# Extract
		[opts,next] = extractOptsAndCallback(opts,next)
		if opts.path
			err = new Error('safeps.initGitRepo: `path` option is deprecated, use `cwd` option instead.')
			return next(err); @
		opts.cwd    or= process.cwd()
		opts.remote or= 'origin'
		opts.branch or= 'master'

		# Prepare commands
		commands = []
		commands.push ['git', 'init']
		commands.push ['git', 'remote', 'add', opts.remote, opts.url]  if opts.url
		commands.push ['git', 'fetch', opts.remote]
		commands.push ['git', 'pull', opts.remote, opts.branch]
		commands.push ['git', 'submodule', 'init']
		commands.push ['git', 'submodule', 'update', '--recursive']

		# Perform commands
		safeps.spawnMultiple(commands, opts, next)

		# Chain
		@

	# Initialize or Pull a Git Repo
	initOrPullGitRepo: (opts,next) ->
		# Extract
		[opts,next] = extractOptsAndCallback(opts,next)
		if opts.path
			err = new Error('safeps.initOrPullGitRepo: `path` option is deprecated, use `cwd` option instead.')
			return next(err); @
		opts.cwd    or= process.cwd()
		opts.remote or= 'origin'
		opts.branch or= 'master'

		# Check if it exists
		safefs.ensurePath opts.cwd, (err,exists) ->
			return complete(err)  if err
			if exists
				safeps.spawn ['git', 'pull', opts.remote, opts.branch], opts, (err,result...) ->
					return next(err, 'pull', result)
			else
				safeps.initGitRepo opts, (err,result) ->
					return next(err, 'init', result)

		# Chain
		@

	# Init Node Modules
	# with cross platform support
	# supports linux, heroku, osx, windows
	# next(err,results)
	initNodeModules: (opts,next) ->
		# Prepare
		pathUtil = require('path')
		[opts,next] = extractOptsAndCallback(opts,next)
		if opts.path
			err = new Error('safeps.initNodeModules: `path` option is deprecated, use `cwd` option instead.')
			return next(err); @
		opts.cwd    or= process.cwd()
		opts.args   ?=  []
		opts.force  ?=  false

		# Paths
		packageJsonPath = pathUtil.join(opts.cwd, 'package.json')
		nodeModulesPath = pathUtil.join(opts.cwd, 'node_modules')

		# Part Two of this command
		partTwo = ->
			# If there is no package.json file, then we can't do anything
			safefs.exists packageJsonPath, (exists) ->
				return next()  unless exists

				# Prepare command
				command = ['npm', 'install'].concat(opts.args)

				# Execute npm install inside the pugin directory
				safeps.spawn(command, opts, next)

		# Check if node_modules already exists
		if opts.force is false
			safefs.exists nodeModulesPath, (exists) ->
				return next()  if exists
				partTwo()
		else
			partTwo()


		# Chain
		@

	# Spawn a Node Module
	# with cross platform support
	# supports linux, heroku, osx, windows
	# spawnNodeModule(name:string, args:array, opts:object, next:function)
	# Better than https://github.com/mafintosh/npm-execspawn as it uses safeps
	# next(err,results)
	spawnNodeModule: (args...) ->
		# Prepare
		pathUtil = require('path')
		opts = {cwd: process.cwd()}

		# Extract options
		for arg in args
			type = typeof arg
			if Array.isArray(arg)
				opts.args = arg
			else if type is 'object'
				if arg.next?
					next = arg.next
					delete arg.next
				for own key,value of arg
					opts[key] = value
			else if type is 'function'
				next = arg
			else if type is 'string'
				opts.name = arg

		# Command
		if opts.name
			command = [opts.name].concat(opts.args or [])
		else
			command = opts.args or []
		delete opts.name
		delete opts.args

		# Paths
		command[0] = pathUtil.join(opts.cwd, 'node_modules', '.bin', command[0])

		# Spawn
		safeps.spawn(command, opts, next)

		# Chain
		@

# =====================================
# Export

module.exports = safeps