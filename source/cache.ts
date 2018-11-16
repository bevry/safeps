const cache: { [key: string]: string } = {}

export function set(key: string, value: string) {
	cache[key] = value
	return cache[key]
}

export function get(key: string) {
	return cache[key]
}
