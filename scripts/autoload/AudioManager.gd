extends Node

## Central audio hub (autoload name: `AudioManager`).
##
## Gameplay calls this with *logical keys* (`play_sfx(&"gunshot")`); it never
## knows what a gun is. Streams come from a SoundLibrary resource, so audio can be
## replaced without touching gameplay (docs/ARCHITECTURE.md, "Audio").
##
## The player nodes are created in code because autoloads have no editable scene;
## keeping them here avoids shipping an .tscn that only exists to hold three nodes.

const DEFAULT_LIBRARY_PATH := "res://resources/audio/sound_library.tres"
## PROTOTYPE DEFAULT — maximum simultaneous positional sounds. Tune after profiling.
const POSITIONAL_VOICE_COUNT := 12

enum Channel { MUSIC, SFX, UI }

var library: SoundLibrary = null

var master_volume_db: float = 0.0
var music_volume_db: float = -8.0
var sfx_volume_db: float = -6.0
var ui_volume_db: float = -6.0
var music_enabled: bool = true
var sfx_enabled: bool = true

var _music_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _positional_players: Array[AudioStreamPlayer2D] = []
var _next_positional_voice: int = 0
var _warned_missing_library: bool = false
var _music_tween: Tween


func _ready() -> void:
	_build_players()
	_load_library(DEFAULT_LIBRARY_PATH)


# ------------------------------------------------------------------------ public

func set_library(new_library: SoundLibrary) -> void:
	library = new_library


func play_music(key: StringName) -> void:
	var stream := _stream(key)
	if stream == null or not music_enabled:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = music_volume_db
	_music_player.play()


## Fades the music out and stops it. `duration` of 0 stops immediately.
func stop_music(duration: float = 0.4) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if duration <= 0.0 or not _music_player.playing:
		_music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, duration)
	_music_tween.tween_callback(_music_player.stop)


func play_ui(key: StringName) -> void:
	_play_on(_ui_player, key, ui_volume_db)


func play_sfx(key: StringName) -> void:
	_play_on(_ui_player, key, sfx_volume_db)


## Plays a key at a world position (falls back to a normal SFX if the pool is full).
func play_at(key: StringName, world_position: Vector2) -> void:
	var stream := _stream(key)
	if stream == null or not sfx_enabled:
		return
	if _positional_players.is_empty():
		play_sfx(key)
		return
	var voice := _positional_players[_next_positional_voice]
	_next_positional_voice = (_next_positional_voice + 1) % _positional_players.size()
	voice.stream = stream
	voice.global_position = world_position
	voice.volume_db = sfx_volume_db + library.get_volume_trim(key)
	voice.play()


func set_channel_volume_db(channel: Channel, volume_db: float) -> void:
	match channel:
		Channel.MUSIC:
			music_volume_db = volume_db
			_music_player.volume_db = volume_db
		Channel.SFX:
			sfx_volume_db = volume_db
		Channel.UI:
			ui_volume_db = volume_db


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		_music_player.stop()
	elif _music_player.stream != null:
		_music_player.play()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled


func is_silent() -> bool:
	return library == null or library.sound_keys().is_empty()


# ----------------------------------------------------------------------- private

func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	add_child(_ui_player)

	for i: int in POSITIONAL_VOICE_COUNT:
		var voice := AudioStreamPlayer2D.new()
		voice.name = "PositionalVoice%d" % i
		voice.max_distance = 2000.0
		add_child(voice)
		_positional_players.append(voice)


func _load_library(path: String) -> void:
	if not ResourceLoader.exists(path):
		# Silence is a valid state: gameplay must work before audio exists.
		return
	library = load(path) as SoundLibrary


func _play_on(player: AudioStreamPlayer, key: StringName, volume_db: float) -> void:
	var stream := _stream(key)
	if stream == null or not sfx_enabled:
		return
	player.stream = stream
	player.volume_db = volume_db + library.get_volume_trim(key)
	player.play()


func _stream(key: StringName) -> AudioStream:
	if library == null:
		if not _warned_missing_library:
			_warned_missing_library = true
			push_warning("AudioManager: no SoundLibrary loaded (%s); audio calls are silent." % DEFAULT_LIBRARY_PATH)
		return null
	return library.get_stream(key)
