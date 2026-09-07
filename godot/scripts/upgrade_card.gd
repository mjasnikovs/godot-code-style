class_name UpgradeCard extends Control

enum Background {red, blue}
enum Icon {bow, sword}

# Config lives in const Dictionary blobs, never a Resource subclass.
const magnum_1: Dictionary = {
	"background": Background.blue,
	"icon": Icon.bow,
	"title_label": "Magnum",
	"description_label": "10",
	"packed_scene": preload("res://scenes/bullet.tscn")
}

@export var title: Label
@export var description: Label

var c_background: Background = Background.red
var c_icon: Icon = Icon.bow
var weapon_scene: PackedScene = null


func _ready() -> void:
	assert(title, "upgrade_card.gd - @export title is not set in the editor on: " + self.name)
	assert(description, "upgrade_card.gd - @export description is not set in the editor on: " + self.name)


# The boundary. A Variant travels exactly one hop, into a typed field.
func apply_config(card: Dictionary) -> void:
	var background: Background = card["background"]
	var icon: Icon = card["icon"]
	var title_text: String = card["title_label"]
	var description_text: String = card["description_label"]
	var scene: PackedScene = card["packed_scene"]

	c_background = background
	c_icon = icon
	title.text = title_text
	description.text = description_text
	weapon_scene = scene
