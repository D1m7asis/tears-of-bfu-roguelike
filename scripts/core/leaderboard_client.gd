extends RefCounted
class_name LeaderboardClient

const SettingsStoreLib = preload("res://scripts/core/settings_store.gd")
const LOCAL_LEADERBOARD_PATH := "user://leaderboard_local.json"
const MAX_ENTRIES: int = 200


static func fetch_leaderboard(host: Node, limit: int = 15) -> Dictionary:
	var api_url := SettingsStoreLib.get_leaderboard_api_url().strip_edges()
	if not _should_use_http(api_url):
		return _fetch_local_leaderboard(limit)
	if api_url == "":
		return {"ok": false, "error": "Адрес API рейтинга пуст.", "entries": []}

	var separator := "?" if api_url.find("?") == -1 else "&"
	var request_url := "%s%saction=list&limit=%d" % [api_url, separator, max(1, limit)]
	return await _request_json(host, request_url, HTTPClient.METHOD_GET, "")


static func submit_run(host: Node, summary: Dictionary, mode: String = "endless") -> Dictionary:
	var api_url := SettingsStoreLib.get_leaderboard_api_url().strip_edges()
	if summary.is_empty():
		return {"ok": false, "error": "Сводка забега пуста."}

	var payload := {
		"player_name": SettingsStoreLib.get_player_name(),
		"score": max(0, int(summary.get("score", 0))),
		"kills": max(0, int(summary.get("kills", 0))),
		"basement": max(1, int(summary.get("basement", 1))),
		"time_seconds": max(0, int(summary.get("time_seconds", 0))),
		"mode": mode,
	}
	if not _should_use_http(api_url):
		return _submit_local_run(payload)
	if api_url == "":
		return {"ok": false, "error": "Адрес API рейтинга пуст."}

	return await _request_json(
		host,
		api_url,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload),
		["Content-Type: application/json", "Accept: application/json"]
	)


static func _request_json(host: Node, url: String, method: HTTPClient.Method, body: String, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	if host == null:
		return {"ok": false, "error": "Узел для HTTP-запроса не найден."}
	if headers.is_empty():
		headers = PackedStringArray(["Accept: application/json"])

	var http := HTTPRequest.new()
	host.add_child(http)
	var request_error := http.request(url, headers, method, body)
	if request_error != OK:
		http.queue_free()
		return {"ok": false, "error": "Не удалось запустить запрос (%d)." % [request_error]}

	var result: Array = await http.request_completed
	http.queue_free()

	if result.size() < 4:
		return {"ok": false, "error": "Неполный HTTP-ответ."}

	var response_code: int = int(result[1])
	var response_body: String = ""
	if result[3] is PackedByteArray:
		response_body = (result[3] as PackedByteArray).get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": "Ошибка HTTP %d" % [response_code],
			"body": response_body,
		}

	if response_body.strip_edges() == "":
		return {"ok": true, "data": {}, "entries": []}

	var parsed: Variant = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Некорректный JSON-ответ.", "body": response_body}

	var data := parsed as Dictionary
	if data.get("ok", true) == false:
		return {
			"ok": false,
			"error": str(data.get("error", "Неизвестная ошибка рейтинга.")),
			"data": data,
			"entries": data.get("entries", []),
		}

	return {
		"ok": true,
		"data": data,
		"entries": data.get("entries", []),
		"message": str(data.get("message", "")),
	}


static func _should_use_http(api_url: String) -> bool:
	if api_url.begins_with("http://") or api_url.begins_with("https://"):
		return true
	return OS.has_feature("web") and api_url != ""


static func _fetch_local_leaderboard(limit: int) -> Dictionary:
	var payload := _load_local_payload()
	var entries: Array = payload.get("entries", [])
	var sorted_entries := _sort_and_trim_entries(entries, max(1, limit))
	return {
		"ok": true,
		"entries": sorted_entries,
		"message": "Локальный рейтинг загружен.",
		"source": "local",
	}


static func _submit_local_run(entry: Dictionary) -> Dictionary:
	var payload := _load_local_payload()
	var entries: Array = payload.get("entries", [])
	var stored_entry := entry.duplicate(true)
	stored_entry["created_at"] = Time.get_datetime_string_from_system(false, true)
	entries.append(stored_entry)
	payload["entries"] = _sort_and_trim_entries(entries, MAX_ENTRIES)
	_save_local_payload(payload)
	return {
		"ok": true,
		"entries": payload["entries"],
		"message": "Результат сохранён в локальный рейтинг.",
		"source": "local",
	}


static func _load_local_payload() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_LEADERBOARD_PATH):
		return {"entries": []}
	var file := FileAccess.open(LOCAL_LEADERBOARD_PATH, FileAccess.READ)
	if file == null:
		return {"entries": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"entries": []}
	return parsed as Dictionary


static func _save_local_payload(payload: Dictionary) -> void:
	var file := FileAccess.open(LOCAL_LEADERBOARD_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))


static func _sort_and_trim_entries(entries: Array, limit: int) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(entry_variant)
	result.sort_custom(Callable(LeaderboardClient, "_compare_entries"))
	if result.size() > limit:
		result.resize(limit)
	return result


static func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b

	var basement_a := int(a.get("basement", 1))
	var basement_b := int(b.get("basement", 1))
	if basement_a != basement_b:
		return basement_a > basement_b

	var kills_a := int(a.get("kills", 0))
	var kills_b := int(b.get("kills", 0))
	if kills_a != kills_b:
		return kills_a > kills_b

	var time_a := int(a.get("time_seconds", 0))
	var time_b := int(b.get("time_seconds", 0))
	return time_a > time_b
