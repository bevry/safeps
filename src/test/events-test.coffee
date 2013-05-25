# Import
{expect,assert} = require('chai')
joe = require('joe')
{EventEmitterEnhanced,EventSystem} = require('../../')
debug = false


# =====================================
# Event Emitter Enhanced

joe.describe 'EventEmitterEnhanced', (describe,it) ->
	eventEmitter = null

	it 'should construct', ->
		eventEmitter = new EventEmitterEnhanced()

	# Serial
	it 'should work in serial', (done) ->
		# Prepare
		first = second = 0

		# Asynchronous
		eventEmitter.on 'serial-test', (opts,next) ->
			first++
			setTimeout(
				->
					expect(second).to.eql(0)
					first++
					next()
				500
			)

		# Synchronous
		eventEmitter.on 'serial-test', ->
			expect(first).to.eql(2)
			second += 2

		# Correct amount of listeners?
		expect(eventEmitter.listeners('serial-test').length).to.eql(2)

		# Emit and check
		eventEmitter.emitSerial 'serial-test', null, (err) ->
			expect(err).to.eql(null)
			expect(first).to.eql(2)
			expect(second).to.eql(2)
			done()

	# Parallel
	it 'should work in parallel', (done) ->
		# Prepare
		first = second = 0

		# Asynchronous
		eventEmitter.on 'parallel-test', (opts,next) ->
			first++
			setTimeout(
				->
					expect(second).to.eql(2)
					first++
					next()
				500
			)

		# Synchronous
		eventEmitter.on 'parallel-test', ->
			expect(first).to.eql(1)
			second += 2

		# Correct amount of listeners?
		expect(eventEmitter.listeners('parallel-test').length).to.eql(2)

		# Emit and check
		eventEmitter.emitParallel 'parallel-test', null, (err) ->
			expect(err).to.eql(null)
			expect(first).to.eql(2)
			expect(second).to.eql(2)
			done()

	# Parallel
	it 'should work with once', (done) ->
		# Prepare
		first = second = 0

		# Asynchronous
		eventEmitter.once 'once-test', (opts,next) ->
			first++
			setTimeout(
				->
					expect(second).to.eql(2)
					first++
					next()
				500
			)

		# Synchronous
		eventEmitter.once 'once-test', ->
			expect(first).to.eql(1)
			second += 2

		# Correct amount of listeners?
		expect(eventEmitter.listeners('once-test').length).to.eql(2)

		# Emit and check
		eventEmitter.emitParallel 'once-test', null, (err) ->
			expect(err).to.eql(null)
			expect(first).to.eql(2)
			expect(second).to.eql(2)
			expect(eventEmitter.listeners('once-test').length).to.eql(0)
			done()

	# Off
	it 'should work with off', (done) ->
		# Prepare
		counterA = counterB = 0

		# Synchronous
		eventEmitter.on 'off-test', listenerA = ->
			expect(counterA).to.eql(0)
			expect(counterB).to.eql(0)
			counterA++

		# Synchronous
		eventEmitter.on 'off-test', listenerB = ->
			expect(counterA).to.eql(0)
			expect(counterB).to.eql(0)
			counterB++

		# Correct amount of listeners?
		expect(eventEmitter.listeners('off-test').length).to.eql(2)

		# Remove and check again
		eventEmitter.off('off-test', listenerA)
		expect(eventEmitter.listeners('off-test').length).to.eql(1)

		# Emit and check
		eventEmitter.emitSerial 'off-test', null, (err) ->
			expect(err).to.eql(null)
			expect(counterA).to.eql(0)
			expect(counterB).to.eql(1)
			done()

	# Priorities
	it 'should work with priorities', (done) ->
		# Prepare
		counterA = counterB = counterC = 0

		# Exec First
		listenerA = ->
			expect(counterA).to.eql(0)
			expect(counterB).to.eql(0)
			expect(counterC).to.eql(0)
			counterA++
		listenerA.priority = 500
		eventEmitter.on('priority-test', listenerA)

		# Exec Last
		listenerB = ->
			expect(counterA).to.eql(1)
			expect(counterB).to.eql(0)
			expect(counterC).to.eql(1)
			counterB++
		listenerB.priority = 300
		eventEmitter.on('priority-test', listenerB)

		# Exec Second
		listenerC = ->
			expect(counterA).to.eql(1)
			expect(counterB).to.eql(0)
			expect(counterC).to.eql(0)
			counterC++
		listenerC.priority = 400
		eventEmitter.on('priority-test', listenerC)


		# Correct amount of listeners?
		expect(eventEmitter.listeners('priority-test').length).to.eql(3)

		# Emit and check
		eventEmitter.emitSerial 'priority-test', null, (err) ->
			expect(err).to.eql(null)
			expect(counterA).to.eql(1)
			expect(counterB).to.eql(1)
			expect(counterC).to.eql(1)
			done()



