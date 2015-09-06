# Import
assert = require('assert')
{equal, deepEqual, errorEqual} = require('assert-helpers')
joe = require('joe')
safeps = require('../../')

# Local Globals
travis = process.env.TRAVIS_NODE_VERSION?
process.env.LANG ?= 'en_AU.UTF-8'


# =====================================
# Tests

joe.describe 'modules', (describe,it) ->

	describe 'locale', (describe,it) ->
		describe 'getLocaleCode', (describe,it) ->
			it 'should fetch something from the environment', ->
				localeCode = safeps.getLocaleCode()
				console.log('localeCode:', localeCode)
				assert.ok(localeCode)

			it 'should fetch something when passed something', ->
				localeCode = safeps.getLocaleCode('fr-CH')
				equal(localeCode, 'fr_ch')
				localeCode = safeps.getLocaleCode('fr_CH')
				equal(localeCode, 'fr_ch')

		describe 'getCountryCode', (describe,it) ->
			it 'should fetch something', ->
				countryCode = safeps.getCountryCode()
				console.log('countryCode:', countryCode)
				assert.ok(countryCode)

			it 'should fetch something when passed something', ->
				countryCode = safeps.getCountryCode('fr-CH')
				equal(countryCode, 'ch')

		describe 'getLanguageCode', (describe,it) ->
			it 'should fetch something', ->
				languageCode = safeps.getLanguageCode()
				console.log('languageCode:', languageCode)
				assert.ok(languageCode)

			it 'should fetch something when passed something', ->
				languageCode = safeps.getLanguageCode('fr-CH')
				equal(languageCode, 'fr')

	describe 'getHomePath', (describe,it) ->
		it 'should fetch home', (done) ->
			safeps.getHomePath (err,path) ->
				errorEqual(err, null)
				console.log('home:',path)
				assert.ok(path)
				done()

	describe 'getTmpPath', (describe,it) ->
		it 'should fetch tmp', (done) ->
			safeps.getTmpPath (err,path) ->
				errorEqual(err, null)
				console.log('tmp:',path)
				assert.ok(path)
				done()

	unless travis then \
	describe 'getExecPath', (describe,it) ->
		it 'should fetch ruby', (done) ->
			wasSync = 0
			safeps.getExecPath 'ruby', (err,path) ->
				wasSync = 1
				errorEqual(err, null)
				console.log('ruby:',path)
				assert.ok(path)
				done()
			equal(wasSync, 0)

	describe 'getGitPath', (describe,it) ->
		it 'should fetch git', (done) ->
			safeps.getExecPath 'git', (err,path) ->
				errorEqual(err, null)
				console.log('git:',path)
				assert.ok(path)
				done()

	describe 'getNodePath', (describe,it) ->
		it 'should fetch node', (done) ->
			safeps.getExecPath 'node', (err,path) ->
				errorEqual(err, null)
				console.log('node:',path)
				assert.ok(path)
				done()

		it 'should fetch node from cache', (done) ->
			wasSync = 0
			safeps.getExecPath 'node', (err,path) ->
				wasSync = 1
				errorEqual(err, null)
				console.log('node:',path)
				assert.ok(path)
			equal(wasSync, 1)
			done()

		it 'should fetch node without cache synchronously', (done) ->
			wasSync = 0
			safeps.getExecPath 'node', {sync:true,cache:false}, (err,path) ->
				wasSync = 1
				errorEqual(err, null)
				console.log('node:',path)
				assert.ok(path)
			equal(wasSync, 1)
			done()

	describe 'getNpmPath', (describe,it) ->
		it 'should fetch npm', (done) ->
			safeps.getExecPath 'npm', (err,path) ->
				errorEqual(err, null)
				console.log('npm:',path)
				assert.ok(path)
				done()

	# Prepare for later
	nodeVersion = null

	describe 'spawn node', (describe, it) ->
		it 'should work asynchronously', (done) ->
			safeps.spawn 'node --version', (err,stdout,stderr,status,signal) ->
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
				nodeVersion = stdout.toString().trim()
				done()

		if safeps.hasSpawnSync() then \
		it 'should work synchronously with callback', (done) ->
			wasSync = 0
			safeps.spawnSync 'node --version', (err,stdout,stderr,status,signal) ->
				wasSync = 1
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
			equal(wasSync, 1)
			done()

		if safeps.hasSpawnSync() then \
		it 'should work synchronously', ->
			{error,stdout,stderr,status,signal} = safeps.spawnSync('node --version')
			equal(error?.stack or null, null)
			console.log('node version:', stdout.toString().trim())
			equal(stdout instanceof Buffer, true)
			assert.ok(stdout)

		it "can't read if stdio is set", (done) ->
			safeps.spawn 'node --version', {stdio:'inherit'}, (err,stdout,stderr,status,signal) ->
				errorEqual(err, null)
				equal(stdout, null)
				equal(stderr, null)
				done()

	describe 'exec node', (describe, it) ->
		it 'should work asynchronously', (done) ->
			safeps.exec 'node --version', (err,stdout,stderr) ->
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				# equal(stdout instanceof Buffer, true)
				# ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
				done()

		if safeps.hasExecSync() then \
		it 'should work synchronously with callback', (done) ->
			wasSync = 0
			safeps.execSync 'node --version', (err,stdout,stderr,status,signal) ->
				wasSync = 1
				errorEqual(err, null)
				console.log('node version:', stdout.toString().trim())
				# equal(stdout instanceof Buffer, true)
				# ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
				assert.ok(stdout)
			equal(wasSync, 1)
			done()

		if safeps.hasExecSync() then \
		it 'should work synchronously', ->
			{error,stdout,stderr} = safeps.execSync('node --version')
			equal(error?.stack or null, null)
			console.log('node version:', stdout.toString().trim())
			# equal(stdout instanceof Buffer, true)
			# ^ https://github.com/joyent/node/issues/5833#issuecomment-82189525
			assert.ok(stdout)

	describe 'spawn node module', (describe, it) ->
		it 'should work', (done) ->
			safeps.spawnNodeModule 'coffeelint', ['--version'], (err,stdout,stderr,status,signal) ->
				errorEqual(err, null)
				console.log('coffeelint version:', stdout.toString().trim())
				equal(stdout instanceof Buffer, true)
				assert.ok(stdout)
				nodeVersion = stdout.toString().trim()
				done()

	#
	# describe 'output prefix node', (describe, it) ->
	# 	it 'should work asynchronously', (done) ->
	# 		safeps.spawn 'node --version', {outputPrefix:'> '}, (err,stdout,stderr,status,signal) ->
	# 			errorEqual(err, null)
	# 			console.log('node version:', stdout.toString().trim())
	# 			equal(stdout instanceof Buffer, true)
	# 			equal(stdout.toString(), stdout.toString())
	# 			done()
	#
	# 	if safeps.hasSpawnSync() then \
	# 	it 'should work synchronously', ->
	# 		{error,stdout,stderr,status,signal} = safeps.spawnSync('node --version', {outputPrefix:'> '})
	# 		equal(error?.stack or null, null)
	# 		console.log('node version:', stdout.toString().trim())
	# 		equal(stdout instanceof Buffer, true)
	# 		equal(stdout.toString(), stdout.toString())
	#
	# ^ Would need to pass them a stream to write in, which we can read what was written