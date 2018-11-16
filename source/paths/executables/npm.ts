import * as cache from '../../cache'
import { isWindows, getStandardExecPaths, determineExecPath, PathOptions } from '../..'

/**
* Path to the evironment's NPM directory.
* As 'npm' is not always available in the environment path,
* we should check common path locations and if we find one that works,
* then we should use it.
* @param {Object} [opts]
* @param {Object} [opts.cache=true]
* @param {Function} next
* @param {Error} next.err
* @param {String} next.npmPath
* @chainable
* @return {this}
*/
export default async function getNpmPath(opts: PathOptions = {}) {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Cached
	const cached = opts.cache && cache.get('npm')
	if (cached) return cached

	// Prepare
	const execName = isWindows ? 'npm.cmd' : 'npm'
	const possibleExecPaths = []

	// Add environment paths
	if (process.env.NPM_PATH) possibleExecPaths.push(process.env.NPM_PATH)
	if (process.env.NPMPATH) possibleExecPaths.push(process.env.NPMPATH)
	if (/node(.exe)?$/.test(process.execPath)) possibleExecPaths.push(process.execPath.replace(/node(.exe)?$/, execName))

	// Add standard paths
	possibleExecPaths.push(...getStandardExecPaths(execName))

	// Add custom paths
	if (isWindows) {
		possibleExecPaths.push(
			`/Program Files (x64)/nodejs/${execName}`,
			`/Program Files (x86)/nodejs/${execName}`,
			`/Program Files/nodejs/${execName}`
		)
	}
	else {
		possibleExecPaths.push(
			`/usr/local/bin/${execName}`,
			`/usr/bin/${execName}`,
			`~/node_modules/.bin/${execName}` // User and Heroku
		)
	}

	// Determine the right path
	const execPath = await determineExecPath(possibleExecPaths, opts)
	if (!execPath) {
		throw new Error('Could not locate npm binary')
	}
	else {
		// Success, write the result to cache and send to our callback
		if (opts.cache) cache.set('npm', execPath)
		return execPath
	}
}
