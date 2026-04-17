extends Node2D

@export var radius: float = 400.0
@export var thickness: float = 6.0

@export var option_font: Font
@export var option_selected_font: Font
@export var label_padding: float = 45.0 
@export var font_size: int = 40

var segments = 4

var selected_segment = -1

var options = [
	{
		"label": "Play",
		"tooltip": "Start the game and choose your mode!",
		"children": [
			{"label": "File", "tooltip": "Supply your own WAV file."},
			{
				"label": "Demo",
				"tooltip": "Play the built-in track.",
				"children": [
					{"label": "Chill", "tooltip": "Low Density, Long Telegraphs, Infinite Lives."},
					{"label": "Normal", "tooltip": "Standard obstacle settings (recommended)"},
					{"label": "Hard", "tooltip": "For players seeking a challenge."},
					{"label": "Back", "tooltip": "Return to input selection."},
				],
			},
			{
				"label": "System Audio",
				"tooltip": "Dynamically generate the level based on system audio.",
				"children": [
					{"label": "Chill", "tooltip": "Low Density, Long Telegraphs, Infinite Lives."},
					{"label": "Normal", "tooltip": "Standard obstacle settings (recommended)"},
					{"label": "Hard", "tooltip": "For players seeking a challenge."},
					{"label": "Back", "tooltip": "Return to input selection."},
				],
			},
			{"label": "Back", "tooltip": "Return to main menu."},
		],
	},
	{
		"label": "Settings",
		"tooltip": "Configure color, VFX, accessibility, and more.",
		"children": [
			{
				"label": "Colour Palette",
				"tooltip": "Switch UI and VFX color themes.",
					"children": [
						{"label": "Cyber", "tooltip": "Bright, pink/blue Tron-inspired." },
						{"label": "Ink", "tooltip": "Classic ink-on-paper duotone." },
						{"label": "Monochrome", "tooltip": "High-contrast for visibility." },
						{"label": "Warmth", "tooltip": "Orange/red energized theme." },
						{"label": "Back", "tooltip": "Return to settings." },
					],
			},
			{
				"label": "Visual Effects",
				"tooltip": "Adjust or disable background effects.",
				"children": [
					{"label": "Particles", "tooltip": "Toggle particle VFX" },
					{"label": "Camera FX", "tooltip": "Toggle camera pulse and movement" },
					{"label": "Shockwave", "tooltip": "Toggle background shockwave on the beat" },
					{"label": "Spectrum Line", "tooltip": "Toggle background spectrum line" },
					{"label": "Back", "tooltip": "Return to settings." },
				],
			},
			{
				"label": "Accessibility",
				"tooltip": "Make visuals and gameplay easier to see or experience.",
				"children": [
					{"label": "Reduced Motion", "tooltip": "Turn off/minimize moving backgrounds and effects." },
					{"label": "High Contrast", "tooltip": "Increase contrast for danger/telegraphs." },
					{"label": "Colourblind Mode", "tooltip": "Use alternative color palette for clarity." },
					{"label": "Back", "tooltip": "Return to settings." },
				],
			},
			{
				"label": "Window Mode",
				"tooltip": "Make visuals and gameplay easier to see or experience.",
				"children": [
					{"label": "Fullscreen", "tooltip": "Enable Circle Seige running in Full-Screen mode (default)." },
					{"label": "Windowed", "tooltip": "Enable Circle Seige running in windowed mode." },
					{"label": "Exclusive Fullscreen", "tooltip": "True fullscreen mode. Improves performance, but makes multi-tasking harder." },
					{"label": "Back", "tooltip": "Return to settings." },
				],
			},
			{"label": "Back", "tooltip": "Return to main menu."},
		]
	},
	{"label": "Credits/Help", "tooltip": "Learn about the game."},
	{"label": "Quit", "tooltip": "Exit the game."},
]

var stack = [options]

var render_options = options

var sector_size = TAU / segments
var angle_offset = -PI / 2.0 - (sector_size / 2.0)

@onready var player = $"../Player"
@onready var file_sel = $"../FileDialog"
@onready var main = $".."
@onready var camera = $"../Camera2D"

