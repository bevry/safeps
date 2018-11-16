/* eslint no-console:0, no-unused-vars:0, no-sync:0, max-params:0 */
'use strict'

// Import
import assert from 'assert'
import { equal, errorEqual } from 'assert-helpers'
import joe from 'joe'
import * as safeps from './index'

// Local Globals
const isTravis = Boolean(process.env.TRAVIS_NODE_VERSION)
if (process.env.LANG == null) {
	process.env.LANG = 'en_AU.UTF-8'
}

// =====================================
// Tests

joe.suite('modules', function (suite, test) {

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
			safeps.getHomePath().then(function (path) {
				console.log('home:', path)
				assert.ok(path)
				done()
			}).catch(done)
		})
	})

	suite('getTmpPath', function (suite, test) {
		test('should fetch tmp', function (done) {
			safeps.getTmpPath().then(function (path) {
				console.log('tmp:', path)
				assert.ok(path)
				done()
			}).catch(done)
		})
	})

	if (!isTravis) {
		suite('getExecPath', function (suite, test) {
			test('should fetch ruby', function (done) {
				let wasSync = 0
				safeps.getExecPath('ruby').then(function (path) {
					wasSync = 1
					console.log('ruby:', path)
					assert.ok(path)
					done()
				}).catch(done)
				equal(wasSync, 0)
			})
		})
	}

	suite('getGitPath', function (suite, test) {
		test('should fetch git', function (done) {
			safeps.getExecPath('git').then(function (path) {
				console.log('git:', path)
				assert.ok(path)
				done()
			}).catch(done)
		})
	})

	suite('getNodePath', function (suite, test) {
		test('should fetch node', function (done) {
			safeps.getExecPath('node').then(function (path) {
				console.log('node:', path)
				assert.ok(path)
				done()
			}).catch(done)
		})

		test('should fetch node from cache', function (done) {
			let wasSync = 0
			safeps.getExecPath('node').then(function (path) {
				wasSync = 1
				console.log('node:', path)
				assert.ok(path)
			}).catch(done)
			equal(wasSync, 1)
			done()
		})

		test('should fetch node without cache synchronously', function (done) {
			let wasSync = 0
			safeps.getExecPath('node', { sync: true, cache: false }).then(function (path) {
				wasSync = 1
				console.log('node:', path)
				assert.ok(path)
			}).catch(done)
			equal(wasSync, 1)
			done()
		})
	})

	suite('getNpmPath', function (suite, test) {
		test('should fetch npm', function (done) {
			safeps.getExecPath('npm').then(function (path) {
				console.log('npm:', path)
				assert.ok(path)
				done()
			}).catch(done)
		})
	})

	// suite('spawn node', function (suite, test) {
	// 	test('should work asynchronously', function (done) {
	// 		safeps.spawn('node --version').then(function ({ stdout, stderr, status, signal }) {
	// 			console.log('node version:', stdout.toString().trim())
	// 			equal(stdout instanceof Buffer, true)
	// 			assert.ok(stdout)
	// 			done()
	// 		}).catch(done)
	// 	})

	// 	if (safeps.hasSpawnSync()) {
	// 		test('should work synchronously with callback', function (done) {
	// 			let wasSync = 0
	// 			safeps.spawn('node --version', { sync: true }).then(function ({ stdout, stderr, status, signal }) {
	// 				wasSync = 1
	// 				console.log('node version:', stdout.toString().trim())
	// 				equal(stdout instanceof Buffer, true)
	// 				assert.ok(stdout)
	// 			}).catch(done)
	// 			equal(wasSync, 1)
	// 			done()
	// 		})
	// 	}

	// 	test("can't read if stdio is set", function (done) {
	// 		safeps.spawn('node --version', { stdio: 'inherit' }).then(function ({ stdout, stderr, status, signal }) {
	// 			equal(stdout, null)
	// 			equal(stderr, null)
	// 			done()
	// 		}).catch(done)
	// 	})
	// })

	suite('exec node', function (suite, test) {
		test('should work asynchronously', function (done) {
			safeps.exec('node --version').then(function ({ stdout, stderr }) {
				console.log('node version:', stdout.toString().trim())
				// equal(stdout instanceof Buffer, true)
				// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
				done()
			}).catch(done)
		})

		// if (safeps.hasExecSync()) {
		// 	test('should work synchronously with callback', function (done) {
		// 		let wasSync = 0
		// 		safeps.exec('node --version', { sync: true }).then(function ({ stdout, stderr, status, signal }) {
		// 			wasSync = 1
		// 			console.log('node version:', stdout.toString().trim())
		// 			// equal(stdout instanceof Buffer, true)
		// 			// ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
		// 			assert.ok(stdout)
		// 		}).catch(done)
		// 		equal(wasSync, 1)
		// 		done()
		// 	})
		// }
	})

	// suite('spawn node module', function (suite, test) {
	// 	test('should work', function (done) {
	// 		safeps.spawnNodeModule('babel', ['--version'], function (err, stdout, stderr, status, signal) {
	// 			errorEqual(err, null)
	// 			console.log('babel version:', stdout.toString().trim())
	// 			equal(stdout instanceof Buffer, true)
	// 			assert.ok(stdout)
	// 			done()
	// 		})
	// 	})
	// })
})


// suite('output prefix node', function (suite, test) {
// 	test('should work asynchronously', function (done) {
// 		safeps.spawn 'node --version', {outputPrefix:'> '}, (err,stdout,stderr,status,signal) {
// 			errorEqual(err, null)
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
