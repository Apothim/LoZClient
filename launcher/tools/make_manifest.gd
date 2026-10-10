extends SceneTree
## Writes manifest.json for a release from a folder of exported game files.
## godot --headless --path launcher --script res://tools/make_manifest.gd -- <build folder> <version> [launch exe]
## Upload every file in the folder (including manifest.json) to the GitHub release tagged v<version>.

const REPO := "https://github.com/Apothim/LozClient"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <build folder> <version> [launch exe]")
		quit(1)
		return
	var dir := str(args[0]).replace("\\", "/")
	var version := str(args[1])
	var launch := str(args[2]) if args.size() > 2 else "LoZ.exe"
	var files: Array = []
	collect(dir, "", files)
	var manifest := {"version": version, "base_url": "%s/releases/download/v%s/" % [REPO, version],
		"launch": launch, "files": files}
	var problem := Updater.validate(manifest)
	if not problem.is_empty():
		printerr(problem)
		quit(1)
		return
	var fa := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(manifest, "\t"))
	print("wrote %s with %d files" % [dir.path_join("manifest.json"), files.size()])
	quit(0)


## GitHub release assets are a flat list, so a file in a subfolder is uploaded as "sub.name".
func collect(root: String, rel: String, out: Array) -> void:
	var d := DirAccess.open(root.path_join(rel))
	for name in d.get_files():
		var path := rel.path_join(name) if not rel.is_empty() else name
		if path == "manifest.json" or name.ends_with(".part"):
			continue
		var full := root.path_join(path)
		var fa := FileAccess.open(full, FileAccess.READ)
		out.append({"path": path, "asset": path.replace("/", "."), "size": fa.get_length(), "sha256": FileAccess.get_sha256(full)})
	for sub in d.get_directories():
		collect(root, rel.path_join(sub) if not rel.is_empty() else sub, out)