var audio_path = ""

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	
	if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept"):
		if selected_segment == -1:
			return
		camera.trigger_select()
		if render_options[selected_segment].has("children"):
			if render_options[selected_segment]["label"] == "Demo":
				audio_path = ProjectSettings.globalize_path("res://demo.wav")
			render_options = render_options[selected_segment]["children"]
			segments = render_options.size()
			sector_size = TAU / segments
			angle_offset = -PI / 2.0 - (sector_size / 2.0)
			selected_segment = -1
			stack.append(render_options)
			queue_redraw()
		else:
			match render_options[selected_segment]["label"]:
				"Back":
					stack.pop_back()
					render_options = stack[-1]
					segments = render_options.size()
					sector_size = TAU / segments
					angle_offset = -PI / 2.0 - (sector_size / 2.0)
					selected_segment = -1
					queue_redraw()
				"Quit": get_tree().quit()
				"File":
					stack.pop_back()
					stack.append(render_options)
					file_sel.show()
				"Normal": main.start(audio_path)
				"Particles": Config.particles = !Config.particles
				"Camera FX": Config.camera_fx = !Config.camera_fx
				"Shockwave": Config.shockwave = !Config.shockwave
				"Spectrum Line": Config.spectrum_line = !Config.spectrum_line
				"Reduced Motion": Config.reduced_motion = !Config.reduced_motion
				"Fullscreen":
					Config.window_mode = Config.WindowModes.FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				"Windowed":
					Config.window_mode = Config.WindowModes.WINDOWED
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					var window_size = Vector2i(1280, 720)
					DisplayServer.window_set_size(window_size)
					var screen_size = DisplayServer.screen_get_size()
					DisplayServer.window_set_position((screen_size - window_size) / 2)
				"Exclusive Fullscreen":
					Config.window_mode = Config.WindowModes.EXCLUSIVE_FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				"Cyber", "Ink", "Monochrome", "Warmth":
					Config.cur_palette = render_options[selected_segment]["label"].to_lower()
					if !Config.contrast and !Config.colourblind:
						Config.colours = Config.palettes[Config.cur_palette]
						main.update_colours()
				"High Contrast":
					if Config.contrast:
						Config.contrast = false
						Config.colours = Config.palettes[Config.cur_palette]
						main.update_colours()
					else:
						Config.contrast = true
						Config.colourblind = false
						Config.colours = Config.palettes["high_contrast"]
						main.update_colours()

func _on_file_selected(path: String) -> void:
	audio_path = path
	render_options = [
		{"label": "Chill", "tooltip": "Low Density, Long Telegraphs, Infinite Lives."},
		{"label": "Normal", "tooltip": "Standard obstacle settings (recommended)"},
		{"label": "Hard", "tooltip": "For players seeking a challenge."},
		{"label": "Back", "tooltip": "Return to input selection."},
	]
	stack.append(render_options)

func _process(_delta: float) -> void:
	queue_redraw()

