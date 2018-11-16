import * as cache from '../../cache'
import { PathOptions } from '../..';

/**
* Get home path. Returns the user's home directory.
* Based upon home function from: https://github.com/isaacs/osenv
* @chainable
* @return {this}
*/
export default async function getHomePath(opts: PathOptions = {}) {
	// By default read from the cache and write to the cache
	if (opts.cache == null) opts.cache = true

	// Cached
	const cached = opts.cache && cache.get('home')
	if (cached) return cached

	// Fetch
	const homePath = process.env.USERPROFILE || process.env.HOME
	if (!homePath) throw new Error("home path doesn't seem to exist")

	// Success, write the result to cache and send to our callback
	if (opts.cache) cache.set('home', homePath)
	return homePath
}
