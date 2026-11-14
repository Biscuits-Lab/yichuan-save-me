extends Node

var players: Array[AudioStreamPlayer] = []
var kill_players: Array[AudioStreamPlayer] = []
var kill_voice: int = 0
var last_kill_time: int = -1000
var music: AudioStreamPlayer
var fading_music: AudioStreamPlayer
var music_transition: Tween
var music_style: String = ""
var samples: Dictionary = {}
const RATE: int = 22050
const MUSIC_VOLUME: float = -25.0
const FLOOR_MUSIC: Dictionary = {
	"office": preload("res://assets/audio/music/office.ogg"),
	"workshop": preload("res://assets/audio/music/workshop.ogg"),
	"server": preload("res://assets/audio/music/server.ogg"),
	"garden": preload("res://assets/audio/music/garden.ogg"),
	"wilds": preload("res://assets/audio/music/wilds.ogg"),
	"sumo": preload("res://assets/audio/music/sumo.ogg"),
	"castle": preload("res://assets/audio/music/castle.ogg")
}

func _ready() -> void:
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -16
		add_child(player)
		players.append(player)
	for i in range(3):
		var player := AudioStreamPlayer.new()
		player.volume_db = -6
		add_child(player)
		kill_players.append(player)
	var specs: Dictionary = {
		"jump": [360.0, 720.0, 0.12], "slash": [480.0, 90.0, 0.09],
		"dash": [180.0, 600.0, 0.12], "skill": [160.0, 950.0, 0.35],
		"hit": [180.0, 60.0, 0.10], "hurt": [240.0, 50.0, 0.22],
		"coffee": [523.0, 1046.0, 0.22], "block": [120.0, 130.0, 0.08],
		"repair": [440.0, 1320.0, 0.45], "start": [330.0, 880.0, 0.3],
		"select": [600.0, 700.0, 0.045], "dead": [330.0, 50.0, 0.6],
		"win": [523.0, 1569.0, 0.8]
	}
	for key in specs:
		var spec: Array = specs[key]
		samples[key] = tone(spec[0], spec[1], spec[2])
	samples["kill"] = kill_sample()
	samples["kill_boss"] = kill_sample(true)
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_VOLUME
	add_child(music)
	fading_music = AudioStreamPlayer.new()
	add_child(fading_music)
	music.stream = compose()
	if music_enabled():
		music.play()

func music_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not "--no-music" in OS.get_cmdline_user_args() and not "--no-audio" in OS.get_cmdline_user_args()

func play_floor_music(style: String) -> void:
	if style == music_style or not FLOOR_MUSIC.has(style):
		return
	music_style = style
	if music_transition:
		music_transition.kill()
	fading_music.stop()
	var previous: AudioStreamPlayer = music
	music = fading_music
	fading_music = previous
	music.stream = FLOOR_MUSIC[style]
	if not music_enabled():
		fading_music.stop()
		music.volume_db = MUSIC_VOLUME
		return
	music.volume_db = -60.0
	music.play()
	music_transition = create_tween().set_parallel()
	music_transition.tween_property(fading_music, "volume_db", -60.0, 0.45)
	music_transition.tween_property(music, "volume_db", MUSIC_VOLUME, 0.55)
	music_transition.chain().tween_callback(fading_music.stop)

func tone(start: float, finish: float, duration: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(RATE * duration) * 2)
	var phase: float = 0
	for i in range(data.size() / 2):
		var t: float = float(i) / RATE
		phase += lerpf(start, finish, t / duration) / RATE
		var wave: float = (1.0 if fmod(phase, 1.0) < 0.4 else -1.0) * (1.0 - t / duration) * minf(1.0, t * 150)
		data.encode_s16(i * 2, int(wave * 18000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func sfx(key: String) -> void:
	if DisplayServer.get_name() == "headless" or "--no-audio" in OS.get_cmdline_user_args():
		return
	if key in ["kill", "kill_boss"]:
		var now: int = Time.get_ticks_msec()
		if key == "kill" and now - last_kill_time < 25:
			return
		last_kill_time = now
		var player: AudioStreamPlayer = kill_players[kill_voice % kill_players.size()]
		kill_voice += 1
		player.stream = samples[key]
		player.pitch_scale = [1.0, 1.06, 0.96, 1.03][kill_voice % 4]
		player.play()
		return
	for player in players:
		if not player.playing:
			player.stream = samples.get(key)
			player.pitch_scale = 1.0
			player.play()
			return

func kill_sample(boss: bool = false) -> AudioStreamWAV:
	var duration: float = 0.25 if boss else 0.16
	var data := PackedByteArray()
	data.resize(int(RATE * duration) * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 701
	var previous_noise: float = 0
	for i in range(data.size() / 2):
		var t: float = float(i) / RATE
		var attack: float = minf(1.0, t / 0.0006)
		var phase: float = TAU * (95 * t + 145 * (1.0 - exp(-t * 65)) / 65)
		var pop: float = (sin(phase) * 0.85 + sin(phase * 2) * 0.12) * exp(-t * 48)
		var current_noise: float = noise.randf_range(-1, 1)
		var crack: float = (current_noise - previous_noise * 0.85) * exp(-t * 170) * 0.22
		previous_noise = current_noise
		var click: float = sin(TAU * 1900 * t) * exp(-t * 220) * 0.18
		var body: float = sin(TAU * 82 * t) * exp(-t * 32) * 0.22 if boss else 0.0
		var tail: float = clampf((duration - t) / 0.02, 0, 1)
		data.encode_s16(i * 2, int(tanh((pop + crack + click + body) * 1.8) * 0.88 * attack * tail * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func _exit_tree() -> void:
	if music_transition:
		music_transition.kill()
	for player in players + kill_players:
		player.stop()
		player.stream = null
	if music:
		music.stop()
		music.stream = null
	if fading_music:
		fading_music.stop()
		fading_music.stream = null
	samples.clear()

func compose() -> AudioStreamWAV:
	# Original 8-bit pentatonic loop. All audio is synthesized locally.
	var melody: Array[int] = [76, 0, 79, 81, 79, 0, 74, 0, 72, 0, 74, 76, 74, 0, 67, 0, 69, 0, 72, 74, 76, 0, 79, 76, 74, 0, 72, 69, 67, 0, 69, 0]
	var bass: Array[int] = [45, 45, 41, 41, 48, 48, 43, 43]
	var step: float = 0.21
	var duration: float = step * melody.size()
	var data := PackedByteArray()
	data.resize(int(RATE * duration) * 2)
	for i in range(data.size() / 2):
		var t: float = float(i) / RATE
		var index: int = mini(int(t / step), 31)
		var local_time: float = fmod(t, step)
		var envelope: float = minf(1.0, local_time * 180) * exp(-local_time * 11)
		var value: float = 0
		if melody[index] > 0:
			var freq: float = 440 * pow(2.0, (melody[index] - 69) / 12.0)
			value += (1.0 if fmod(t * freq, 1.0) < 0.25 else -0.35) * envelope * 0.32
		var bass_freq: float = 440 * pow(2.0, (bass[index / 4] - 69) / 12.0)
		value += (absf(fmod(t * bass_freq, 1.0) * 4 - 2) - 1) * 0.26
		if index % 4 == 0:
			value += sin(local_time * (95 - local_time * 140) * TAU) * exp(-local_time * 25) * 0.30
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 23000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = data.size() / 2
	return stream
