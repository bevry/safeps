// =====================================
// Prepare

// Import
import PromisePool from 'native-promise-pool'
import fsUtil from 'fs'
import pathUtil from 'path'
import * as ps from 'child_process'
import stream from 'stream'

// Locals
import * as cache from './cache'
import getGitPath from './paths/executables/git'
import getNodePath from './paths/executables/node'
import getNpmPath from './paths/executables/npm'
import getHomePath from './paths/general/home'
import getTmpPath from './paths/general/tmp'
export { getGitPath, getNodePath, getNpmPath, getHomePath, getTmpPath }

// Prepare
const IS_WINDOWS = (process.platform || '').indexOf('win') === 0
const DEFAULT_MAX_OPEN_PROCESSES = 100


/** If true, which is not the default, then we should use the synchronous variety of underlying methods behind the scens, such as accessSync, spawnSync, execSync. */
type SyncOption = boolean;

/** If true, the default, then we should make efforts to indentify the command's executable location before running it. */
type SafeOption = boolean;

/** If undefined, use the current process.env for the child. If an object, use the object. */
type EnvOption = NodeJS.ProcessEnv;

interface AccessOptions {
	mode?: number
	sync?: SyncOption
}
export interface PathOptions extends AccessOptions {
	/** If true, which is the default, it will cache the result for quicker access next time. */
	cache?: boolean
}

interface ExecSpawnOptions {
	sync?: SyncOption
	safe?: SafeOption
	env?: EnvOption
}
type ExecOptions = ExecSpawnOptions & ps.ExecOptions;
type ExecSyncOptions = ExecSpawnOptions & ps.ExecSyncOptions;
type SpawnOptions = ExecSpawnOptions & ps.SpawnOptions;
type SpawnSyncOptions = ExecSpawnOptions & ps.SpawnSyncOptions;

interface CheckResult {
	error?: Error | null
	status: number | null
	stdout?: Buffer | string
	stderr?: Buffer | string
}

interface ExecSyncResult {
	stdout: Buffer | string

	/* Provided by ps.execSync */
	error?: Error
}
interface ExecResult {
	process: ps.ChildProcess
	pid: number
	stdout: Buffer | string
	stderr: Buffer | string

	/* Provided by ps.exec */
	error: Error | null

	// technically, it is possible to get signal and status via process
}
interface SpawnSyncResult {
	pid: number
	signal: string
	status: number
	stdout: Buffer | string
	stderr: Buffer | string
	output: string[]

	/* Provided by ps.spawnSync */
	error?: Error
}
interface SpawnResult {
	process: ps.ChildProcess
	pid: number
	signal: string | null
	status: number | null

	/* Provided by safeps.checkExecutableResult */
	error?: Error

	// tehnically, it is possible to get stdout and stderr
}


// =====================================
// Define Globals

// Prepare
const safepsPromisePool = new PromisePool({
	concurrency: process.env.NODE_MAX_OPEN_PROCESSES == null ? DEFAULT_MAX_OPEN_PROCESSES : Number(process.env.NODE_MAX_OPEN_PROCESSES)
})


// =====================================
// Define Locals

/**
* Cache of executable paths
* @access private
*/
const execPathCache = {}


// =====================================
// Open and Close Processes

/**
* Open a file.
* Pass your callback to fire when it is safe to open the process
*/
export function openProcess(task: PromisePoolTask) {
	// Add the task to the pool and execute it right away
	return safepsPromisePool.open(task)
}


// =================================
// Environments
// @TODO These should be abstracted out into their own packages

/**
* Returns whether or not we are running on a windows machine
*/
export function isWindows() {
	return IS_WINDOWS
}

/**
* Get locale code - eg: en-AU, fr-FR, zh-CN etc.
*/
export function getLocaleCode(lang?: string): string {
	lang = lang || process.env.LANG || ''
	return lang.replace(/\..+/, '').replace('-', '_').toLowerCase() || ''
}

/**
* Given the localeCode, return the language code.
*/
export function getLanguageCode(localeCode?: string): string {
	localeCode = getLocaleCode(localeCode)
	return localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i, '$1').toLowerCase() || ''
}

/**
* Given the localeCode, return the country code.
*/
export function getCountryCode(localeCode?: string): string {
	localeCode = getLocaleCode(localeCode)
	return localeCode.replace(/^([a-z]+)[_-]([a-z]+)$/i, '$2').toLowerCase() || ''
}


// =================================
// Executeable Helpers

/**
* Has spawn sync.
* Returns true if the child_process spawnSync, method exists, otherwise false
*/
export function hasSpawnSync(): boolean {
	return ps.spawnSync != null
}

/**
* Has exec sync.
* Returns true if the child_process execSync method exists, otherwise false.
*/
export function hasExecSync(): boolean {
	return ps.execSync != null
}

/**
 * Wraps {@link fs.access} with a promise API that is capable of sync/async interop.
 */
