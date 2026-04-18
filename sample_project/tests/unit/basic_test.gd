extends "res://addons/godoteer/test.gd"


func test_expect_passes_without_recording_failure() -> void:
	expect([1, 2, 3].size() == 3, "Array length should stay stable")
	expect(drain_failures().is_empty(), "expect(true) should not record failures")


func test_expect_uses_default_message() -> void:
	set_failures_quiet(true)
	expect(false)
	set_failures_quiet(false)

	var failures := drain_failures()
	expect(failures.size() == 1, "Expected one failure entry", failures)
	expect(failures[0] == "Expectation failed", "Unexpected default failure message", failures)


func test_expect_includes_variadic_details() -> void:
	set_failures_quiet(true)
	expect(false, "expected=", [1, 2], "actual=", [1, 2, 3])
	set_failures_quiet(false)

	var failures := drain_failures()
	expect(failures.size() == 1, "Expected one detailed failure", failures)
	expect(
		failures[0] == "Expectation failed: expected= [1, 2] actual= [1, 2, 3]",
		"Unexpected variadic failure message",
		failures
	)
