class_name Verify extends Node2D

const SCRIPTS_DIR: String = "res://scripts/"
const SCENES_DIR: String = "res://scenes/"
const APOSTROPHE: String = "'"
# gdformat rewrites a string holding a double quote into single quotes, so it is a code point.
const DOUBLE_QUOTE: int = 34
const WARNING_PREFIX: String = "debug/gdscript/warnings/"
const WARNINGS: Array[String] = [
	"unassigned_variable",
	"unassigned_variable_op_assign",
	"unused_variable",
	"unused_local_constant",
	"unused_private_class_variable",
	"unused_parameter",
	"unused_signal",
	"shadowed_variable",
	"shadowed_variable_base_class",
	"shadowed_global_identifier",
	"unreachable_code",
	"unreachable_pattern",
	"standalone_expression",
	"standalone_ternary",
	"incompatible_ternary",
	"untyped_declaration",
	"inferred_declaration",
	"unsafe_property_access",
	"unsafe_method_access",
	"unsafe_cast",
	"unsafe_call_argument",
	"unsafe_void_return",
	"return_value_discarded",
	"static_called_on_instance",
	"missing_tool",
	"redundant_static_unload",
	"redundant_await",
	"missing_await",
	"assert_always_true",
	"assert_always_false",
	"integer_division",
	"narrowing_conversion",
	"int_as_enum_without_cast",
	"int_as_enum_without_match",
	"enum_variable_without_default",
	"empty_file",
	"deprecated_keyword",
	"confusable_identifier",
	"confusable_local_declaration",
	"confusable_local_usage",
	"confusable_capture_reassignment",
	"confusable_temporary_modification",
	"inference_on_variant",
	"native_method_override",
	"get_node_default_without_onready",
	"onready_with_export",
	"property_used_as_function",
	"constant_used_as_function",
	"function_used_as_property"
]

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	var sources: Dictionary = read_files(SCRIPTS_DIR, ".gd")
	check(sources.size() >= 10, "the verification project has scripts to check")

	verify_declarations(sources)
	verify_prohibited(sources)
	verify_scenes(read_files(SCENES_DIR, ".tscn"))
	verify_signal_emitters(sources)
	verify_layout(sources)
	verify_asserts(sources)
	verify_typing(sources)
	verify_node_access(sources)
	verify_compiles(sources)
	verify_state_machine()
	verify_buffers()
	verify_damage()
	verify_config_boundary()
	verify_setter()
	verify_preloads()
	verify_warning_settings()

	if failures > 0:
		printerr("FAILURES: " + str(failures) + " of " + str(checks) + " checks")
		get_tree().quit(1)
		return
	get_tree().quit(0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: " + label)


# Comments and string literals are removed before any token scan, so a word
# inside an assert message is never mistaken for code.
func strip_noise(text: String) -> String:
	var out: String = ""
	for line: String in text.split("\n"):
		var clean: String = ""
		var in_string: bool = false
		var index: int = 0
		while index < line.length():
			var character: String = line[index]
			if line.unicode_at(index) == DOUBLE_QUOTE:
				in_string = !in_string
			elif character == "#" and !in_string:
				break
			elif !in_string:
				clean += character
			index += 1
		out += clean + "\n"
	return out


func read_files(directory: String, extension: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(directory)
	assert(dir, "verify.gd - cannot open " + directory)
	for file_name: String in dir.get_files():
		if !file_name.ends_with(extension):
			continue
		var file: FileAccess = FileAccess.open(directory + file_name, FileAccess.READ)
		out[file_name] = file.get_as_text()
	return out


# --- 1. Declaration and file shape ------------------------------------------


func verify_declarations(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var text: String = sources[file_name]
		var first: String = text.split("\n")[0]

		if file_name == "global.gd":
			check(first == "extends Node", "autoload omits class_name: " + file_name)
			for line: String in text.split("\n"):
				check(!line.begins_with("class_name "), "autoload declares no class_name: " + file_name)
			continue

		check(first.begins_with("class_name "), "line 1 is a class_name declaration: " + file_name)
		check(first.contains(" extends "), "declaration is one line: " + file_name)

		var declared: String = first.split(" ")[1]
		var expected: String = ""
		for part: String in file_name.replace(".gd", "").split("_"):
			expected += part.substr(0, 1).to_upper() + part.substr(1)
		check(declared == expected, "class_name matches filename: " + file_name + " declared " + declared)


# --- 2. Prohibited constructs ------------------------------------------------


func verify_prohibited(sources: Dictionary) -> void:
	var untyped_math: RegEx = RegEx.create_from_string("(?<![\\w.])(max|min|clamp|lerp|abs|sign)\\(")
	# connect(func ...) is the lambda form; anything else after the paren is a method reference.
	var method_reference: RegEx = RegEx.create_from_string("\\.connect\\(\\s*(?!func\\b)\\S")
	for file_name: String in sources.keys():
		var raw: String = sources[file_name]
		var text: String = strip_noise(raw)
		check(!text.contains("@warning_ignore"), "no warning suppression: " + file_name)
		check(!text.contains("gdlint:ignore"), "no gdlint suppression: " + file_name)
		check(!text.contains("##"), "no doc-comments: " + file_name)
		check(!text.contains("Vector2i"), "no Vector2i: " + file_name)
		check(!text.contains("static func"), "no static functions: " + file_name)
		check(!text.contains("@tool"), "no tool scripts: " + file_name)
		check(!text.contains("@abstract"), "no abstract: " + file_name)
		check(!text.contains("@icon"), "no icon annotation: " + file_name)
		check(!text.contains("func _on_"), "no func _on_* names at all: " + file_name)
		for keyword: String in ["if not ", "and not ", "or not ", "while not ", "return not "]:
			check(!text.contains(keyword), "negation uses ! not the not keyword: " + file_name)
		check(!text.contains("class Inner"), "no inner classes: " + file_name)
		check(!text.contains("extends Resource"), "no custom Resource subclasses: " + file_name)
		check(
			method_reference.search(text) == null, "every connection is a lambda, not a method reference: " + file_name
		)
		check(untyped_math.search(text) == null, "typed math helpers, maxf and clampi not max and clamp: " + file_name)
		if text.contains("@export var"):
			check(text.contains("@export_category("), "exports are grouped under @export_category: " + file_name)

		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			check(!trimmed.begins_with("match "), "no match statements: " + file_name)
			check(!trimmed.begins_with("print("), "no print in committed code: " + file_name)
			check(!line.contains(":= "), "no inferred declarations: " + file_name)
			check(!trimmed.contains(APOSTROPHE), "double-quoted strings only: " + file_name)


# --- 2a. Scenes carry no wiring a script should own ----------------------------


func verify_scenes(scenes: Dictionary) -> void:
	check(scenes.size() >= 3, "the verification project has scenes to check")
	var quote: String = String.chr(DOUBLE_QUOTE)
	for file_name: String in scenes.keys():
		var text: String = scenes[file_name]
		check(!text.contains("[connection"), "no signal connection saved in a scene: " + file_name)
		check(!text.contains("type=" + quote + "Timer" + quote), "no scene-tree Timer node: " + file_name)


# --- 2b. Signals are emitted through a typed method ---------------------------


func verify_signal_emitters(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var raw: String = sources[file_name]
		var text: String = strip_noise(raw)

		var declared: Array[String] = []
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if !trimmed.begins_with("signal "):
				continue
			declared.append(trimmed.split(" ")[1].split("(")[0])

		for signal_name: String in declared:
			check(
				text.contains(signal_name + ".emit("),
				"signal " + signal_name + " is emitted in its own class: " + file_name
			)

		# A caller must never reach through a reference to emit.
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if !trimmed.contains(".emit("):
				continue
			var target: String = trimmed.split(".emit(")[0].strip_edges()
			check(
				!target.contains("."),
				"emit is called on a local signal, not through a reference: " + file_name + " " + trimmed
			)
			check(declared.has(target), "emit only names a signal this class declares: " + file_name + " " + trimmed)


# --- 3. Layout ---------------------------------------------------------------


func verify_layout(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var text: String = sources[file_name]
		var line_number: int = 0
		for line: String in text.split("\n"):
			line_number += 1
			check(line.length() <= 120, "line <= 120 chars: " + file_name + ":" + str(line_number))
			var indent: String = line.substr(0, line.length() - line.lstrip("\t").length())
			check(!line.begins_with(" "), "tabs not spaces: " + file_name + ":" + str(line_number))
			check(!indent.contains(" "), "no mixed indent: " + file_name + ":" + str(line_number))
			check(line == line.rstrip(" \t"), "no trailing whitespace: " + file_name + ":" + str(line_number))


# --- 4. Every export is asserted in _ready -----------------------------------


func verify_asserts(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var text: String = sources[file_name]
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if !trimmed.begins_with("@export var"):
				continue
			var export_type: String = trimmed.split(":")[1].strip_edges().split(" ")[0].split("=")[0]
			# Value exports (int, float, bool, String) carry a default and are not asserted.
			# Node and resource exports are, because a missing one is a silent null.
			if export_type in ["int", "float", "bool", "String", "StringName", "Vector2", "Color"]:
				continue
			var export_name: String = trimmed.split(" ")[2].split(":")[0]
			# gdformat wraps a long assert, so its condition can sit on the next line.
			var asserted: RegEx = RegEx.create_from_string("assert\\(\\s*!?" + export_name + "\\b")
			check(asserted.search(text) != null, "@export " + export_name + " is asserted in " + file_name)
			check(
				text.contains(file_name + " - @export " + export_name),
				"assert message names the file and export: " + file_name + " " + export_name
			)


# --- 5. Type annotations -----------------------------------------------------


func verify_typing(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var text: String = sources[file_name]
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("func "):
				check(trimmed.contains("->"), "function has a return type: " + file_name + " " + trimmed)
			if trimmed.begins_with("var ") or trimmed.begins_with("const "):
				check(trimmed.contains(":"), "declaration is typed: " + file_name + " " + trimmed)
			if trimmed.begins_with("for "):
				check(trimmed.contains(":"), "loop variable is typed: " + file_name + " " + trimmed)


# --- 6. Cross-scene access ---------------------------------------------------


func verify_node_access(sources: Dictionary) -> void:
	# %Name is a scene-unique path. Modulo in this style always carries spaces,
	# so a % glued to an identifier is a path, not arithmetic.
	var unique_name: RegEx = RegEx.create_from_string("%[A-Za-z_]")
	for file_name: String in sources.keys():
		var raw: String = sources[file_name]
		var text: String = strip_noise(raw)
		check(!text.contains("get_tree().get_root().get_node"), "no raw root grabs outside the autoload: " + file_name)
		check(
			!text.contains("owner.take_damage") and !text.contains("get_parent().take_damage"),
			"no method calls through a Node-typed reference: " + file_name
		)
		check(!text.contains("$"), "no $ scene paths: " + file_name)
		check(!unique_name.search(text), "no %UniqueName scene paths: " + file_name)
		check(!text.contains("get_node("), "no get_node calls: " + file_name)
		check(!text.contains("has_node("), "no has_node calls: " + file_name)
		check(!text.contains("find_child"), "no find_child or find_children calls: " + file_name)
		check(!text.contains("NodePath("), "no NodePath literals in a script: " + file_name)
		# get_children() picks nothing by position and stays allowed. get_child(i) is a
		# path with a number instead of a name.
		check(!text.contains("get_child("), "no get_child(i) index grabs: " + file_name)
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if !trimmed.begins_with("@onready"):
				continue
			check(
				!trimmed.contains("preload(") and (trimmed.contains(".new(") or trimmed.contains("[")),
				"@onready is a derived value, never a preload or a node grab: " + file_name + " " + trimmed
			)


# --- 6b. Every script compiles ------------------------------------------------


# A headless launch parses only the scripts the main scene reaches. Loading each one
# here covers the rest, with the autoload registered so a reference to it resolves.
func verify_compiles(sources: Dictionary) -> void:
	for file_name: String in sources.keys():
		var script: GDScript = load(SCRIPTS_DIR + file_name)
		check(script != null and script.can_instantiate(), "script compiles: " + file_name)


# --- 7. The state machine actually behaves -----------------------------------


func verify_state_machine() -> void:
	var player: Player = Global.player
	check(player != null, "the autoload holds the player reference")
	if !player:
		return

	check(Character.Direction.left == -1, "Direction.left is -1")
	check(Character.Direction.right == 1, "Direction.right is 1")

	player.force_state(Player.State.idle)
	player.set_state(Player.State.walk)
	check(player.c_state == Player.State.walk, "set_state moves out of a free state")

	player.force_state(Player.State.attack)
	player.set_state(Player.State.walk)
	check(player.c_state == Player.State.attack, "set_state refuses while a state is blocked")

	player.force_state(Player.State.idle)
	check(player.c_state == Player.State.idle, "force_state bypasses the block")

	for state: Player.State in Player.State.values():
		var anim_name: StringName = Player.State.keys()[state]
		check(player.animation.has_animation(anim_name), "every enum key has an animation: " + anim_name)


# --- 8. Buffers decay --------------------------------------------------------


func verify_buffers() -> void:
	var player: Player = Global.player
	if !player:
		return
	player.jump_buffer_time = 0.05
	player.knockback_buffer_time = 0.2
	player._physics_process(0.05)
	check(is_equal_approx(player.knockback_buffer_time, 0.15), "a buffer decays by delta in the physics tick")
	player._physics_process(0.2)
	check(player.jump_buffer_time == 0.0, "a buffer floors at zero, never goes negative")


# --- 9. Typed damage through the base class ----------------------------------


func verify_damage() -> void:
	var enemy: Enemy = Enemy.new()
	add_child(enemy)
	var before: int = enemy.health
	enemy.take_damage(10, Character.Direction.left)
	check(enemy.health == before - 10, "take_damage lands through the typed base class")
	check(enemy.knockback_buffer_time > 0, "take_damage sets the knockback buffer")
	enemy.queue_free()


# --- 10. The config boundary --------------------------------------------------


func verify_config_boundary() -> void:
	var card: UpgradeCard = UpgradeCard.new()
	var title: Label = Label.new()
	var description: Label = Label.new()
	card.add_child(title)
	card.add_child(description)
	card.title = title
	card.description = description
	add_child(card)

	card.apply_config(UpgradeCard.MAGNUM_1)
	check(card.c_background == UpgradeCard.Background.blue, "a Variant reaches a typed enum field")
	check(card.title.text == "Magnum", "a Variant reaches a typed String field")
	check(card.weapon_scene is PackedScene, "a Variant reaches a typed PackedScene field")
	card.queue_free()


# --- 11. Setters clamp --------------------------------------------------------


func verify_setter() -> void:
	var bar: HealthBar = HealthBar.new()
	var label: Label = Label.new()
	bar.add_child(label)
	bar.label = label
	add_child(bar)
	bar.value = 500
	check(bar.value == 100, "a clamping setter holds the upper bound")
	bar.value = -20
	check(bar.value == 0, "a clamping setter holds the lower bound")
	bar.queue_free()


# --- 12. preload constants ----------------------------------------------------


func verify_preloads() -> void:
	check(Player.GOLD_SCENE is PackedScene, "a preload const is a PackedScene")
	check(MagnumWeapon.BULLET_SCENE is PackedScene, "a weapon preload const is a PackedScene")
	check(EnemySpawner.ENEMY_SCENE is PackedScene, "a spawner preload const is a PackedScene")


# --- 13. the warning block ----------------------------------------------------


# The section header is part of the key. `gdscript/warnings/x` under `[gdscript]`
# is a setting Godot accepts, stores and never reads, so the block reads as present
# while nothing enforces it.
func verify_warning_settings() -> void:
	for warning: String in WARNINGS:
		var key: String = WARNING_PREFIX + warning
		check(ProjectSettings.has_setting(key), "warning is set at its real key: " + key)
		var level: int = ProjectSettings.get_setting(key, 0)
		check(level == 2, "warning is an error, not a warning: " + key)
		check(
			!ProjectSettings.has_setting("gdscript/warnings/" + warning),
			"no headerless twin of the warning: " + warning
		)
