extends "res://addons/godoteer/test_scene.gd"

const COLLECTION_PROBE := preload("res://scenes/collection_probe.tscn")


func test_live_collection_locators(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(COLLECTION_PROBE)
	var status := screen.get_by_node_name("StatusLabel")
	var choices := screen.get_all_by_role("button", {"name": "Choice"})
	var choice_scope := screen.within(screen.get_by_node_name("ChoiceList"))
	var texts := screen.get_all_by_text("Echo")
	var labels := screen.get_all_by_node_name("ValueLabel")
	var form := screen.within(screen.get_by_node_name("FormList"))
	var by_label := form.get_all_by_label_text("Item Name")
	var by_placeholder := form.get_all_by_placeholder_text("Type item")

	expect(choices.count() == 2, "Repeated buttons should count as two", choices.count())
	expect(not choices.is_empty(), "Repeated buttons should not be empty")
	await choices.to_have_count(2)
	await choices.first().click()
	await status.to_have_text("Choice 1")
	await choices.last().click()
	await status.to_have_text("Choice 2")
	await choices.nth(1).click()
	await status.to_have_text("Choice 2")

	expect(choice_scope.get_all_by_role("button", {"name": "Choice"}).count() == 2, "Scoped role collection should stay inside choice list")
	expect(texts.count() == 3, "Repeated text query should count three labels", texts.count())
	expect(labels.count() == 3, "Node-name collection query should count three matching nodes", labels.count())
	expect(by_label.count() == 2, "Label-text collection query should count two inputs", by_label.count())
	expect(by_placeholder.count() == 2, "Placeholder collection query should count two inputs", by_placeholder.count())

	var text_locators := texts.all()
	expect(text_locators.size() == 3, "all() should return raw iterable locator array", text_locators.size())
	expect(text_locators[0].text() == "Echo", "all() locators should resolve text", text_locators[0].text())
	expect(text_locators[2].text() == "Echo", "all() should preserve later matches", text_locators[2].text())


func test_live_collection_waits_and_empty_queries(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(COLLECTION_PROBE)
	drain_failures()
	var missing := screen.query_all_by_text("Missing")

	expect(missing.is_empty(), "query_all_by_text should return empty live collection for zero matches")
	await missing.to_be_empty()
	expect(drain_failures().is_empty(), "Empty query collection should not record failure")

	var delayed_live := screen.query_all_by_role("button", {"name": "Delayed Choice"})
	var delayed_found := await screen.find_all_by_role("button", {"name": "Delayed Choice"})
	await delayed_live.to_have_count(3)
	await delayed_found.to_have_count(3)
	expect(delayed_live.count() == 3, "Live collection should see delayed nodes without rebuild", delayed_live.count())
	await delayed_found.first().click()
	await screen.get_by_node_name("StatusLabel").to_have_text("Delayed 1")


func test_out_of_range_collection_locator_records_clear_failure(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(COLLECTION_PROBE)
	var choices := screen.get_all_by_role("button", {"name": "Choice"})

	drain_failures()
	set_failures_quiet(true)
	await choices.nth(9).click()
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(failures.size() == 1, "Out-of-range nth click should record one failure", failures)
	expect(str(failures[0]).contains("index 9 out of range"), "Out-of-range failure should explain missing index", failures)
	expect(str(failures[0]).contains("current_count=2"), "Out-of-range failure should include current count", failures)
