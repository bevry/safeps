# Import
balUtilModules = null
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
balUtilFlow = require('./flow')

# Prepare
isWindows = process?.platform?.indexOf('win') is 0


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

balUtilModules =

	# =====================================
	# Open and Close Processes

	# Open a file
	# Pass your callback to fire when it is safe to open the process
	openProcess: (fn) ->
		# Add the task to the pool and execute it right away
		global.safepsGlobal.pool.addTask(fn)

		# Chain
		balUtilModules

	# Close a process
	# Only here for backwards compatibility, do not use this
	closeFile: ->
		# Log
		console.log('safeps.closeFile has been deprecated, please use the safeps.openFile completion callback to close files')

		# Chain
		balUtilModules


	# =================================
	# Require

	# Require Fresh
	# Require the file without adding it into the cache
	requireFresh: (path) ->
		path = require('path').resolve(path)
		delete require.cache[path]  # clear require cache for the config file
		result = require(path)
		delete require.cache[path]  # clear require cache for the config file
		return result


	# =================================
	# Environments

	# Is Windows
	# Returns whether or not we are running on a windows machine
	isWindows: ->
		return isWindows

	# Get Locale Code
	getLocaleCode: (lang=null) ->
		lang ?= (process.env.LANG or '')
		localeCode = lang.replace(/\..+/,'').replace('-','_').toLowerCase() or null
		return localeCode

	# Get Language Code
	getLanguageCode: (localeCode=null) ->
		localeCode = balUtilModules.getLocaleCode(localeCode) or ''
		languageCode = localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i,'$1').toLowerCase() or null
		return languageCode

	# Get Country Code
	getCountryCode: (localeCode=null) ->
		localeCode = balUtilModules.getLocaleCode(localeCode) or ''
		countryCode = localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i,'$2').toLowerCase() or null
		return countryCode


	# =================================
	# Spawn

	# Spawn
	# Wrapper around node's spawn command for a cleaner and more powerful API
	# next(err,stdout,stderr,code,signal)
	spawn: (command,opts,next) ->
		# Patience
		balUtilModules.openProcess (closeProcess) ->
			# Prepare
			{spawn} = require('child_process')
			[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)

			# Prepare
			pid = null
			err = null
			stdout = ''
			stderr = ''

			# Prepare format
			if typeChecker.isString(command)
				command = command.split(' ')

			# Execute command
			if typeChecker.isArray(command)
				pid = spawn(command[0], command.slice(1), opts)
			else
				pid = spawn(command.command, command.args or [], command.options or opts)

			# Fetch
			pid.stdout.on 'data', (data) ->
				process.stdout.write(data)  if opts.output
				stdout += data.toString()
			pid.stderr.on 'data', (data) ->
				process.stderr.write(data)  if opts.output
				stderr += data.toString()

			# Wait
			pid.on 'exit', (code,signal) ->
				err = null
				if code isnt 0
					err = new Error(stderr or 'exited with a non-zero status code')
				closeProcess()
				next(err,stdout,stderr,code,signal)

			# Stdin?
			if opts.stdin
				# Write the content to stdin
				pid.stdin.write(opts.stdin)
				pid.stdin.end()

		# Chain
		@

	# Spawn Multiple
	# next(err,results), results = [result...], result = [err,stdout,stderr,code,signal]
	spawnMultiple: (commands,opts,next) ->
		# Prepare
		[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)
		opts.tasksMode or= 'serial'
		results = []

		# Make sure we send back the arguments
		concurrency = if opts.tasksMode is 'serial' then 1 else 0
		tasks = new TaskGroup().setConfig({concurrency}).once 'complete', (err) ->
			next(err,results)

		# Prepare tasks
		unless typeChecker.isArray(commands)
			commands = [commands]

		# Add tasks
		commands.forEach (command) ->  tasks.addTask (complete) ->
			balUtilModules.spawn command, opts, (args...) ->
				err = args[0] or null
				results.push(args)
				complete(err)

		# Run the tasks
		tasks.run()

		# Chain
		@


	# =================================
	# Command

	# Spawn Command
	spawnCommand: (command,args=[],opts,next) ->
		# Get the executable path of the command
		balUtilModules.getExecPath command, (err,execPath) ->
			# Check
			return next(err)  if err

			# Prefix the path to the arguments
			pieces = [execPath].concat(args)

			# Forward onto spawn
			balUtilModules.spawn(pieces, opts, next)

		# Chain
		@

	# Spawn Commands
	spawnCommands: (command,multiArgs=[],opts,next) ->
		# Get the executable path of the command
		balUtilModules.getExecPath command, (err,execPath) ->
			# Check
			return next(err)  if err

			# Prefix the path to the arguments
			pieces = []
			for args in multiArgs
				pieces.push = [execPath].concat(args)

			# Forward onto spawn multiple
			balUtilModules.spawnMultiple(pieces, opts, next)

		# Chain
		@


	# =================================
	# Exec

	# Exec
	# Wrapper around node's exec command for a cleaner and more powerful API
	# next(err,stdout,stderr)
	exec: (command,opts,next) ->
		# Patience
		balUtilModules.openProcess (closeProcess) ->
			# Prepare
			{exec} = require('child_process')
			[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)

			# Output
			if opts.output
				opts.stdio = 'inherit'
				delete opts.output

			# Execute command
			exec command, opts, (err,stdout,stderr) ->
				# Complete the task
				closeProcess()
				next(err,stdout,stderr)

		# Chain
		@

	# Exec Multiple
	# next(err,results), results = [result...], result = [err,stdout,stderr]
	execMultiple: (commands,opts,next) ->
		# Prepare
		[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)
		opts.tasksMode or= 'serial'
		results = []

		# Make sure we send back the arguments
		concurrency = if opts.tasksMode is 'serial' then 1 else 0
		tasks = new TaskGroup().setConfig({concurrency}).once 'complete', (err) ->
			next(err,results)

		# Prepare tasks
		unless typeChecker.isArray(commands)
			commands = [commands]

		# Add tasks
		commands.forEach (command) ->  tasks.addTask (complete) ->
			balUtilModules.exec @command, opts, (args...) ->
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
	determineExecPath: (possibleExecPaths,next) ->
		# Prepare
		pathUtil = require('path')
		execPath = null

		# Group
		tasks = new TaskGroup().once 'complete', (err) ->
			next(err,execPath)

		# Handle
		possibleExecPaths.forEach (possibleExecPath) ->
			return  unless possibleExecPath
			tasks.addTask (complete) ->
				# Check
				return complete()  if execPath

				# Resolve the path as it may be a virtual or relative path
				possibleExecPath = pathUtil.resolve(possibleExecPath)

				# Check if the path exists
				safefs.exists possibleExecPath, (exists) ->
					# Skip if the path doesn't exist
					return complete()  unless exists

					# Check to see if the path is an executable
					balUtilModules.spawn [possibleExecPath, '--version'], {env:process.env}, (err,stdout,stderr,code,signal) ->
						# Problem
						return complete()  if err

						# Good
						execPath = possibleExecPath
						return complete()

		# Fire the tasks
		tasks.run()

		# Chain
		@

	# Get Environment Paths
	getEnvironmentPaths: ->
		# Fetch system include paths
		if balUtilModules.isWindows()
			environmentPaths = process.env.PATH.split(/;/g)
		else
			environmentPaths = process.env.PATH.split(/:/g)

		# Return
		return environmentPaths

	# Get standard exec paths
	getStandardExecPaths: (execName) ->
		# Prepare
		possibleExecPaths = [process.cwd()].concat(balUtilModules.getEnvironmentPaths())
		for value,index in possibleExecPaths
			possibleExecPaths[index] = value.replace(/\/$/,'')

		# Get the possible exec paths
		possibleExecPaths = balUtilFlow.suffixArray("/#{execName}", possibleExecPaths)  if execName

		# Return
		return possibleExecPaths

	# Get an Exec Path
	# next(err,foundPath)
	getExecPath: (execName,next) ->
		# Prepare
		execNameCapitalized = execName[0].toUpperCase() + execName.substr(1)
		getExecMethodName = 'get'+execNameCapitalized+'Path'

		# Check for special case
		if balUtilModules[getExecMethodName]?
			balUtilModules[getExecMethodName](next)
		else
			# Fetch available paths
			if isWindows and execName.indexOf('.') is -1
				# we are for windows add the paths for .exe as well
				possibleExecPaths = balUtilModules.getStandardExecPaths(execName+'.exe').concat(balUtilModules.getStandardExecPaths(execName))
			else
				# we are normal, try the paths
				possibleExecPaths = balUtilModules.getStandardExecPaths(execName)

			# Forward onto determineExecPath
			# Which will determine which path it is out of the possible paths
			balUtilModules.determineExecPath(possibleExecPaths, next)

		# Chain
		@

	# Get Home Path
	# Based upon home function from: https://github.com/isaacs/osenv
	# next(err,homePath)
	getHomePath: (next) ->
		# Cached
		if balUtilModules.cachedHomePath?
			next(null,balUtilModules.cachedHomePath)
			return @

		# Fetch
		homePath = process.env.USERPROFILE or process.env.HOME

		# Forward
		homePath or= null
		balUtilModules.cachedHomePath = homePath
		next(null,homePath)

		# Chain
		@

	# Get Tmp Path
	# Based upon tmpdir function from: https://github.com/isaacs/osenv
	# next(err,tmpPath)
	getTmpPath: (next) ->
		# Cached
		if balUtilModules.cachedTmpPath?
			next(null,balUtilModules.cachedTmpPath)
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
			balUtilModules.getHomePath (err,homePath) ->
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
		balUtilModules.cachedTmpPath = tmpPath
		next(null,tmpPath)

		# Chain
		@

	# Get Git Path
	# As `git` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,gitPath)
	getGitPath: (next) ->
		# Cached
		if balUtilModules.cachedGitPath?
			next(null,balUtilModules.cachedGitPath)
			return @

		# Prepare
		execName = if isWindows then 'git.exe' else 'git'
		possibleExecPaths =
			[
				process.env.GIT_PATH
				process.env.GITPATH
			]
			.concat(balUtilModules.getStandardExecPaths(execName))
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
		balUtilModules.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			balUtilModules.cachedGitPath = execPath

			# Check
			return next(err)  if err
			return next(new Error('Could not locate git binary'))  unless execPath

			# Forward
			return next(null,execPath)

		# Chain
		@

	# Get Node Path
	# As `node` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,nodePath)
	getNodePath: (next) ->
		# Cached
		if balUtilModules.cachedNodePath?
			next(null,balUtilModules.cachedNodePath)
			return @

		# Prepare
		execName = if isWindows then 'node.exe' else 'node'
		possibleExecPaths =
			[
				process.env.NODE_PATH
				process.env.NODEPATH
				(if /node(.exe)?$/.test(process.execPath) then process.execPath else '')
			]
			.concat(balUtilModules.getStandardExecPaths(execName))
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
		balUtilModules.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			balUtilModules.cachedNodePath = execPath

			# Check
			return next(err)  if err
			return next(new Error('Could not locate node binary'))  unless execPath

			# Forward
			return next(null,execPath)

		# Chain
		@


	# Get Npm Path
	# As `npm` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,npmPath)
	getNpmPath: (next) ->
		# Cached
		if balUtilModules.cachedNpmPath?
			next(null,balUtilModules.cachedNpmPath)
			return @

		# Prepare
		execName = if isWindows then 'npm.cmd' else 'npm'
		possibleExecPaths =
			[
				process.env.NPM_PATH
				process.env.NPMPATH
				(if /node(.exe)?$/.test(process.execPath) then process.execPath.replace(/node(.exe)?$/,execName) else '')
			]
			.concat(balUtilModules.getStandardExecPaths(execName))
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
		balUtilModules.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			balUtilModules.cachedNpmPath = execPath

			# Check
			return next(err)  if err
			return next(new Error('Could not locate npm binary'))  unless execPath

			# Forward
			return next(null,execPath)

		# Chain
		@


	# =================================
	# Special Commands

	# Initialize a Git Repository
	# Requires internet access
	# opts = {path,remote,url,branch,logger,output,gitPath}
	# next(err)
	initGitRepo: (opts,next) ->
		# Extract
		[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)
		{path,remote,url,branch,logger,output,gitPath} = opts
		remote or= 'origin'
		branch or= 'master'

		# Prepare commands
		commands = [
			['init']
			['remote', 'add', remote, url]
			['fetch', remote]
			['pull', remote, branch]
			['submodule', 'init']
			['submodule', 'update', '--recursive']
		]

		# Perform commands
		logger.log 'debug', "Initializing git repo with url [#{url}] on directory [#{path}]"  if logger
		balUtilModules.spawnCommands 'git', commands, {gitPath:gitPath,cwd:path,output:output}, (args...) ->
			return next(args...)  if args[0]?
			logger.log 'debug', "Initialized git repo with url [#{url}] on directory [#{path}]"  if logger
			return next(args...)

		# Chain
		@

	# Initialize or Pull a Git Repo
	initOrPullGitRepo: (opts,next) ->
		# Extract
		[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)
		{path,remote,branch} = opts
		remote or= 'origin'
		branch or= 'master'

		# Check if it exists
		safefs.ensurePath path, (err,exists) =>
			return complete(err)  if err
			if exists
				opts.cwd = path
				balUtilModules.spawnCommand('git', ['pull',remote,branch], opts, next)
			else
				balUtilModules.initGitRepo(opts, next)

		# Chain
		@

	# Init Node Modules
	# with cross platform support
	# supports linux, heroku, osx, windows
	# next(err,results)
	initNodeModules: (opts,next) ->
		# Prepare
		pathUtil = require('path')
		[opts,next] = balUtilFlow.extractOptsAndCallback(opts,next)
		{path,logger,force} = opts
		opts.cwd = path

		# Paths
		packageJsonPath = pathUtil.join(path,'package.json')
		nodeModulesPath = pathUtil.join(path,'node_modules')

		# Part Two of this command
		partTwo = ->
			# If there is no package.json file, then we can't do anything
			safefs.exists packageJsonPath, (exists) ->
				return next()  unless exists

				# Prepare command
				command = ['install']
				command.push('--force')  if force

				# Execute npm install inside the pugin directory
				logger.log 'debug', "Initializing node modules\non:   #{dirPath}\nwith:",command  if logger
				balUtilModules.spawnCommand 'npm', command, opts, (args...) ->
					return next(args...)  if args[0]?
					logger.log 'debug', "Initialized node modules\non:   #{dirPath}\nwith:",command  if logger
					return next(args...)

		# Check if node_modules already exists
		if force is false
			safefs.exists nodeModulesPath, (exists) ->
				return next()  if exists
				partTwo()
		else
			partTwo()


		# Chain
		@


# =====================================
# Export

module.exports = balUtilModules