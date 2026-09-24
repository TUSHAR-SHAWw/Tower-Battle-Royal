extends Node

## Headless test runner.
##
##   & 'E:\GAMES\Godot_v4.7-stable_win64.exe' --headless --path <project> res://tests/TestRunner.tscn
##   (or: powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1)
##
## Why a report *file*: the Windows 4.7 binary is a GUI-subsystem executable, so
## its stdout is not attached to a console and the report would otherwise be
## invisible. The markdown report plus user://logs/godot.log are the source of
## truth (see docs/TOOLING.md).
##
## Exit codes: 0 = all green, 1 = failures, 2 = watchdog timeout, 3 = setup error.

const REPORT_DIR := "res://tests/results"
const REPORT_PATH := "res://tests/results/last_run.md"
## Safety net: a broken test must not hang an automated run forever.
const WATCHDOG_SECONDS := 120.0

## Suites run in this order. Add new suite scripts here.
const SUITE_PATHS: Array[String] = [
	"res://tests/foundation/signal_hub_test.gd",
	"res://tests/foundation/game_state_test.gd",
	"res://tests/foundation/scene_router_test.gd",
	"res://tests/foundation/input_actions_test.gd",
	"res://tests/foundation/math_utils_test.gd",
	"res://tests/foundation/object_pool_test.gd",
	"res://tests/foundation/damage_info_test.gd",
	"res://tests/foundation/state_machine_test.gd",
	"res://tests/player/player_test.gd",
]

var _suite_results: Array[Dictionary] = []
var _total_assertions: int = 0
var _total_failures: int = 0
var _timed_out: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	GameLog.info("Tests", "engine %s | %d suites" % [Engine.get_version_info().get("string", "?"), SUITE_PATHS.size()])
	var watchdog := Timer.new()
	watchdog.name = "Watchdog"
	watchdog.one_shot = true
	watchdog.wait_time = WATCHDOG_SECONDS
	watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(watchdog)
	watchdog.start()
	call_deferred(&"_run_all_suites")


func _on_watchdog_timeout() -> void:
	_timed_out = true
	GameLog.err("Tests", "watchdog fired after %.0fs — a suite is stuck." % WATCHDOG_SECONDS)
	_write_report(0)
	get_tree().quit(2)


func _run_all_suites() -> void:
	var started_at := Time.get_ticks_msec()

	for suite_path: String in SUITE_PATHS:
		var suite_script: GDScript = load(suite_path) as GDScript
		if suite_script == null:
			_suite_results.append({
				"path": suite_path, "name": "<load failed>", "assertions": 0,
				"failures": ["could not load suite script (parse error? see godot.log)"],
			})
			_total_failures += 1
			continue

		var suite := suite_script.new() as TestCase
		if suite == null:
			_suite_results.append({
				"path": suite_path, "name": "<not a TestCase>", "assertions": 0,
				"failures": ["suite script must extend TestCase"],
			})
			_total_failures += 1
			continue

		suite.name = suite_path.get_file().get_basename()
		add_child(suite)
		var suite_started := Time.get_ticks_msec()
		await suite.run_suite()
		var suite_ms := Time.get_ticks_msec() - suite_started

		_suite_results.append({
			"path": suite_path,
			"name": suite.suite_name(),
			"assertions": suite.assertion_count,
			"failures": suite.failures.duplicate(),
			"duration_ms": suite_ms,
		})
		_total_assertions += suite.assertion_count
		_total_failures += suite.failures.size()

		GameLog.info("Tests", "%s: %d assertions, %d failures (%d ms)" % [
			suite.suite_name(), suite.assertion_count, suite.failures.size(), suite_ms,
		])
		suite.queue_free()

	if _timed_out:
		return

	var elapsed_ms := Time.get_ticks_msec() - started_at
	_write_report(elapsed_ms)
	GameLog.info("Tests", "RESULT: %s | %d suites | %d assertions | %d failures | %d ms" % [
		"PASS" if _total_failures == 0 else "FAIL",
		_suite_results.size(), _total_assertions, _total_failures, elapsed_ms,
	])
	get_tree().quit(0 if _total_failures == 0 else 1)


func _write_report(elapsed_ms: int) -> void:
	var lines: Array[String] = []
	lines.append("# Tower Battle Royal — headless test report")
	lines.append("")
	lines.append("- Engine: Godot %s" % Engine.get_version_info().get("string", "?"))
	lines.append("- Run at: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("- Suites: %d" % _suite_results.size())
	lines.append("- Assertions: %d" % _total_assertions)
	lines.append("- Failures: %d" % _total_failures)
	lines.append("- Duration: %d ms" % elapsed_ms)
	lines.append("")
	lines.append("## Result: %s" % ("PASS" if _total_failures == 0 and not _timed_out else "FAIL"))
	lines.append("")
	lines.append("## Suites")
	lines.append("")
	lines.append("| Suite | Assertions | Failures | Duration |")
	lines.append("| --- | --- | --- | --- |")
	for result: Dictionary in _suite_results:
		lines.append("| %s | %d | %d | %d ms |" % [
			result.get("name", "?"), result.get("assertions", 0),
			(result.get("failures", []) as Array).size(), result.get("duration_ms", 0),
		])
	lines.append("")

	var any_failure := false
	for result: Dictionary in _suite_results:
		var suite_failures: Array = result.get("failures", [])
		if suite_failures.is_empty():
			continue
		any_failure = true
		lines.append("### %s" % result.get("name", "?"))
		lines.append("")
		for failure: Variant in suite_failures:
			lines.append("- %s" % failure)
		lines.append("")
	if not any_failure:
		lines.append("All assertions passed.")
		lines.append("")

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		GameLog.err("Tests", "could not write report to %s (error %d)" % [REPORT_PATH, FileAccess.get_open_error()])
		return
	file.store_string("\n".join(PackedStringArray(lines)))
	file.close()
	GameLog.info("Tests", "report written to %s" % ProjectSettings.globalize_path(REPORT_PATH))
