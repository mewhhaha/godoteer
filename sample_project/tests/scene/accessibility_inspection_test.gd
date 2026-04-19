extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")


func _tree_find(snapshot: Dictionary, wanted_name: String) -> Dictionary:
	if str(snapshot.get("node_name", "")) == wanted_name:
		return snapshot

	for child in snapshot.get("children", []):
		var found := _tree_find(child, wanted_name)
		if not found.is_empty():
			return found

	return {}


func _paths_include_suffix(paths: Array, suffix: String) -> bool:
	for path in paths:
		if str(path).ends_with(suffix):
			return true
	return false


func test_relation_aware_accessibility_queries(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))

	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var name_by_label := form.get_by_label_text("Player Name")
	var name_by_description := form.get_by_role("textbox", {"description": "Type player name before starting"})
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms", "checked": false})
	var disabled_button := form.get_by_role("button", {"name": "Disabled Action", "disabled": true})
	var start_button := form.get_by_role("button", {"name": "Start", "disabled": false})

	expect(name_field.node() == name_by_label.node(), "Explicit labeled_by relation should drive label query")
	expect(name_field.node() == name_by_description.node(), "Explicit described_by relation should drive role description query")
	expect(terms_toggle.node() != null, "Checked=false role query should find unchecked checkbox")
	expect(disabled_button.node() != null, "Disabled role query should find disabled button")
	expect(start_button.node() != null, "Disabled=false role query should find enabled button")

	await name_field.to_have_accessibility_role("textbox")
	screen.expect_accessibility_role(name_field, "textbox")

	await terms_toggle.check()
	var checked_terms := form.get_by_role("checkbox", {"name": "Accept Terms", "checked": true})
	expect(checked_terms.node() == terms_toggle.node(), "Checked=true role query should find toggled checkbox")


func test_accessibility_snapshot_and_tree(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var start_button := form.get_by_role("button", {"name": "Start"})
	var status := form.get_by_node_name("StatusLabel")

	var has_element := screen.has_accessibility_element(name_field)
	expect(typeof(has_element) == TYPE_BOOL, "has_accessibility_element should return bool", has_element)
	screen.accessibility_rid(name_field)
	if DisplayServer.get_name() != "headless":
		expect(has_element, "Windowed accessibility support should expose at least one accessibility element")
		screen.expect_has_accessibility_element(name_field)

	var name_snapshot := screen.accessibility_snapshot(name_field)
	expect(name_snapshot.get("role", "") == "textbox", "Snapshot should report textbox role", name_snapshot)
	expect(name_snapshot.get("name", "") == "Player Name", "Snapshot should report relation-backed accessible name", name_snapshot)
	expect(name_snapshot.get("description", "") == "Type player name before starting", "Snapshot should report relation-backed description", name_snapshot)
	expect(name_snapshot.get("placeholder", "") == "Enter hero name", "Snapshot should report placeholder text", name_snapshot)
	expect(name_snapshot.get("disabled", true) == false, "Snapshot should report enabled text field", name_snapshot)
	expect(name_snapshot.get("checked", true) == null, "Snapshot should report null checked state for textbox", name_snapshot)
	expect(name_snapshot.get("live", -1) == 0, "Snapshot should report no live region mode for textbox", name_snapshot)
	expect(_paths_include_suffix(name_snapshot.get("labeled_by", []), "/NameLabel"), "Snapshot should include labeled_by relation path", name_snapshot)
	expect(_paths_include_suffix(name_snapshot.get("described_by", []), "/NameHelp"), "Snapshot should include described_by relation path", name_snapshot)
	expect(_paths_include_suffix(name_snapshot.get("flow_to", []), "/TermsToggle"), "Snapshot should include flow_to relation path", name_snapshot)

	var start_snapshot := screen.accessibility_snapshot(start_button)
	expect(start_snapshot.get("role", "") == "button", "Snapshot should report button role", start_snapshot)
	expect(_paths_include_suffix(start_snapshot.get("controls", []), "/StatusLabel"), "Snapshot should include controls relation path", start_snapshot)

	var status_snapshot := screen.accessibility_snapshot(status)
	expect(status_snapshot.get("live", 0) == 1, "Snapshot should expose live region mode", status_snapshot)

	var tree := screen.accessibility_tree()
	var name_tree := _tree_find(tree, "NameInput")
	var hidden_tree := _tree_find(tree, "HiddenMessage")
	expect(not name_tree.is_empty(), "Accessibility tree should include NameInput", tree)
	expect(hidden_tree.is_empty(), "Accessibility tree should exclude hidden nodes by default", tree)
	expect(_paths_include_suffix(name_tree.get("labeled_by", []), "/NameLabel"), "Tree should preserve labeled_by relation path", name_tree)
	expect(_paths_include_suffix(name_tree.get("described_by", []), "/NameHelp"), "Tree should preserve described_by relation path", name_tree)

	var tree_with_hidden := screen.accessibility_tree(null, {"include_hidden": true})
	var visible_hidden_tree := _tree_find(tree_with_hidden, "HiddenMessage")
	expect(not visible_hidden_tree.is_empty(), "Accessibility tree should include hidden nodes when requested", tree_with_hidden)
