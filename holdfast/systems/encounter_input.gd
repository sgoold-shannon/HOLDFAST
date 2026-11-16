extends RefCounted
## Main-scene input priority. Each adapter reports consumption, including modal blocking.
const ORDER := ["ending","return","roster","story","results","rescue","protocol","breaker","civilian","tactical"]
static func dispatch(event: InputEvent, handlers: Dictionary) -> bool:
	for layer in ORDER:
		if handlers[layer].call(event): return true
	return false
