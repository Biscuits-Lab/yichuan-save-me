extends Node
## Shared device detection, focus navigation and dual-motor feedback for both modes.

const PLAYSTATION := {"A":"×", "B":"○", "X":"□", "Y":"△", "LB":"L1", "RB":"R1", "LT":"L2", "RT":"R2", "Start":"Options", "Back":"Share"}
const NINTENDO := {"A":"B", "B":"A", "X":"Y", "Y":"X", "LB":"L", "RB":"R", "LT":"ZL", "RT":"ZR", "Start":"+", "Back":"−"}
const RUMBLE := {
	"dash": [0, Vector3(0.37, 0.12, 0.075)],
	"skill": [1, Vector3(0.42, 0.24, 0.10), Vector3(0.14, 0.34, 0.12)],
	"windup": [1, Vector3(0.16, 0.03, 0.10), Vector3(0.0, 0.0, 0.065), Vector3(0.24, 0.06, 0.085)],
	"charge": [2, Vector3(0.34, 0.20, 0.09), Vector3(0.13, 0.43, 0.16)],
	"volley": [2, Vector3(0.42, 0.08, 0.065), Vector3(0.0, 0.0, 0.045), Vector3(0.31, 0.13, 0.075)],
	"summon": [2, Vector3(0.11, 0.21, 0.12), Vector3(0.0, 0.0, 0.06), Vector3(0.28, 0.26, 0.14)],
	"kill": [3, Vector3(0.52, 0.36, 0.11)],
	"laser": [4, Vector3(0.62, 0.27, 0.08), Vector3(0.31, 0.48, 0.23)],
	"slam": [4, Vector3(0.50, 0.74, 0.085), Vector3(0.11, 0.40, 0.17)],
	"hurt": [4, Vector3(0.52, 0.46, 0.10), Vector3(0.12, 0.23, 0.085)],
	"phase": [5, Vector3(0.17, 0.34, 0.15), Vector3(0.0, 0.0, 0.08), Vector3(0.39, 0.56, 0.23)],
	"victory": [6, Vector3(0.36, 0.49, 0.15), Vector3(0.0, 0.0, 0.08), Vector3(0.54, 0.33, 0.22)],
	"death": [7, Vector3(0.72, 0.94, 0.16), Vector3(0.18, 0.50, 0.20), Vector3(0.0, 0.0, 0.09), Vector3(0.08, 0.23, 0.26)]
}

var active: bool = false
var device: int = -1
var labels: Dictionary = {}
var focus_context: String = ""
var focus_rect := Rect2()
var menu_stick := Vector2.ZERO
var stick_latched: bool = false
var rumble_pattern: Array = []
var rumble_index: int = 0
var rumble_gain: float = 1.0
var rumble_until: int = 0

