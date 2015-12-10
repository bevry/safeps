/* eslint no-console:0, no-unused-vars:0, no-sync:0, no-magic-numbers:0, max-params:0 */
'use strict'

// Import
const assert = require('assert')
const {equal, errorEqual} = require('assert-helpers')
const joe = require('joe')
const safeps = require('../../')

// Local Globals
const isTravis = Boolean(process.env.TRAVIS_NODE_VERSION)
if ( process.env.LANG == null ) {
	process.env.LANG = 'en_AU.UTF-8'
}


// =====================================
// Tests

joe.describe('modules', function (describe, it) {

	describe('locale', function (describe, it) {
		describe('getLocaleCode', function (describe, it) {
			it('should fetch something from the environment', function () {
				const localeCode = safeps.getLocaleCode()
				console.log('localeCode:', localeCode)
				assert.ok(localeCode)
			})

			it('should fetch something when passed something', function () {
				let localeCode = safeps.getLocaleCode('fr-CH')
				equal(localeCode, 'fr_ch')
				localeCode = safeps.getLocaleCode('fr_CH')
				equal(localeCode, 'fr_ch')
			})
		})

		describe('getCountryCode', function (describe, it) {
			it('should fetch something', function () {
				const countryCode = safeps.getCountryCode()
				console.log('countryCode:', countryCode)
				assert.ok(countryCode)
			})

			it('should fetch something when passed something', function () {
				const countryCode = safeps.getCountryCode('fr-CH')
				equal(countryCode, 'ch')
			})
		})

		describe('getLanguageCode', function (describe, it) {
			it('should fetch something', function () {
				const languageCode = safeps.getLanguageCode()
				console.log('languageCode:', languageCode)
				assert.ok(languageCode)
			})

			it('should fetch something when passed something', function () {
				const languageCode = safeps.getLanguageCode('fr-CH')
				equal(languageCode, 'fr')
			})
		})
	})

	describe('getHomePath', function (describe, it) {
		it('should fetch home', function (done) {
			safeps.getHomePath(function (err, path) {
				errorEqual(err, null)
				console.log('home:', path)
				assert.ok(path)
				done()
			})
		})
	})

	describe('getTmpPath', function (describe, it) {
		it('should fetch tmp', function (done) {
			safeps.getTmpPath(function (err, path) {
				errorEqual(err, null)
				console.log('tmp:', path)
				assert.ok(path)
				done()
			})
		})
	})

	if ( !isTravis ) {
		describe('getExecPath', function (describe, it) {
			it('should fetch ruby', function (done) {
				let wasSync = 0
				safeps.getExecPath('ruby', function (err, path) {
					wasSync = 1
					errorEqual(err, null)
					console.log('ruby:', path)
					assert.ok(path)
					done()
				})
				equal(wasSync, 0)
			})
		})
	}

	describe('getGitPath', function (describe, it) {
		it('should fetch git', function (done) {
			safeps.getExecPath('git', function (err, path) {
				errorEqual(err, null)
				console.log('git:', path)
				assert.ok(path)
				done()
			})
		})
	})

	describe('getNodePath', function (describe, it) {
		it('should fetch node', function (done) {
			safeps.getExecPath('node', function (err, path) {
				errorEqual(err, null)
				console.log('node:', path)
				assert.ok(path)
				done()
			})
		})

		it('should fetch node from cache', function (done) {
			let wasSync = 0
			safeps.getExecPath('node', function (err, path) {
				wasSync = 1
				errorEqual(err, null)
				console.log('node:', path)
				assert.ok(path)
			})
			equal(wasSync, 1)
			done()
		})

		it('should fetch node without cache synchronously', function (done) {
			let wasSync = 0
			safeps.getExecPath('node', {sync: true, cache: false}, function (err, path) {
				wasSync = 1
				errorEqual(err, null)
				console.log('node:', path)
				assert.ok(path)
			})
			equal(wasSync, 1)
			done()
		})
	})

	describe('getNpmPath', function (describe, it) {
		it('should fetch npm', function (done) {
			safeps.getExecPath('npm', function (err, path) {
				errorEqual(err, null)
				console.log('npm:', path)
				assert.ok(path)
				done()
			})
		})
	})

	describe('spawn node', function (describe, it) {
		it('should work asynchronously', function (done) {
			safeps.spawn('node --version', function (err, stdout, stderr, status, signal) {
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
				done()
			})
		})

		if ( safeps.hasSpawnSync() ) {
			it('should work synchronously with callback', function (done) {
				let wasSync = 0
				safeps.spawnSync('node --version', function (err, stdout, stderr, status, signal) {
					wasSync = 1
					errorEqual(err, null)
					console.log('node version:', stdout.toString().trim())
					equal(stdout instanceof Buffer, true)
					assert.ok(stdout)
				})
				equal(wasSync, 1)
				done()
			})

			it('should work synchronously', function () {
				const {error, stdout, stderr, status, signal} = safeps.spawnSync('node --version')
				errorEqual(error, null)
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
			})
		}

		it("can't read if stdio is set", function (done) {
			safeps.spawn('node --version', {stdio: 'inherit'}, function (err, stdout, stderr, status, signal) {
				errorEqual(err, null)
				equal(stdout, null)
				equal(stderr, null)
				done()
			})
		})
	})

	describe('exec node', function (describe, it) {
		it('should work asynchronously', function (done) {
			safeps.exec('node --version', function (err, stdout, stderr) {
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				// equal(stdout instanceof Buffer, true)
				// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
				done()
			})
		})

		if ( safeps.hasExecSync() ) {
			it('should work synchronously with callback', function (done) {
				let wasSync = 0
				safeps.execSync('node --version', function (err, stdout, stderr, status, signal) {
					wasSync = 1
					errorEqual(err, null)
					console.log('node version:', stdout.toString().trim())
					// equal(stdout instanceof Buffer, true)
					// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
					assert.ok(stdout)
				})
				equal(wasSync, 1)
				done()
			})

			it('should work synchronously', function () {
				const {error, stdout, stderr} = safeps.execSync('node --version')
				errorEqual(error, null)
				console.log('node version:', stdout.toString().trim())
				// equal(stdout instanceof Buffer, true)
				// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
			})
		}
	})

	describe('spawn node module', function (describe, it) {
		it('should work', function (done) {
			safeps.spawnNodeModule('babel', ['--version'], function (err, stdout, stderr, status, signal) {
				errorEqual(err, null)
				console.log('babel version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
				done()
			})
		})
	})
})


	// describe('output prefix node', function (describe, it) {
	// 	it('should work asynchronously', function (done) {
	// 		safeps.spawn 'node --version', {outputPrefix:'> '}, (err,stdout,stderr,status,signal) {
	// 			errorEqual(err, null)
	// 			console.log('node version:', stdout.toString().trim())
	// 			equal(stdout instanceof Buffer, true)
	// 			equal(stdout.toString(), stdout.toString())
	// 			done()

	// 	if safeps.hasSpawnSync() then \
	// 	it('should work synchronously', function () {
	// 		{error,stdout,stderr,status,signal} = safeps.spawnSync('node --version', {outputPrefix:'> '})
	// 		equal(error?.stack or null, null)
	// 		console.log('node version:', stdout.toString().trim())
	// 		equal(stdout instanceof Buffer, true)
	// 		equal(stdout.toString(), stdout.toString())

	// ^ Would need to pass them a stream to write in, which we can read what was written
