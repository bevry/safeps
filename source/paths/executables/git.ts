import * as cache from '../../cache'
import { isWindows, getStandardExecPaths, determineExecPath, PathOptions } from '../..'

/**
* Path to the evironment's GIT directory.
* As 'git' is not always available in the environment path, we should check
* common path locations and if we find one that works, then we should use it.
* @param {Object} [opts]
* @param {Object} [opts.cache=true]
* @param {Function} next
* @param {Error} next.err
* @param {String} next.gitPath
* @chainable
* @return {this}
*/
export default async function getGitPath(opts: PathOptions = {}) {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Cached
	const cached = opts.cache && cache.get('git')
	if (cached) return cached

	// Prepare
	const execName = isWindows ? 'git.exe' : 'git'
	const possibleExecPaths = []

	// Add environment paths
	if (process.env.GIT_PATH) possibleExecPaths.push(process.env.GIT_PATH)
	if (process.env.GITPATH) possibleExecPaths.push(process.env.GITPATH)

	// Add standard paths
	possibleExecPaths.push(...getStandardExecPaths(execName))

	// Add custom paths
	if (isWindows) {
		possibleExecPaths.push(
			`/Program Files (x64)/Git/bin/${execName}`,
			`/Program Files (x86)/Git/bin/${execName}`,
			`/Program Files/Git/bin/${execName}`
		)
	}
	else {
		possibleExecPaths.push(
			`/usr/local/bin/${execName}`,
			`/usr/bin/${execName}`,
			`~/bin/${execName}`
		)
	}

	// Determine the right path
	const execPath = await determineExecPath(possibleExecPaths, opts)
	if (!execPath) {
		throw new Error('Could not locate git binary')
	}
	else {
		// Success, write the result to cache and send to our callback
		if (opts.cache) cache.set('git', execPath)
		return execPath
	}
}