export function access(path: string, { sync = false, mode }: AccessOptions): Promise<boolean> {
	if (sync) {
		try {
			fsUtil.accessSync(path, mode)
			return Promise.resolve(true)
		}
		catch (err) {
			return Promise.reject(err)
		}
	}
	else {
		return new Promise(function (resolve, reject) {
			fsUtil.access(path, mode, function (err) {
				if (err) return Promise.reject(err)
				return Promise.resolve(true)
			})
		})
	}
}

/**
* Wraps {@link access} to check if the path is executable.
*/
export function isExecutable(path: string, { sync, mode = fsUtil.constants.X_OK }: AccessOptions): Promise<boolean> {
	try {
		return access(path, { sync, mode })
	}
	catch (err) {
		return Promise.resolve(false)
	}
}

/**
* Internal: Prepare options for an execution.
* Makes sure all options are populated or exist and gives the opportunity to prepopulate some of those options.
*/
export function prepareExecutableOptions(opts?: ExecSpawnOptions) {
	// Prepare
	opts = opts || {}

	// By default make sure execution is valid
	if (opts.safe == null) opts.safe = true

	// By default make sure sync if off
	if (opts.sync == null) opts.sync = false

	// By default inherit environment variables
	if (opts.env == null) {
		opts.env = process.env
	}

	// Add stdio and stdio
	// if (typeof opts.stdin === 'undefined') opts.stdin = null
	// if (typeof opts.stdio === 'undefined') opts.stdio = null
	// If a direct pipe then don't do output modifiers
	// if (opts.stdio) {
	// 	opts.read = opts.output = false
	// 	opts.outputPrefix = null
	// }
	// Otherwise, set output modifiers
	// else {
	// 	if (opts.read == null) opts.read = true
	// 	if (opts.output == null) opts.output = Boolean(opts.outputPrefix)
	// 	if (opts.outputPrefix == null) opts.outputPrefix = null
	// }

	// Return
	return opts
}

/**
 * Checks the executable result for an invalid status code.
 * @private
 */
function checkExecutableResult(result: CheckResult): void {
	// If we already have an error, then we are done.
	if (result.error) return

	// Otherwise, let's check the status code for an error.
	// Error if the status code exists but is not zero, as zero is the success code.
	if (result.status && result.status !== 0) {
		let message = 'Command exited with a non-zero status code.'

		// Attach stdout and stderr, as the error message is not that much information.
		if (result.stdout) {
			message += "\n\n## The command's stdout output: ##\n\n" + result.stdout.toString()
		}
		// and output the stderr if we have it
		if (result.stderr) {
			message += "\n\n## The command's stderr output:## \n\m" + result.stderr.toString()
		}

		// And create the error from that output.
		result.error = new Error(message)
	}
}


// =================================
// Spawn


/**
* Wrapper around node's spawn command for a cleaner, more robust and powerful API.
* Launches a new process with the given command.
* Command line arguments are part of the command parameter (unlike the node.js spawn).
* Command can be an array of command line arguments or a command line string.
* Opts allows additional options to be sent to the spawning action.
* @example
* const safeps = require('safeps')
* const command = ['npm', 'install', 'jade', '--save']
* try {
*  const {stdout, stderr, status, signal} = await spawn(command, opts)
* }
* catch (err) {
*   console.error(err)
* }
*/
export async function spawn(input: Array<string> | string, opts: SpawnOptions & SpawnSyncOptions = {}): Promise<SpawnResult> {
	// Prepare
	opts = prepareExecutableOptions(opts)

	// If the command is a string, then convert it into an array
	const command =
		typeof input === 'string'
			? input.split(' ')
			: input

	// Open a slot in the pool
	return openProcess(() => new Promise(async function (resolve, reject) {
		// Get correct executable path
		if (opts.safe) {
			try {
				command[0] = await getExecPath(command[0], opts as PathOptions)
			}
			catch (err) {
				// ignore, as we will try with the unresolved path
			}
		}

		// Spawn Synchronously
		if (opts.sync) {
			const result = ps.spawnSync(command[0], command.slice(1), opts)
			checkExecutableResult(result)
			if (result.error) return reject(result.error)
			return resolve(result)
		}
		// Spawn Asynchronously
		else {
			// Spawn
			const process = ps.spawn(command[0], command.slice(1), opts)
			const pid = process.pid

			// Callback
			// if (opts.onInitialised) await opts.onInitialised(result.process)

			// Notice the user about deprecations
			// if (opts.stdin || opts.read || opts.output) {
			// 	throw new Error('opts.stdin, opts.read, opts.output have been removed, use the stdio option, or a the new onInitialised callback option')
			// }

			// Monitor
			process.on('exit', function (status, signal) {
				const result: SpawnResult = { process, pid, status, signal }
				checkExecutableResult(result)
				if (result.error) return reject(result.error)
				return resolve(result)
			})
		}
	}))
}


// =================================
// Exec

