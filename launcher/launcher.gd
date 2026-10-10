extends Control
## Checks the latest release, downloads any game files that changed, then starts the game.

const MANIFEST_URL := "https://github.com/Apothim/LozClient/releases/latest/download/manifest.json"

var http: HTTPRequest
var status: Label
var bar: ProgressBar
var play: Button
var notes_box: ScrollContainer
var notes: Label
var install_dir := ""
var manifest := {}
var queue: Array = []
var current := {}


func _ready() -> void:
	# Next to launcher.exe in a build; in the editor, the launcher's user folder.
	install_dir = ProjectSettings.globalize_path("user://game") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir().path_join("game")
	DirAccess.make_dir_recursive_absolute(install_dir)
	build_ui()
	http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	check()


func build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 24)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "LoZ Launcher"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 22
	box.add_child(bar)
	notes_box = ScrollContainer.new()
	notes_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_box.custom_minimum_size.y = 120
	notes_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_box.visible = false
	box.add_child(notes_box)
	notes = Label.new()
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_box.add_child(notes)
	play = Button.new()
	play.text = "Play"
	play.disabled = true
	play.custom_minimum_size = Vector2(160, 44)
	play.pressed.connect(launch)
	box.add_child(play)


func _process(_delta: float) -> void:
	if not current.is_empty() and http.get_body_size() > 0:
		bar.value = 100.0 * http.get_downloaded_bytes() / http.get_body_size()


func check() -> void:
	status.text = "Checking for updates..."
	http.download_file = ""
	http.request_completed.connect(on_manifest, CONNECT_ONE_SHOT)
	if http.request(MANIFEST_URL) != OK:
		offline("Couldn't reach the update server.")


func on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		offline("Couldn't check for updates (error %d / HTTP %d)." % [result, code])
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var problem := Updater.validate(data)
	if not problem.is_empty():
		offline("The update information is broken: " + problem)
		return
	manifest = data
	var text := Updater.plain_notes(str(manifest.get("notes", "")))
	# Notes that already start with their own heading (as the publish script's notes do) aren't given a second one.
	var has_heading := str(manifest.get("notes", "")).strip_edges().begins_with("#")
	notes.text = text if has_heading or text.is_empty() else "What's new in %s\n\n%s" % [manifest["version"], text]
	notes_box.visible = not text.is_empty()
	queue = Updater.needed(manifest, install_dir)
	if queue.is_empty():
		ready_to_play("Up to date (version %s)." % manifest["version"])
	else:
		next_download()


func next_download() -> void:
	if queue.is_empty():
		Updater.write_installed(install_dir, str(manifest["version"]))
		ready_to_play("Updated to version %s." % manifest["version"])
		return
	current = queue.pop_front()
	var target := install_dir.path_join(str(current["path"]))
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	status.text = "Downloading %s (%s)..." % [current["path"], String.humanize_size(int(current.get("size", 0)))]
	bar.value = 0
	http.download_file = target + ".part"
	http.request_completed.connect(on_file, CONNECT_ONE_SHOT)
	if http.request(Updater.asset_url(manifest, current)) != OK:
		offline("Couldn't start downloading %s." % current["path"])


func on_file(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var target := install_dir.path_join(str(current["path"]))
	var part := target + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		offline("Download of %s failed (error %d / HTTP %d)." % [current["path"], result, code])
		return
	# The file must be exactly what the release says, or it is thrown away.
	if FileAccess.get_sha256(part) != str(current["sha256"]).to_lower():
		DirAccess.remove_absolute(part)
		offline("%s didn't match the release's checksum; it was not installed." % current["path"])
		return
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
		DirAccess.remove_absolute(part)
		offline("Couldn't replace %s. Is the game still running?" % current["path"])
		return
	DirAccess.rename_absolute(part, target)
	current = {}
	next_download()


## No update, but an installed game can still be played.
func offline(why: String) -> void:
	current = {}
	var exe := game_exe()
	if not exe.is_empty() and FileAccess.file_exists(exe):
		ready_to_play(why + " You can still play the installed version, but the server may ask you to update.")
	else:
		status.text = why + " The game isn't installed yet; try again later."


func ready_to_play(text: String) -> void:
	status.text = text
	bar.value = 100
	play.disabled = game_exe().is_empty()


## The game to start: the manifest's, or what the last successful update installed.
func game_exe() -> String:
	var launch := str(manifest.get("launch", "LoZ.exe"))
	return install_dir.path_join(launch) if Updater.safe_path(launch) else ""


func launch() -> void:
	var exe := game_exe()
	if OS.create_process(exe, []) == -1:
		status.text = "Couldn't start %s." % exe
		return
	get_tree().quit()
