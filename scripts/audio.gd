extends Node

var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var samples: Dictionary = {}
const RATE: int = 22050

func _ready() -> void:
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -16
		add_child(player)
		players.append(player)
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
	music = AudioStreamPlayer.new()
	music.volume_db = -25
	add_child(music)
	music.stream = compose()
	if DisplayServer.get_name() != "headless" and not "--no-music" in OS.get_cmdline_user_args() and not "--no-audio" in OS.get_cmdline_user_args():
		music.play()

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
	for player in players:
		if not player.playing:
			player.stream = samples.get(key)
			player.play()
			return

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
	if music:
		music.stop()
		music.stream = null
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
