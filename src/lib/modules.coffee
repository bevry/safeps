# Import
safeps = null
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
{extractOptsAndCallback} = require('extract-opts')

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

	# Close a process
	# Only here for backwards compatibility, do not use this
	closeProcess: ->
		# Log
		console.log('safeps.closeProcess has been deprecated, please use the safeps.openProcess completion callback to close files')

		# Chain
		safeps


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
	# Spawn

	# Spawn
	# Wrapper around node's spawn command for a cleaner and more powerful API
	# next(err,stdout,stderr,code,signal)
	spawn: (command, opts, next) ->
		# Patience
		safeps.openProcess (closeProcess) ->
			# Prepare
			{spawn} = require('child_process')
			[opts,next] = extractOptsAndCallback(opts, next)
			opts.safe ?= true
			opts.read ?= true
			opts.output ?= false
			opts.stdin ?= null

			# Format the command: string to array
			command = command.split(' ')  if typeChecker.isString(command)

			# Prepare
			pid = null
			err = null
			stdout = null
			stderr = null
			code = null
			signal = null
			tasks = new TaskGroup().once 'complete', ->
				closeProcess()
				return next?(err, stdout, stderr, code, signal)

			# Find
			if opts.safe
				tasks.addTask (complete) ->
					safeps.getExecPath command, (err,execPath) ->
						return complete(err)  if err
						command[0] = execPath
						return complete()

			# Execute
			tasks.addTask (complete) ->
				# Spawn
				pid = spawn(command[0], command.slice(1), opts)

				# Read
				if opts.read
					# Prepare
					stdout = ''
					stderr = ''

					# Listen
					pid.stdout.on 'data', (data) ->
						process.stdout.write(data)  if opts.output
						stdout += data.toString()
					pid.stderr.on 'data', (data) ->
						process.stderr.write(data)  if opts.output
						stderr += data.toString()

				# Wait
				pid.on 'close', (code,signal) ->
					err = null
					if code isnt 0
						err = new Error(stderr or 'exited with a non-zero status code')
					return complete()

				# Write
				if opts.stdin
					pid.stdin.write(opts.stdin)
					pid.stdin.end()

		# Chain
		@

	# Spawn Multiple
	# next(err,results), results = [result...], result = [err,stdout,stderr,code,signal]
	spawnMultiple: (commands,opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)
		opts.concurrency ?= 1
		results = []

		# Make sure we send back the arguments
		tasks = new TaskGroup().setConfig({concurrency:opts.concurrency}).once 'complete', (err) ->
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
	# Command

	# Spawn Command
	spawnCommand: (command,args=[],opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)

		# Prefix the path to the arguments
		pieces = [command].concat(args)

		# Forward onto spawn
		safeps.spawn(pieces, opts, next)

		# Chain
		@

	# Spawn Commands
	spawnCommands: (command,multiArgs=[],opts,next) ->
		# Prepare
		[opts,next] = extractOptsAndCallback(opts, next)

		# Prefix the path to the arguments
		pieces = []
		for args in multiArgs
			pieces.push [command].concat(args)

		# Forward onto spawn multiple
		safeps.spawnMultiple(pieces, opts, next)

		# Chain
		@


	# =================================
	# Exec

	# Exec
	# Wrapper around node's exec command for a cleaner and more powerful API
	# next(err,stdout,stderr)
	exec: (command,opts,next) ->
		# Patience
		safeps.openProcess (closeProcess) ->
			# Prepare
			{exec} = require('child_process')
			[opts,next] = extractOptsAndCallback(opts, next)
			opts.output ?= false

			# Output
			if opts.output
				opts.stdio = 'inherit'
				delete opts.output

			# Execute command
			exec command, opts, (err,stdout,stderr) ->
				# Complete the task
				closeProcess()
				return next(err, stdout, stderr)

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
		tasks = new TaskGroup().setConfig({concurrency: opts.concurrency}).once 'complete', (err) ->
			next(err, results)

		# Prepare tasks
		unless typeChecker.isArray(commands)
			commands = [commands]

		# Add tasks
		commands.forEach (command) ->  tasks.addTask (complete) ->
			safeps.exec @command, opts, (args...) ->
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
			next(err, execPath)

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
					safeps.spawn [possibleExecPath, '--version'], {env:process.env}, (err,stdout,stderr,code,signal) ->
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
		# Fetch system include paths with the correct delimiter for the system
		environmentPaths = process.env.PATH.split(pathUtil.delimiter)

		# Return
		return environmentPaths

	# Get Standard Paths
	getStandardExecPaths: (execName) ->
		# Prepare
		possibleExecPaths = [process.cwd()].concat(safeps.getEnvironmentPaths())

		# Get the possible exec paths
		if execName
			possibleExecPaths = possibleExecPaths.map (path) ->
				return pathUtil.join(path, execName)

		# Return
		return possibleExecPaths

	# Get an Exec Path
	# next(err,foundPath)
	getExecPath: (execName,next) ->
		# Prepare
		execNameCapitalized = execName[0].toUpperCase() + execName.substr(1)
		getExecMethodName = 'get'+execNameCapitalized+'Path'

		# Check for special case
		if safeps[getExecMethodName]?
			safeps[getExecMethodName](next)
		else
			# Fetch available paths
			if isWindows and execName.indexOf('.') is -1
				# we are for windows add the paths for .exe as well
				possibleExecPaths = safeps.getStandardExecPaths(execName+'.exe').concat(safeps.getStandardExecPaths(execName))
			else
				# we are normal, try the paths
				possibleExecPaths = safeps.getStandardExecPaths(execName)

			# Forward onto determineExecPath
			# Which will determine which path it is out of the possible paths
			safeps.determineExecPath(possibleExecPaths, next)

		# Chain
		@

	# Get Home Path
	# Based upon home function from: https://github.com/isaacs/osenv
	# next(err,homePath)
	getHomePath: (next) ->
		# Cached
		if safeps.cachedHomePath?
			next(null,safeps.cachedHomePath)
			return @

		# Fetch
		homePath = process.env.USERPROFILE or process.env.HOME

		# Forward
		homePath or= null
		safeps.cachedHomePath = homePath
		next(null,homePath)

		# Chain
		@

	# Get Tmp Path
	# Based upon tmpdir function from: https://github.com/isaacs/osenv
	# next(err,tmpPath)
	getTmpPath: (next) ->
		# Cached
		if safeps.cachedTmpPath?
			next(null,safeps.cachedTmpPath)
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
			safeps.getHomePath (err,homePath) ->
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
		safeps.cachedTmpPath = tmpPath
		next(null,tmpPath)

		# Chain
		@

	# Get Git Path
	# As `git` is not always available to use, we should check common path locations
	# and if we find one that works, then we should use it
	# next(err,gitPath)
	getGitPath: (next) ->
		# Cached
		if safeps.cachedGitPath?
			next(null,safeps.cachedGitPath)
			return @

		# Prepare
		execName = if isWindows then 'git.exe' else 'git'
		possibleExecPaths =
			[
				process.env.GIT_PATH
				process.env.GITPATH
			]
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
		safeps.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			safeps.cachedGitPath = execPath

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
		if safeps.cachedNodePath?
			next(null,safeps.cachedNodePath)
			return @

		# Prepare
		execName = if isWindows then 'node.exe' else 'node'
		possibleExecPaths =
			[
				process.env.NODE_PATH
				process.env.NODEPATH
				(if /node(.exe)?$/.test(process.execPath) then process.execPath else '')
			]
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
		safeps.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			safeps.cachedNodePath = execPath

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
		if safeps.cachedNpmPath?
			next(null,safeps.cachedNpmPath)
			return @

		# Prepare
		execName = if isWindows then 'npm.cmd' else 'npm'
		possibleExecPaths =
			[
				process.env.NPM_PATH
				process.env.NPMPATH
				(if /node(.exe)?$/.test(process.execPath) then process.execPath.replace(/node(.exe)?$/, execName) else '')
			]
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
		safeps.determineExecPath possibleExecPaths, (err,execPath) ->
			# Cache
			safeps.cachedNpmPath = execPath

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
	# opts = {path,remote,url,branch,log,output}
	# next(err)
	initGitRepo: (opts,next) ->
		# Extract
		[opts,next] = extractOptsAndCallback(opts,next)
		if opts.path  # legacy
			opts.cwd = opts.path
			delete opts.path
		opts.cwd    or= process.cwd()
		opts.remote or= 'origin'
		opts.branch or= 'master'

		# Prepare commands
		commands = []
		commands.push ['init']
		commands.push ['remote', 'add', opts.remote, opts.url]  if opts.url
		commands.push ['fetch', opts.remote]
		commands.push ['pull', opts.remote, opts.branch]
		commands.push ['submodule', 'init']
		commands.push ['submodule', 'update', '--recursive']

		# Perform commands
		safeps.spawnCommands('git', commands, opts, next)

		# Chain
		@

	# Initialize or Pull a Git Repo
	initOrPullGitRepo: (opts,next) ->
		# Extract
		[opts,next] = extractOptsAndCallback(opts,next)
		if opts.path  # legacy
			opts.cwd = opts.path
			delete opts.path
		opts.cwd    or= process.cwd()
		opts.remote or= 'origin'
		opts.branch or= 'master'

		# Check if it exists
		safefs.ensurePath opts.cwd, (err,exists) =>
			return complete(err)  if err
			if exists
				safeps.spawnCommand 'git', ['pull', opts.remote, opts.branch], opts, (err,result...) ->
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
		if opts.path  # legacy
			opts.cwd = opts.path
			delete opts.path
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
				command = ['install'].concat(opts.args)

				# Execute npm install inside the pugin directory
				safeps.spawnCommand('npm', command, opts, next)

		# Check if node_modules already exists
		if opts.force is false
			safefs.exists nodeModulesPath, (exists) ->
				return next()  if exists
				partTwo()
		else
			partTwo()


		# Chain
		@


# =====================================
# Export

module.exports = safeps