class_name SoundLibrary
extends Resource

## Maps *logical* sound keys to streams, so no gameplay script ever references an
## asset path and placeholder sounds can be swapped without code changes.
##
## Nothing references this resource yet: it exists (empty) so that gameplay code
## can already call `AudioManager.play_sfx(&"gunshot")` and start making noise the
## day real audio is added (see docs/ARCHITECTURE.md, "Audio").

## Key -> AudioStream. Examples: &"ui_click", &"gunshot", &"floor_warning".
@export var streams: Dictionary[StringName, AudioStream] = {}
## Optional per-key volume trim in dB (0.0 = unchanged).
@export var volume_trim_db: Dictionary[StringName, float] = {}


func has_sound(key: StringName) -> bool:
	return streams.has(key) and streams[key] != null


func get_stream(key: StringName) -> AudioStream:
	return streams.get(key) as AudioStream


func get_volume_trim(key: StringName) -> float:
	return float(volume_trim_db.get(key, 0.0))


func sound_keys() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in streams.keys():
		result.append(StringName(key))
	return result
