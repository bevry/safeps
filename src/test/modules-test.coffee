# Import
{expect} = require('chai')
joe = require('joe')
safefs = require('../..')
TaskGroup = require('taskgroup')

# Test
joe.describe 'safeps', (describe,it) ->

	it 'should work correctly', (done) ->
		openFiles = 0
		closedFiles = 0
		maxOpenFiles = 100
		totalFiles = maxOpenFiles*2

		# Add all our open tasks
		[0...totalFiles].forEach (i) ->
			# Open
			safefs.openFile (closeFile) ->
				++openFiles

				# Check for logical conditions
				expect(openFiles, 'check 1').to.be.lte(maxOpenFiles)

				# Delay would go here if we are over the limit
				process.nextTick ->
					# Check for logical conditions
					expect(openFiles, 'check 2').to.be.lte(maxOpenFiles)

					# Close the file
					closeFile()
					++closedFiles
					--openFiles

					if closedFiles is totalFiles
						done()

			# Check for logical conditions
			expect(openFiles, 'check 4').to.be.lte(maxOpenFiles)