# =====================================
# Event System

class Person extends EventSystem
	###
	A person can eat while they drink, but they can't drink while they eat
	This has come from the fact that if you have food in your mouth, you can still drink things
	Whereas if you have drink in your mouth, then put food in your mouth, the drink goes everywhere
	###

	# Eat something
	eat: (something,next) ->
		console.log "#{something}: started food"  if debug

		# Start eating
		console.log "#{something}: start eating"  if debug
		@start 'eating', (err) =>
			# Eating
			console.log "#{something}: eating"  if debug
			return next?(err)  if err

			# Finish eating after 2 seconds
			setTimeout(=>
				# Finished eating
				console.log "#{something}: swallowed food"  if debug

				# Perform our callback
				next?(null,something)

				# Clean up
				console.log "#{something}: start finish"  if debug
				@finished 'eating', (err) ->
					# Finished drinking
					console.log "#{something}: finished food"  if debug
					return next?(err)  if err

			,2*1000)


	# Drink something
	drink: (something,next) ->
		console.log "#{something}: started drink"  if debug

		# Prevent eating
		console.log "#{something}: blocking eating"  if debug
		@block 'eating', (err) =>
			# Eating blocked
			console.log "#{something}: blocked eating"  if debug
			return next?(err)  if err

			# Start drinking
			console.log "#{something}: start drinking"  if debug
			@start 'drinking', (err) =>
				# Drinking
				console.log "#{something}: drinking"  if debug
				return next?(err)  if err

				# Finish drinking after 1 seconds
				setTimeout(=>
					console.log "#{something}: swallowed drink"  if debug

					# Perform our callback
					next?(null,something)

					# Clean up
					console.log "#{something}: start finish"  if debug
					@finished 'drinking', (err) =>
						# Finished drinking
						console.log "#{something}: finished drink"  if debug
						return done(err)  if err

						# Resume eating
						console.log "#{something}: unblocking eating"  if debug
						@unblock 'eating', (err) =>
							console.log "#{something}: unblocked eating"  if debug
							return done(err)  if err

				,1*1000)


# -------------------------------------
# Tests

joe.describe 'EventSystem', (describe,it) ->

	it 'should work as expected', (done) ->
		# Prepare
		foods = ['apple','orange','grape']
		drinks = ['coke','fanta','water']
		myPerson = new Person()

		# Completion handlers
		foodsAte = []
		drinksDrunk = []
		myPersonTriedToDrinkThenEat = false

		# Track the order of what myPerson ate
		eating = false
		drinking = false
		myPerson.on 'eating:locked', ->
			console.log 'eating:locked'  if debug
		myPerson.on 'eating:unlocked', ->
			console.log 'eating:unlocked'  if debug
		myPerson.on 'eating:started', ->
			console.log 'eating:started'  if debug
			if drinking is true
				console.log 'myPerson just tried to eat then drink'  if debug
				myPersonTriedToDrinkThenEat = true
			eating = true
		myPerson.on 'eating:finished', ->
			console.log 'eating:finished'  if debug
			eating = false

		myPerson.on 'drinking:locked', ->
			console.log 'drinking:locked'  if debug
		myPerson.on 'drinking:unlocked', ->
			console.log 'drinking:unlocked'  if debug
		myPerson.on 'drinking:started', ->
			console.log 'drinking:started'  if debug
			drinking = true
		myPerson.on 'drinking:finished', ->
			console.log 'drinking:finished'  if debug
			drinking = false

		# Track what myPerson ate
		ateAFood = (err,something) ->
			return done(err)  if err
			foodsAte.push something
			console.log "completely finished eating #{something} - #{foodsAte.length}/#{foods.length}"  if debug
		drankADrink = (err,something) ->
			return done(err)  if err
			drinksDrunk.push something
			console.log "completely finished drinking #{something} - #{drinksDrunk.length}/#{drinks.length}"  if debug

		# Stuff myPerson full of stuff
		myPerson.eat(food,ateAFood)  for food in foods
		myPerson.drink(drink,drankADrink)  for drink in drinks

		# Async
		setTimeout(
			->
				assert.equal(foods.length, foodsAte.length, 'myPerson ate all his foods')
				assert.equal(drinks.length, drinksDrunk.length, 'myPerson ate all his drinks')
				assert.equal(false, myPersonTriedToDrinkThenEat, 'myPerson tried to drink then eat, when he shouldn\'t have')
				done()
			,14000
		)
