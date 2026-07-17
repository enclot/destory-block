class_name Shard
extends RigidBody2D
@onready var polygon_2d: Polygon2D = $Polygon2D
var collision_polygon_2d: CollisionPolygon2D

var lifetime:float:
	set(value):
		lifetime = value
		await get_tree().create_timer(lifetime).timeout
		_disappear()

func _ready() -> void:
	var new_collision = CollisionPolygon2D.new()
	new_collision.polygon = polygon_2d.polygon
	add_child(new_collision)
	collision_polygon_2d = new_collision

func _disappear() -> void:
	collision_polygon_2d.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(self.queue_free)
