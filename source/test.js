/* eslint no-console:0, no-unused-vars:0, no-sync:0, max-params:0 */
'use strict'

// Import
const assert = require('assert')
const { equal, errorEqual, contains, nullish } = require('assert-helpers')
const kava = require('kava')
const safeps = require('./index.js')

// Local Globals
const isTravis = Boolean(process.env.TRAVIS_NODE_VERSION)
if (process.env.LANG == null) {
	process.env.LANG = 'en_AU.UTF-8'
}

// =====================================
// Tests

kava.suite('modules', function (suite, test) {
	suite('locale', function (suite, test) {
		suite('getLocaleCode', function (suite, test) {
			test('should fetch something from the environment', function () {
				const localeCode = safeps.getLocaleCode()
				console.log('localeCode:', localeCode)
				assert.ok(localeCode)
			})

			test('should fetch something when passed something', function () {
				let localeCode = safeps.getLocaleCode('fr-CH')
				equal(localeCode, 'fr_ch')
				localeCode = safeps.getLocaleCode('fr_CH')
				equal(localeCode, 'fr_ch')
			})
		})

		suite('getCountryCode', function (suite, test) {
			test('should fetch something', function () {
				const countryCode = safeps.getCountryCode()
				console.log('countryCode:', countryCode)
				assert.ok(countryCode)
			})

			test('should fetch something when passed something', function () {
				const countryCode = safeps.getCountryCode('fr-CH')
				equal(countryCode, 'ch')
			})
		})

		suite('getLanguageCode', function (suite, test) {
			test('should fetch something', function () {
				const languageCode = safeps.getLanguageCode()
				console.log('languageCode:', languageCode)
				assert.ok(languageCode)
			})

			test('should fetch something when passed something', function () {
				const languageCode = safeps.getLanguageCode('fr-CH')
				equal(languageCode, 'fr')
			})
		})
	})

	suite('getHomePath', function (suite, test) {
		test('should fetch home', function (done) {
			safeps.getHomePath(function (err, path) {
				nullish(err, 'no error')
				console.log('home:', path)
				assert.ok(path)
				done()
			})
		})
	})

	suite('getTmpPath', function (suite, test) {
		test('should fetch tmp', function (done) {
			safeps.getTmpPath(function (err, path) {
				nullish(err, 'no error')
				console.log('tmp:', path)
				assert.ok(path)
				done()
			})
		})
	})

	if (!isTravis) {
		suite('getExecPath', function (suite, test) {
			test('should fetch ruby', function (done) {
				let wasSync = 0
				safeps.getExecPath('ruby', function (err, path) {
					wasSync = 1
					nullish(err, 'no error')
					console.log('ruby:', path)
					assert.ok(path)
					done()
				})
				equal(wasSync, 0)
			})
		})
	}

	suite('getGitPath', function (suite, test) {
		test('should fetch git', function (done) {
			safeps.getExecPath('git', function (err, path) {
				nullish(err, 'no error')
				console.log('git:', path)
				assert.ok(path)
				done()
			})
		})
	})

	suite('getNodePath', function (suite, test) {
		test('should fetch node', function (done) {
			safeps.getExecPath('node', function (err, path) {
				nullish(err, 'no error')
				console.log('node:', path)
				assert.ok(path)
				done()
			})
		})

		test('should fetch node from cache', function (done) {
			let wasSync = 0
			safeps.getExecPath('node', function (err, path) {
				wasSync = 1
				nullish(err, 'no error')
				console.log('node:', path)
				assert.ok(path)
			})
			equal(wasSync, 1)
			done()
		})

		test('should fetch node without cache synchronously', function (done) {
			let wasSync = 0
			safeps.getExecPath('node', { sync: true, cache: false }, function (
				err,
				path
			) {
				wasSync = 1
				nullish(err, 'no error')
				console.log('node:', path)
				assert.ok(path)
			})
			equal(wasSync, 1)
			done()
		})
	})

	suite('getNpmPath', function (suite, test) {
		test('should fetch npm', function (done) {
			safeps.getExecPath('npm', function (err, path) {
				nullish(err, 'no error')
				console.log('npm:', path)
				assert.ok(path)
				done()
			})
		})
	})

	suite('spawn node', function (suite, test) {
		test('should work asynchronously', function (done) {
			safeps.spawn('node --version', function (
				err,
				stdout,
				stderr,
				status,
				signal
			) {
				nullish(err, 'no error')
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
				done()
			})
		})

		if (safeps.hasSpawnSync()) {
			test('should work synchronously with callback', function (done) {
				let wasSync = 0
				safeps.spawnSync('node --version', function (
					err,
					stdout,
					stderr,
					status,
					signal
				) {
					wasSync = 1
					nullish(err, 'no error')
					console.log('node version:', stdout.toString().trim())
					equal(stdout instanceof Buffer, true)
					assert.ok(stdout)
				})
				equal(wasSync, 1)
				done()
			})

			test('should work synchronously', function () {
				const { error, stdout, stderr, status, signal } = safeps.spawnSync(
					'node --version'
				)
				nullish(error, 'no error')
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
			})
		}

		test("can't read if stdio is set", function (done) {
			safeps.spawn('node --version', { stdio: 'inherit' }, function (
				err,
				stdout,
				stderr,
				status,
				signal
			) {
				nullish(err, 'no error')
				equal(stdout, null)
				equal(stderr, null)
				done()
			})
		})
	})

	suite('exec node', function (suite, test) {
		test('should work asynchronously', function (done) {
			safeps.exec('node --version', function (err, stdout, stderr) {
				nullish(err, 'no error')
				console.log('node version:', stdout.toString().trim())
				// equal(stdout instanceof Buffer, true)
				// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
				done()
			})
		})

		if (safeps.hasExecSync()) {
			test('should work synchronously with callback', function (done) {
				let wasSync = 0
				safeps.execSync('node --version', function (
					err,
					stdout,
					stderr,
					status,
					signal
				) {
					wasSync = 1
					nullish(err, 'no error')
					console.log('node version:', stdout.toString().trim())
					// equal(stdout instanceof Buffer, true)
					// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
					assert.ok(stdout)
				})
				equal(wasSync, 1)
				done()
			})

			test('should work synchronously', function () {
				const { error, stdout, stderr } = safeps.execSync('node --version')
				nullish(error, 'no error')
				console.log('node version:', stdout.toString().trim())
				// equal(stdout instanceof Buffer, true)
				// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
			})
		}
	})

	suite('spawn node module', function (suite, test) {
		test('should work', function (done) {
			const random = Math.random()
			safeps.spawnNodeModule('bevry-echo', [random], function (
				err,
				stdout,
				stderr,
				status,
				signal
			) {
				nullish(err, 'no error')
				contains(stdout.toString().trim(), random)
				done()
			})
		})
	})
})

// suite('output prefix node', function (suite, test) {
// 	test('should work asynchronously', function (done) {
// 		safeps.spawn 'node --version', {outputPrefix:'> '}, (err,stdout,stderr,status,signal) {
// 			nullish(err, 'no error')
// 			console.log('node version:', stdout.toString().trim())
// 			equal(stdout instanceof Buffer, true)
// 			equal(stdout.toString(), stdout.toString())
// 			done()

// 	if safeps.hasSpawnSync() then \
// 	test('should work synchronously', function () {
// 		{error,stdout,stderr,status,signal} = safeps.spawnSync('node --version', {outputPrefix:'> '})
// 		equal(error?.stack or null, null)
// 		console.log('node version:', stdout.toString().trim())
// 		equal(stdout instanceof Buffer, true)
// 		equal(stdout.toString(), stdout.toString())

// ^ Would need to pass them a stream to write in, which we can read what was written
