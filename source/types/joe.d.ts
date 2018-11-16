declare module 'joe' {

	type Errback = (error?: Error) => void
	type SuiteCallback = (suite: Suite, test: Test, done: Errback) => void
	type Suite = (name: string, cb: SuiteCallback) => void
	type TestCallback = (done: Errback) => void
	type Test = (name: string, cb: TestCallback) => void

	export var suite: Suite
	export var test: Test
}