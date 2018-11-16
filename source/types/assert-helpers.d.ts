declare module 'assert-helpers' {
	function equal(actual: any, expected: any, message?: string): void
	function errorEqual(actual: Error | string, expected: string, message?: string): void
}