func get_status(option: Dictionary) -> Array:
	match option.label:
		"Particles": 
			if Config.particles:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Camera FX":
			if Config.camera_fx:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Shockwave":
			if Config.shockwave:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Spectrum Line":
			if Config.spectrum_line:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Reduced Motion":
			if Config.reduced_motion:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Fullscreen":
			if Config.window_mode == Config.WindowModes.FULLSCREEN:
				return ["[ SELECTED ]", Color(0.3,0.7,1.0,1)]
			else:
				return ["", Color(1.0,1.0,1.0,0)]
		"Windowed":
			if Config.window_mode == Config.WindowModes.WINDOWED:
				return ["[ SELECTED ]", Color(0.3,0.7,1.0,1)]
			else:
				return ["", Color(1.0,1.0,1.0,0)]
		"Exclusive Fullscreen": 
			if Config.window_mode == Config.WindowModes.EXCLUSIVE_FULLSCREEN:
				return ["[ SELECTED ]", Color(0.3,0.7,1.0,1)]
			else:
				return ["", Color(1.0,1.0,1.0,0)]
		"Cyber", "Ink", "Monochrome", "Warmth":
			if Config.cur_palette == option["label"].to_lower():
				return ["[ SELECTED ]", Color(0.3,0.7,1.0,1)]
			else:
				return ["", Color(1.0,1.0,1.0,0)]
		"High Contrast":
			if Config.contrast:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		"Colourblind Mode":
			if Config.colourblind:
				return ["[ ON ]", Color(0.3,1,0.3,1)]
			else:
				return ["[ OFF ]", Color(1.0,0.3,0.3,1)]
		_:
			return ["", Color(1, 1, 1, 0)]

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0,0,0,0.2))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(0.9, 0.9, 1.0, 0.9), thickness, true)
	
	for i in range(segments):
		var a = angle_offset + i * sector_size
		var dir = Vector2(cos(a), sin(a))
		draw_line(Vector2.ZERO, dir * radius, Color(0.8, 0.8, 1.0, 0.6), 3.0)

	var local_pos = to_local(player.global_position)
	if local_pos.distance_squared_to(Vector2.ZERO) <= radius * radius:
		var angle = atan2(local_pos.y, local_pos.x)
		if angle < 0:
			angle += TAU

		var adjusted_angle = angle - angle_offset
		adjusted_angle = fposmod(adjusted_angle, TAU)
		selected_segment = int(adjusted_angle / sector_size)
		
		var start = angle_offset + selected_segment * sector_size
		var end = start + sector_size
		
		var pts = []
		pts.append(Vector2.ZERO)
		for i in range(49):
			var a = lerpf(start, end, float(i) / 48.0)
			pts.append(Vector2(cos(a), sin(a)) * radius)
		var sel_c = Config.colours["selection"]
		sel_c.a = 0.4
		var arc_c = Config.colours["selection"]
		arc_c.a = 0.8
		draw_colored_polygon(pts, sel_c)
		draw_arc(Vector2.ZERO, radius, start, end, 64, arc_c, 2.0)
	else:
		selected_segment = -1
	
	for i in range(render_options.size()):
		var a = angle_offset + (i + 0.5) * sector_size
		var dir = Vector2(cos(a), sin(a))

		var is_selected = (i == selected_segment)
		var col = Config.colours["tooltip"] if is_selected else Config.colours["menu"]
		var font = option_selected_font if is_selected && option_selected_font != null else option_font

		var label_text = render_options[i].label

		var label_text_size = font.get_string_size(label_text, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

		var dx = label_text_size.x / 2
		var dy = label_text_size.y / 2
		var corners = [
			Vector2(-dx, -dy),
			Vector2(dx, -dy),
			Vector2(dx, dy),
			Vector2(-dx, dy)
		]

		var anchor_offset = 0.0
		for c in corners:
			anchor_offset = max(anchor_offset, c.dot(dir))
		var box_center_dist = radius - label_padding - anchor_offset
		var box_center = dir * box_center_dist
		var label_pos = box_center - Vector2(label_text_size.x / 2, label_text_size.y / 2)
		
		var ascent = font.get_ascent(font_size)
		draw_string(font, label_pos+Vector2(0, ascent), label_text, HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		
		var status = get_status(render_options[i])
		var status_text = status[0]
		var status_colour = status[1]
		if status_text != "":
			var status_font_size = int(font_size * 0.53)
			var status_font = option_font
			var status_size = status_font.get_string_size(status_text, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, status_font_size)
			var status_pos = label_pos + Vector2((dx - status_size.x/2), ascent + dy + 6)
			draw_string(status_font, status_pos, status_text, HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT, -1, status_font_size, status_colour)

	if selected_segment != -1:
		if selected_segment < render_options.size() and render_options[selected_segment].has("tooltip"):
			var message = render_options[selected_segment].tooltip
			var tooltip_font = option_font
			var tooltip_size = tooltip_font.get_string_size(message) if tooltip_font != null else Vector2(0,0)
			
			var ypos = radius + 72
			var tooltip_width = get_viewport_rect().size.x
			var c = Config.colours["tooltip"]
			c.a = 0.76
			draw_string(option_font, Vector2(-tooltip_width/2, ypos), message, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, tooltip_width, 26, c)
