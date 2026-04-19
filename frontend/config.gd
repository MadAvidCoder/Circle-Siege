extends Node

enum WindowModes {
	FULLSCREEN,
	WINDOWED,
	EXCLUSIVE_FULLSCREEN,
}

var palettes = {
	"cyber": {
		"bg_dark": Color("#0a080f"),
		"bg_light": Color("#d4c7ff"),
		"player": Color("#d91219"),
		"player_inactive": Color("340202ff"),
		"player_invulnerable": Color("ffabaaff"),
		"obstacles": Color("#d9a0d4"),
		"beat_obstacle": Color("#fe7b31"),
		"shockwave": Color("dd9400"),
		"spectrum": Color("50a9f0"),
		"near_miss": Color("fff2b3"),
		"telegraph_chord": Color("e633ff"),
		"telegraph_radial": Color("ff8033"),
		"selection": Color("33ff33"),
		"tooltip": Color("4dffcc"),
		"menu": Color("#d7edfa"),
	},
	"ink": {
		"bg_dark": Color("bca971ff"),
		"bg_light": Color("fffde8"),
		"player": Color("1d2731"),
		"player_inactive": Color("#3f3626"),
		"player_invulnerable": Color("fff9c1ff"),
		"obstacles": Color("5a7081"),
		"beat_obstacle": Color("a45b65"),
		"shockwave": Color("5a7081"),
		"spectrum": Color("66938aff"),
		"near_miss": Color("554100ff"),
		"telegraph_chord": Color("8d6c5b"),
		"telegraph_radial": Color("1d2731"),
		"selection": Color("#a14529"),
		"tooltip": Color("3f3626ff"),
		"menu": Color("#1d2731"),
	},
	"monochrome": {
		"bg_dark": Color("2b2d2f"),
		"bg_light": Color("e3e3e3"),
		"player": Color("000000"),
		"player_inactive": Color("#3b3b3b"),
		"player_invulnerable": Color("#faffb8"),
		"obstacles": Color("dc8e88ff"),
		"beat_obstacle": Color("c0392b"),
		"shockwave": Color("bcbcbc"),
		"spectrum": Color("7f7f7f"),
		"near_miss": Color("faffb8"),
		"telegraph_chord": Color("565656"),
		"telegraph_radial": Color("cc402e"),
		"selection": Color("00a8ff"),
		"tooltip": Color("d0ece7"),
		"menu": Color("1a1a1e"),
	},
	"warmth": {
		"bg_dark": Color("58391c"),
		"bg_light": Color("feb47b"),
		"player": Color("fae0ae"),
		"player_inactive": Color("#58391c"),
		"player_invulnerable": Color("c17a00"),
		"obstacles": Color("ff805e"),
		"beat_obstacle": Color("dbcaa2"),
		"shockwave": Color("ffe382"),
		"spectrum": Color("e29a21"),
		"near_miss": Color("fffdf5"),
		"telegraph_chord": Color("f38181"),
		"telegraph_radial": Color("e86509"),
		"selection": Color("c7f464"),
		"tooltip": Color("fff6d3"),
		"menu": Color("#ffeed0"),
	},
	"high_contrast": {
		"bg_dark": Color("#000000"),
		"bg_light": Color("#262626"),
		"player": Color("#ffffff"),
		"player_inactive": Color("#4c4c4c"),
		"player_invulnerable": Color("609fffff"),
		"obstacles": Color("#ffff00"),
		"beat_obstacle": Color("#00ffff"),
		"shockwave": Color("#ff00ff"),
		"spectrum": Color("#00ff00"),
		"near_miss": Color("ffb400ff"),
		"telegraph_chord": Color("#ffffff"),
		"telegraph_radial": Color("#ff0000"),
		"selection": Color("#ffffff"),
		"menu": Color("#ffffff"),
		"tooltip": Color("#ffff00"),
	},
	"colourblind": {
		"bg_dark": Color("1b4266ff"),
		"bg_light": Color("#e1efe6"),
		"player": Color("449c4fff"),
		"player_inactive": Color("03293aff"),
		"player_invulnerable": Color("#fafffc"),
		"obstacles": Color("#d08419"),
		"beat_obstacle": Color("#be39a2"),
		"shockwave": Color("#3cbcc3"),
		"spectrum": Color("#f6d846"),
		"near_miss": Color("#efe676"),
		"telegraph_chord": Color("#106eb5"),
		"telegraph_radial": Color("#ce5c5c"),
		"selection": Color("#693fb6"),
		"menu": Color("#fafffc"),
		"menu_selected": Color("#3cbcc3"),
		"tooltip": Color("#fafffc"),
	},
}

var cur_palette: String = "cyber"
var colours: Dictionary = palettes[cur_palette]

var particles: bool = true
var camera_fx: bool = true
var shockwave: bool = true
var spectrum_line: bool = true
var reduced_motion: bool = false
var colourblind: bool = false
var contrast: bool = false
var window_mode: WindowModes = WindowModes.FULLSCREEN

func _ready() -> void:
	match window_mode:
		WindowModes.WINDOWED:
			Config.window_mode = Config.WindowModes.WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var window_size = Vector2i(1280, 720)
			DisplayServer.window_set_size(window_size)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_position((screen_size - window_size) / 2)
		WindowModes.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WindowModes.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
