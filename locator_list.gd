extends RefCounted
class_name GodoteerLocatorList

const GodoteerLocator = preload("locator.gd")

var screen: Object
var query: Dictionary
var description := "locator_list"


func _init(screen_instance: Object, locator_query: Dictionary, label: String = "locator_list") -> void:
	screen = screen_instance
	query = locator_query
	description = label


func count() -> int:
	return screen.resolve_query_nodes(query).size()


func is_empty() -> bool:
	return count() == 0


func all() -> Array:
	var nodes: Array = screen.resolve_query_nodes(query)
	var locators: Array = []
	for index in range(nodes.size()):
		locators.append(GodoteerLocator.new(screen, {
			"kind": "target",
			"value": nodes[index],
		}, "%s[%d]" % [description, index]))
	return locators


func nth(index: int) -> GodoteerLocator:
	return GodoteerLocator.new(screen, {
		"kind": "collection_position",
		"query": query,
		"mode": "nth",
		"index": index,
		"label": "%s.nth(%d)" % [description, index],
	}, "%s.nth(%d)" % [description, index])


func first() -> GodoteerLocator:
	return GodoteerLocator.new(screen, {
		"kind": "collection_position",
		"query": query,
		"mode": "first",
		"label": "%s.first()" % description,
	}, "%s.first()" % description)


func last() -> GodoteerLocator:
	return GodoteerLocator.new(screen, {
		"kind": "collection_position",
		"query": query,
		"mode": "last",
		"label": "%s.last()" % description,
	}, "%s.last()" % description)


func to_have_count(expected: int, timeout_sec: float = 2.0) -> bool:
	screen.trace_event("wait_started", {
		"message": "Waiting for locator list count on %s" % description,
		"wait_kind": "locator_list.to_have_count",
		"expected_count": expected,
		"timeout_sec": timeout_sec,
	})
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var actual := count()
		if actual == expected:
			screen.trace_event("wait_finished", {
				"message": "Locator list count matched on %s" % description,
				"wait_kind": "locator_list.to_have_count",
				"expected_count": expected,
				"actual_count": actual,
			})
			return true
		await screen.wait_frames(1)

	screen.trace_event("wait_timed_out", {
		"message": "Locator list count timed out on %s" % description,
		"wait_kind": "locator_list.to_have_count",
		"expected_count": expected,
		"actual_count": count(),
	})
	screen.record_failure("Timed out waiting for %s to have count %d actual=%d" % [description, expected, count()])
	return false


func to_be_empty(timeout_sec: float = 2.0) -> bool:
	screen.trace_event("wait_started", {
		"message": "Waiting for locator list to become empty on %s" % description,
		"wait_kind": "locator_list.to_be_empty",
		"timeout_sec": timeout_sec,
	})
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if is_empty():
			screen.trace_event("wait_finished", {
				"message": "Locator list became empty on %s" % description,
				"wait_kind": "locator_list.to_be_empty",
			})
			return true
		await screen.wait_frames(1)

	screen.trace_event("wait_timed_out", {
		"message": "Locator list did not become empty on %s" % description,
		"wait_kind": "locator_list.to_be_empty",
		"actual_count": count(),
	})
	screen.record_failure("Timed out waiting for %s to become empty actual=%d" % [description, count()])
	return false
