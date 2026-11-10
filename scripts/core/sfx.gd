extends Node
## Sonidos y musica. Los wav estan en assets/sfx y se pueden reemplazar.

var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	apply_volume()

var _current_track := ""

func play_music(track: String) -> void:
	## track: "menu" o "game" (assets/sfx/music_<track>.ogg)
	if track == _current_track and music.playing: return
	_current_track = track
	var path := "res://assets/sfx/music_%s.ogg" % track
	if not ResourceLoader.exists(path): return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	music.stream = st
	apply_volume()
	if float(Game.settings.get("music", 0.7)) > 0.01:
		music.play()

func _load(name: String) -> AudioStream:
	if _streams.has(name): return _streams[name]
	var path := "res://assets/sfx/%s.wav" % name
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = st
	return st

func apply_volume() -> void:
	var mv := float(Game.settings.get("music", 0.7))
	music.volume_db = linear_to_db(maxf(mv, 0.001) * 0.55)
	if mv <= 0.01:
		music.stop()
	elif not music.playing and music.stream:
		music.play()

func play(name: String) -> void:
	var v := float(Game.settings.get("sfx", 0.9))
	if v <= 0.01: return
	var st := _load(name)
	if st == null: return
	for p in _players:
		if not p.playing:
			p.stream = st
			p.volume_db = linear_to_db(v)
			p.play()
			return

func vibrate(ms := 30) -> void:
	if Game.settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
