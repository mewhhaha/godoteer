extends "res://scripts/discovery_test_base.gd"


func test_mixed_dir_discovery_runs_only_real_suite() -> void:
	expect(helper_value() == "mixed-dir", "mixed dir helper base should stay usable")
