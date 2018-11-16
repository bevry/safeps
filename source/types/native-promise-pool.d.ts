declare module 'native-promise-pool'

type PromisePoolTask = () => Promise<any>

declare class PromisePool {
	constructor(opts: { concurrency: number })
	open: (task: PromisePoolTask) => Promise<any>
}