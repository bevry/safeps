import * as cache from '../../cache'
import { isWindows, PathOptions } from '../..'
import pathUtil from 'path'
import getHomePath from './home';

/**
* Path to the evironment's temporary directory.
* Based upon tmpdir function from: https://github.com/isaacs/osenv
* @param {Object} [opts]
* @param {Object} [opts.cache=true]
* @param {Function} next
* @param {Error} next.err
* @param {String} next.tmpPath
* @chainable
* @return {this}
*/
export default async function getTmpPath(opts: PathOptions = {}) {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Cached
	const cached = opts.cache && cache.get('tmp')
	if (cached) return cached


	// Prepare
	const tmpDirName = isWindows ? 'temp' : 'tmp'

	// Try the OS environment temp path
	let tmpPath = process.env.TMPDIR || process.env.TMP || process.env.TEMP || null

	// Fallback
	if (!tmpPath) {
		// Try the user directory temp path
		const homePath = await getHomePath(opts)
		tmpPath = pathUtil.resolve(homePath, tmpDirName)

		// Fallback
		if (!tmpPath) {
			// Try the system temp path
			// @TODO perhaps we should check if we have write access to this path
			tmpPath = isWindows
				? pathUtil.resolve(process.env.windir || 'C:\\Windows', tmpDirName)
				: '/tmp'
		}
	}

	// Check if we couldn't find it, we should always be able to find it
	if (!tmpPath) {
		throw new Error("Wan't able to find a temporary path")
	}

	// Success, write the result to cache and send to our callback
	if (opts.cache) cache.set('tmp', tmpPath)
	return tmpPath
}
