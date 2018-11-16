import * as cache from '../../cache'
import { isWindows, getStandardExecPaths, determineExecPath, PathOptions } from '../..'

/**
* Path to the evironment's Node directory.
* As 'node' is not always available in the environment path,
* we should check common path locations and if we find one that works,
* then we should use it.
* @param {Object} [opts]
* @param {Object} [opts.cache=true]
* @param {Function} next
* @param {Error} next.err
* @param {String} next.nodePath
* @chainable
* @return {this}
*/
export default async function getNodePath(opts: PathOptions = {}) {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Cached
	const cached = opts.cache && cache.get('node')
	if (cached) return cached

	// Prepare
	const execName = isWindows ? 'node.exe' : 'node'
	const possibleExecPaths = []

	// Add environment paths
	if (process.env.NODE_PATH) possibleExecPaths.push(process.env.NODE_PATH)
	if (process.env.NODEPATH) possibleExecPaths.push(process.env.NODEPATH)
	if (/node(.exe)?$/.test(process.execPath)) possibleExecPaths.push(process.execPath)

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
			`~/bin/${execName}`  // User and Heroku
		)
	}

	// Determine the right path
	const execPath = await determineExecPath(possibleExecPaths, opts)
	if (!execPath) {
		throw new Error('Could not locate node binary')
	}
	else {
		// Success, write the result to cache and send to our callback
		if (opts.cache) cache.set('node', execPath)
		return execPath
	}
}