/**
* Wrapper around node's exec command for a cleaner, more robust and powerful API.
* Runs a command in a shell and buffers the output.
* Note:
* Stdout and stderr should be Buffers but they are strings unless encoding:null
* for now, nothing we should do, besides wait for joyent to reply
* https://github.com/joyent/node/issues/5833#issuecomment-82189525.
*/
export function exec(command: string, opts: ExecOptions & ExecSyncOptions = {}): Promise<ExecResult> {
	// Prepare
	opts = prepareExecutableOptions(opts)

	// Output
	// if (opts.output === true && !opts.outputPrefix) {
	// 	// opts.stdio = 'inherit'
	// 	opts.output = null
	// }

	// Open a slot in the pool
	return openProcess(() => new Promise(function (resolve, reject) {
		// Execute command
		if (opts.sync) {
			let stdout, error
			try {
				stdout = ps.execSync(command, opts)
			}
			catch (error) {
				return Promise.reject(error)
			}
			return Promise.resolve({ stdout })
		}
		else {
			const process = ps.exec(command, opts, function (error, stdout, stderr) {
				const result: ExecResult = {
					process,
					pid: process.pid,
					error,
					stdout,
					stderr
				}
				if (result.error) return reject(result.error)
				return resolve(result)
			})
		}
	}))
}


// =================================
// Paths

/**
* Determine an executable path from the passed array of possible file paths.
* Called by {@link getExecPath} to find a path for a given executable name.
*/
export async function determineExecPath(possibleExecPaths: Array<string>, opts: AccessOptions): Promise<string | null> {
	// Handle
	for (let possibleExecPath of possibleExecPaths) {
		// Check if the path is invalid, if it is, skip it
		if (!possibleExecPath) continue

		// Resolve the path as it may be a virtual or relative path
		possibleExecPath = pathUtil.resolve(possibleExecPath)

		// Check if the executeable exists
		const executable = await isExecutable(possibleExecPath, opts)
		if (executable) return possibleExecPath
	}

	// No valid exec paths
	return null
}

/**
* Get the system's environment paths.
*/
export function getEnvironmentPaths(): Array<string> {
	// Fetch system include paths with the correct delimiter for the system
	const environmentPaths = (process.env.PATH || '').split(pathUtil.delimiter)

	// Return
	return environmentPaths
}

/**
* Get the possible paths for the passed executable using the standard environment paths.
* Basically, get a list of places to look for the executable. Only safe for non-Windows systems.
*/
export function getStandardExecPaths(execName: string): Array<string> {
	// Fetch
	let standardExecPaths = [process.cwd()].concat(getEnvironmentPaths())

	// Get the possible exec paths
	if (execName) {
		standardExecPaths = standardExecPaths.map(function (path) {
			return pathUtil.join(path, execName)
		})
	}

	// Return
	return standardExecPaths
}

/**
* Get the possible paths for the passed executable using the standard environment paths.
* Basically, get a list of places to look for the executable.
* Makes allowances for Windows executables possibly needing an extension to ensure execution (.exe, .cmd, .bat).
*/
export function getPossibleExecPaths(execName: string): Array<string> {
	let possibleExecPaths

	// Fetch available paths
	if (isWindows && execName.indexOf('.') === -1) {
		// we are for windows add the paths for .exe as well
		const standardExecPaths = getStandardExecPaths(execName)
		possibleExecPaths = []
		for (let i = 0; i < standardExecPaths.length; ++i) {
			const standardExecPath = standardExecPaths[i]
			possibleExecPaths.push(
				standardExecPath,
				standardExecPath + '.exe',
				standardExecPath + '.cmd',
				standardExecPath + '.bat'
			)
		}
	}
	else {
		// we are normal, try the paths
		possibleExecPaths = getStandardExecPaths(execName)
	}

	// Return
	return possibleExecPaths
}

/**
* Given an executable name, search and find its actual path.
* Will search the standard file paths defined by the environment to see if the executable is in any of those paths.
*/
export async function getExecPath(execName: string, opts: PathOptions = {}): Promise<string> {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Check for absolute path, as we would not be needed and would just currupt the output
	if (execName.substr(0, 1) === '/' || execName.substr(1, 1) === ':') {
		return execName
	}

	// Convert to lowercase to make the rest easier
	execName = execName.toLowerCase()

	// Check for cache
	const cached = opts.cache && cache.get(execName)
	if (cached) return cached

	// Handle special locations
	switch (execName) {
		case 'git':
			return getGitPath(opts)
		case 'node':
			return getNodePath(opts)
		case 'npm':
			return getNpmPath(opts)
	}

	// Fetch possible exec paths
	const possibleExecPaths = getPossibleExecPaths(execName)

	// Forward onto determineExecPath
	// Which will determine which path it is out of the possible paths
	const execPath = await determineExecPath(possibleExecPaths, opts)
	if (!execPath) {
		throw new Error(`Could not locate the ${execName} executable path`)
	}
	else {
		// Success, write the result to cache and send to our callback
		if (opts.cache) cache.set(execName, execPath)
		return execPath
	}
}
