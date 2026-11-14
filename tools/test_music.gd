extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var audio = game.audio
	var enabled: bool = audio.music_enabled()
	check(audio.music_style.is_empty() and audio.music.stream is AudioStreamWAV, "Title keeps its original music")
	check(audio.FLOOR_MUSIC.size() == game.Data.FLOOR_COUNT, "Every campaign floor has a score")
	var hashes: Dictionary = {}
	for floor_number in range(game.Data.FLOOR_COUNT):
		game.floor_index = floor_number
		game.generate_floor()
		var style: String = game.Data.FLOOR_STYLES[floor_number]
		var stream: AudioStreamOggVorbis = audio.music.stream
		check(audio.music_style == style and stream == audio.FLOOR_MUSIC[style], "Generated floor selects its matching score: " + style)
		check(stream.loop and stream.get_length() >= 27.0 and stream.get_length() <= 38.0, "Score has a full looping arrangement: " + style)
		hashes[FileAccess.get_sha256(stream.resource_path)] = true
		var player: AudioStreamPlayer = audio.music
		audio.play_floor_music(style)
		game.enter_room(1)
		check(audio.music == player and audio.music.stream == stream, "Same floor and room traversal do not restart the score: " + style)
		if enabled:
			await create_timer(0.65).timeout
			check(audio.music.playing and not audio.fading_music.playing and is_equal_approx(audio.music.volume_db, audio.MUSIC_VOLUME), "Crossfade leaves only the destination score playing: " + style)
		else:
			check(not audio.music.playing and not audio.fading_music.playing, "Silent launch options remain silent: " + style)
	check(hashes.size() == game.Data.FLOOR_COUNT, "All seven scores contain different audio")
	# Switch before the previous transition finishes, including back to a prior floor.
	for style in ["office", "sumo", "server", "wilds", "sumo"]:
		audio.play_floor_music(style)
	if enabled:
		await create_timer(0.65).timeout
	check(audio.music_style == "sumo" and audio.music.stream == audio.FLOOR_MUSIC.sumo, "Rapid switches settle on the latest requested score")
	check(not audio.fading_music.playing and audio.music.playing == enabled, "Rapid switches never leave an old score playing")
	var current: AudioStream = audio.music.stream
	audio.play_floor_music("unknown")
	check(audio.music.stream == current, "Unknown style cannot interrupt current music")
	game.start_run(20261114, true)
	check(audio.music_style == "office", "Restart returns from later floors to the office score")
	for floor_number in range(game.Data.FLOOR_COUNT - 1):
		for room in game.rooms:
			room.cleared = true
			room.skill_claimed = true
		game.enemies.clear()
		game.state = "loading"
		var boss_id: int = -1
		for room in game.rooms:
			if room.type == "boss":
				boss_id = room.id
		game.enter_room(boss_id)
		check(game.next_floor() and audio.music_style == game.Data.FLOOR_STYLES[floor_number + 1], "Real floor progression switches the music: %d" % (floor_number + 1))
		game.state = "playing"
	game.start_run(20261114, true)
	check(audio.music_style == "office", "A new run always restores first-floor music")
	# Let the queued startup effects finish before tearing down the audio mixer.
	await create_timer(0.4).timeout
	if enabled:
		await create_timer(0.65).timeout
		var position: float = audio.music.get_playback_position()
		game._unhandled_input(key_event(KEY_M))
		check(game.muted and AudioServer.is_bus_mute(0), "M mutes the score through the existing master bus")
		await create_timer(0.1).timeout
		game._unhandled_input(key_event(KEY_M))
		check(not game.muted and not AudioServer.is_bus_mute(0) and audio.music.get_playback_position() > position, "Unmuting preserves music playback position")
		# Seek across the actual decoder loop boundary instead of waiting half a minute.
		audio.music.seek(audio.music.stream.get_length() - 0.12)
		await create_timer(0.35).timeout
		check(audio.music.playing and audio.music.get_playback_position() < 1.0, "Ogg playback wraps at the loop boundary without stopping")
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("MUSIC RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
