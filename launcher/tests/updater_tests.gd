extends SceneTree
## godot --headless --path launcher --script res://tests/updater_tests.gd   (exit 0 = pass)

const EXPECTED := 19
var passed := 0
var failed := 0


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("  FAIL  ", what)


func _init() -> void:
	check(Updater.safe_path("LoZ.exe"), "a plain file name is safe")
	check(Updater.safe_path("data/maps.pck"), "a subfolder is safe")
	check(not Updater.safe_path("../evil.exe"), "parent folders are refused")
	check(not Updater.safe_path("C:/Windows/evil.exe"), "drive paths are refused")
	check(not Updater.safe_path("/etc/evil"), "absolute paths are refused")
	check(not Updater.safe_path("a//b"), "empty path parts are refused")

	var dir := ProjectSettings.globalize_path("user://updater_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var fa := FileAccess.open(dir.path_join("LoZ.exe"), FileAccess.WRITE)
	fa.store_string("game")
	fa = null
	var sha := FileAccess.get_sha256(dir.path_join("LoZ.exe"))
	var good := {"version": "1.0", "base_url": "https://example.com/v1.0/", "launch": "LoZ.exe",
		"files": [{"path": "LoZ.exe", "asset": "LoZ.exe", "size": 4, "sha256": sha},
			{"path": "LoZ.pck", "asset": "LoZ.pck", "size": 9, "sha256": "0".repeat(64)}]}
	check(Updater.validate(good) == "", "a good manifest passes")
	check(Updater.validate({"version": "1", "base_url": "http://x/", "launch": "a", "files": good["files"]}) != "", "plain http is refused")
	var bad: Dictionary = good.duplicate(true)
	bad["files"][0]["path"] = "../x"
	check(Updater.validate(bad) != "", "a manifest with an escaping path is refused")
	check(Updater.validate([]) != "", "a non-object manifest is refused")

	var need := Updater.needed(good, dir)
	check(need.size() == 1 and str(need[0]["path"]) == "LoZ.pck", "only the missing file is downloaded")
	good["files"][0]["sha256"] = "f".repeat(64)
	check(Updater.needed(good, dir).size() == 2, "a changed file is downloaded again")
	check(Updater.asset_url(good, {"asset": "a b.pck"}) == "https://example.com/v1.0/a%20b.pck", "asset urls are encoded")

	Updater.write_installed(dir, "1.0")
	check(Updater.installed_version(dir) == "1.0", "the installed version is remembered")
	DirAccess.remove_absolute(dir.path_join("LoZ.exe"))
	DirAccess.remove_absolute(dir.path_join(Updater.INSTALLED_FILE))
	check(Updater.installed_version(dir) == "", "no installed file means no version")

	check(Updater.plain_notes("## What's new\n\n- Added a sprite.\n- Fixed sorting.") == "What's new\n\n• Added a sprite.\n• Fixed sorting.", "Markdown headings and bullets become plain lines")
	check(Updater.plain_notes("a".repeat(50), 10) == "aaaaaaaaaa...", "long notes are cut")
	check(Updater.plain_notes("") == "", "no notes stays empty")
	var odd: Dictionary = good.duplicate(true)
	odd["notes"] = 5
	check(Updater.validate(odd) != "", "notes that are not text are refused")

	if passed + failed != EXPECTED:
		print("  FAIL  ran %d assertions, expected %d" % [passed + failed, EXPECTED])
		failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