func _ready() -> void:
	Input.joy_connection_changed.connect(connection_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		select_device(devices[0])

func _exit_tree() -> void:
	stop_rumble()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop_rumble()

func select_device(id: int) -> void:
	if id != device:
		stop_rumble()
		device = id
		menu_stick = Vector2.ZERO
		stick_latched = false
		var name_lower: String = Input.get_joy_name(id).to_lower()
		if ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"].any(func(name: String) -> bool: return name in name_lower):
			labels = PLAYSTATION.duplicate()
			if "dualsense" in name_lower or "ps5" in name_lower:
				labels["Back"] = "Create"
		elif ["nintendo", "switch", "joy-con"].any(func(name: String) -> bool: return name in name_lower):
			labels = NINTENDO
		else:
			labels = {}
	active = true

func connection_changed(id: int, connected: bool) -> void:
	if connected:
		if not active:
			select_device(id)
	elif id == device:
		stop_rumble()
		device = -1
		var devices := Input.get_connected_joypads()
		if active and not devices.is_empty():
			select_device(devices[0])
		else:
			active = false

func observe(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		select_device(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.36:
		select_device(event.device)
	elif active and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length_squared() >= 9.0)):
		active = false
		menu_stick = Vector2.ZERO
		stick_latched = false
		stop_rumble()

func key(button: String, desktop: String = "") -> String:
	return labels.get(button, button) if active else desktop

func text(desktop: String, controller: String) -> String:
	if not active:
		return desktop
	for button in labels:
		controller = controller.replace("{%s}" % button, labels[button])
	return controller.replace("{", "").replace("}", "")

func bind_button(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	bind_event(action, event)

func bind_axis(action: String, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	bind_event(action, event)

func bind_event(action: String, event: InputEvent) -> void:
	event.device = -1
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.26)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func menu_direction(event: InputEvent) -> Vector2:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: return Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: return Vector2.RIGHT
			JOY_BUTTON_DPAD_UP: return Vector2.UP
			JOY_BUTTON_DPAD_DOWN: return Vector2.DOWN
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		menu_stick[event.axis] = event.axis_value
		if menu_stick.length() < 0.30:
			stick_latched = false
		elif not stick_latched and menu_stick.length() >= 0.57:
			stick_latched = true
			if absf(menu_stick.x) >= absf(menu_stick.y):
				return Vector2(signf(menu_stick.x), 0)
			return Vector2(0, signf(menu_stick.y))
	return Vector2.ZERO

func focused(entries: Array[Dictionary], context: String) -> Dictionary:
	if entries.is_empty():
		return {}
	if focus_context == context:
		for entry in entries:
			if entry.rect == focus_rect:
				return entry
	focus_context = context
	var first: Dictionary = entries[0]
	for entry in entries:
		if entry.get("primary", false):
			first = entry
			break
	focus_rect = first.rect
	return first

func move_focus(entries: Array[Dictionary], context: String, direction: Vector2) -> void:
	var current: Dictionary = focused(entries, context)
	if current.is_empty():
		return
	var origin: Vector2 = focus_rect.get_center()
	var best_score: float = INF
	for entry in entries:
		var offset: Vector2 = entry.rect.get_center() - origin
		var advance: float = offset.dot(direction)
		if advance <= 4.0:
			continue
		var score: float = advance + 2.5 * absf(offset.cross(direction))
		if score < best_score:
			best_score = score
			focus_rect = entry.rect

func pulse(kind: String, gain: float = 1.0) -> void:
	if not active or device < 0:
		return
	var pattern: Array = RUMBLE[kind]
	if not rumble_pattern.is_empty() and pattern[0] <= rumble_pattern[0]:
		return
	rumble_pattern = pattern
	rumble_index = 1
	rumble_gain = clampf(gain, 0.0, 1.0)
	advance_rumble(Time.get_ticks_msec())

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not rumble_pattern.is_empty() and now >= rumble_until:
		advance_rumble(now)

func advance_rumble(now: int) -> void:
	if rumble_index >= rumble_pattern.size():
		stop_rumble()
		return
	var segment: Vector3 = rumble_pattern[rumble_index]
	rumble_index += 1
	rumble_until = now + roundi(segment.z * 1000.0)
	send_motors(segment.x * rumble_gain, segment.y * rumble_gain, segment.z)

func stop_rumble() -> void:
	if not rumble_pattern.is_empty():
		send_motors(0.0, 0.0, 0.0)
	rumble_pattern = []

func stop_combat_rumble() -> void:
	# A kill pulse can finish while the room-clear reward opens.
	if not rumble_pattern.is_empty() and rumble_pattern[0] < RUMBLE.phase[0] and rumble_pattern != RUMBLE.kill:
		stop_rumble()

func send_motors(weak: float, strong: float, seconds: float) -> void:
	if device not in Input.get_connected_joypads():
		return
	if weak > 0.0 or strong > 0.0:
		Input.start_joy_vibration(device, weak, strong, seconds)
	else:
		Input.stop_joy_vibration(device)
