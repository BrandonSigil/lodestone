extends Node
## Sound (autoload "Sfx"): the Music and SFX buses, their volumes (Options), one-shot sounds and mood music.
## Every sound is a placeholder made in code (2026-11-13 playtest: the game had no audio at all). A real file wins:
## drop `res://audio/sfx/<name>.ogg` or `res://audio/music/<mood>.ogg` in and it plays instead, no code change.
## Sfx.play("hit"), Sfx.music("village"). Buttons click on their own (every Button added to the tree).

const RATE := 22050
const SOUNDS := ["click", "hover", "open", "close", "confirm", "error", "hit", "crit", "miss", "down", "hurt", "step_turn",
	"pickup", "coin", "levelup", "victory", "defeat", "door", "hint", "stone", "camp", "move"]
const MOODS := ["menu", "village", "wild", "road", "fight", "boss"]
const MUSIC_DB := -9.0  ## the music sits under the sounds
const FADE := 1.2  ## seconds to cross from one mood to the next

var _cache := {}  ## name -> AudioStream
var _music_cache := {}  ## mood -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _mood := ""
var _pending := {}  ## mood -> Thread making it
var _last_play := {}  ## name -> msec, so a burst of the same sound doesn't stack into noise


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = _music_player()
	_music_b = _music_player()
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	set_process(false)


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


## The Options volumes (0..1) onto the buses. Called at start and after a change.
func apply_volumes() -> void:
	var st: Dictionary = get_node("/root/Game").meta.get("settings", {}) if has_node("/root/Game") else {}
	_set_bus("Music", float(st.get("music_volume", 0.7)))
	_set_bus("SFX", float(st.get("sfx_volume", 0.8)))


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## The mood music of an explore map: the village and its houses, else the wild (the pass, the den, the crypt).
static func map_mood(map_name: String) -> String:
	if map_name in ["village", "village_v2", "home", "tavern"] or map_name.begins_with("house"):
		return "village"
	return "wild"


## One sound. pitch_jitter: a small random pitch change so repeats don't sound copied.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.04) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -1000)) < 40:
		return
	_last_play[sound] = now
	var s := _stream(sound)
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


## Mood music: crossfades to the mood's loop ("" fades out). Made on a thread the first time, so a scene change
## never hitches.
func music(mood: String) -> void:
	if mood == _mood or DisplayServer.get_name() == "headless":
		return
	_mood = mood
	if mood == "":
		_fade_to(null)
		return
	var file := "res://audio/music/%s.ogg" % mood
	if ResourceLoader.exists(file):
		_fade_to(load(file) as AudioStream)
	elif _music_cache.has(mood):
		_fade_to(_music_cache[mood])
	elif not _pending.has(mood):
		var th := Thread.new()
		_pending[mood] = th
		th.start(func() -> AudioStream: return SfxSynth.music(mood, RATE))
	set_process(true)


func _process(_delta: float) -> void:
	for mood: String in _pending.keys():
		var th: Thread = _pending[mood]
		if th.is_alive():
			continue
		var s: AudioStream = th.wait_to_finish()
		_pending.erase(mood)
		_music_cache[mood] = s
		if mood == _mood:
			_fade_to(s)
	if _pending.is_empty():
		set_process(false)


func _fade_to(s: AudioStream) -> void:
	var old := _music_a if _music_a.playing and _music_a.volume_db > -70.0 else _music_b
	var new := _music_b if old == _music_a else _music_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.tween_callback(old.stop)
	if s != null:
		new.stream = s
		new.volume_db = -40.0
		new.play()
		create_tween().tween_property(new, "volume_db", MUSIC_DB, FADE)


func _stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var file := "res://audio/sfx/%s.ogg" % sound
	var s: AudioStream = load(file) as AudioStream if ResourceLoader.exists(file) else SfxSynth.sound(sound, RATE)
	_cache[sound] = s
	return s


## Every button clicks; the round X closes with its own sound. Hover is a faint tick.
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("quiet"):
		var b := n as BaseButton
		b.pressed.connect(func() -> void: play("close" if (b is Button and (b as Button).text == "X") else "click", -4.0))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				play("hover", -16.0, 0.02))


func _exit_tree() -> void:
	for th: Thread in _pending.values():
		th.wait_to_finish()
