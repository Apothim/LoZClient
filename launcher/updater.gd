class_name Updater
extends RefCounted
## The launcher's bookkeeping, kept free of nodes and networking so it can be tested headlessly.
## A release publishes manifest.json beside its files:
## {"version": "0.1.0", "base_url": "https://.../download/v0.1.0/", "launch": "LoZ.exe",
##  "files": [{"path": "LoZ.exe", "asset": "LoZ.exe", "size": 123, "sha256": "..."}]}

const INSTALLED_FILE := "installed.json"


## Whether `path` stays inside the install folder: relative, no "..", no drive or leading slash.
## The manifest comes from the network, so a bad path must never write elsewhere on the PC.
static func safe_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.begins_with("\\") or path.contains(":"):
		return false
	for part in path.replace("\\", "/").split("/"):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


## "" when the manifest is usable, otherwise what is wrong with it.
static func validate(manifest) -> String:
	if not (manifest is Dictionary):
		return "manifest is not an object"
	if str(manifest.get("version", "")).is_empty():
		return "manifest has no version"
	if not str(manifest.get("base_url", "")).begins_with("https://"):
		return "manifest base_url must be https"
	var files = manifest.get("files")
	if not (files is Array) or (files as Array).is_empty():
		return "manifest lists no files"
	for f in files:
		if not (f is Dictionary) or not safe_path(str(f.get("path", ""))) or str(f.get("asset", "")).is_empty() \
				or str(f.get("sha256", "")).length() != 64:
			return "manifest has a bad file entry: %s" % str(f)
	if not safe_path(str(manifest.get("launch", ""))):
		return "manifest has a bad launch path"
	if manifest.has("notes") and not (manifest["notes"] is String):
		return "manifest notes must be text"
	return ""


## The release notes as plain text for a label: Markdown headings and bullets become simple lines, and a long
## note is cut so a bad manifest can't fill the window.
static func plain_notes(text: String, max_chars := 3000) -> String:
	var lines: PackedStringArray = []
	for raw in text.replace("\r", "").split("\n"):
		var line := raw.strip_edges(false, true)
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			line = stripped.lstrip("#").strip_edges()
		elif stripped.begins_with("- ") or stripped.begins_with("* "):
			line = "• " + stripped.substr(2)
		lines.append(line)
	var out := "\n".join(lines).strip_edges()
	return out if out.length() <= max_chars else out.left(max_chars).strip_edges() + "..."


## The manifest entries whose file in `dir` is missing or differs (by size, then sha256).
static func needed(manifest: Dictionary, dir: String) -> Array:
	var out: Array = []
	for f in manifest["files"]:
		var local := dir.path_join(str(f["path"]))
		if not FileAccess.file_exists(local):
			out.append(f)
			continue
		var fa := FileAccess.open(local, FileAccess.READ)
		var size := fa.get_length() if fa != null else -1
		fa = null
		if size != int(f.get("size", size)) or FileAccess.get_sha256(local) != str(f["sha256"]).to_lower():
			out.append(f)
	return out


static func asset_url(manifest: Dictionary, entry: Dictionary) -> String:
	var base := str(manifest["base_url"])
	if not base.ends_with("/"):
		base += "/"
	return base + str(entry["asset"]).uri_encode()


static func installed_version(dir: String) -> String:
	var text := FileAccess.get_file_as_string(dir.path_join(INSTALLED_FILE))
	var data = JSON.parse_string(text) if not text.is_empty() else null
	return str(data.get("version", "")) if data is Dictionary else ""


static func write_installed(dir: String, version: String) -> void:
	var fa := FileAccess.open(dir.path_join(INSTALLED_FILE), FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify({"version": version}))
