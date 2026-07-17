@tool
class_name DistructibleBlock
extends RigidBody2D

const SHARD_SCENE = preload("res://shard.tscn")

@export var divisions : int = 10
@export var impulse_force : float = 550.0

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var texture: Texture2D = null:
	set(value):
		texture = value
		_update_texture()

			
@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var collision_polygon_2d: CollisionPolygon2D = $CollisionPolygon2D

var default_texture

func _update_texture() -> void:
	if !sprite_2d:
		return
	if texture:
		sprite_2d.texture = texture
	else:
		sprite_2d.texture = default_texture
	# sprite2Dのサイズからpolygonの大きさを決める
	var tex_size = sprite_2d.texture.get_size()
	polygon_2d.polygon = PackedVector2Array([
		Vector2(-tex_size.x / 2, -tex_size.y / 2),
		Vector2(tex_size.x / 2, -tex_size.y / 2),
		Vector2(tex_size.x / 2, tex_size.y / 2),
		Vector2(-tex_size.x / 2, tex_size.y / 2)
	])

	# colisionにコピー
	collision_polygon_2d.polygon = polygon_2d.polygon	
	
func _ready() -> void:
	default_texture = sprite_2d.texture
	_update_texture()
		


func is_point_inside(global_pos:Vector2)->bool:
	var local_pos = polygon_2d.to_local(global_pos)
	return Geometry2D.is_point_in_polygon(local_pos, polygon_2d.polygon)
	

# 外部から攻撃や弾が当たったときにこの関数を呼ぶ
func take_damage():
	explode_into_shards()


func explode_into_shards():
	var sprite = $Sprite2D
	if not sprite or not sprite.texture:
		queue_free()
		return
		
	var size = sprite.texture.get_size()
	
	# 1. ボロノイの「母点（セルの中心）」をランダムに配置
	# この数を増やすと、破片の数が多くなり、1つ1つが小さくなります
	var cell_count = divisions
	var centers = PackedVector2Array()
	for i in range(cell_count):
		centers.append(Vector2(randf_range(0, size.x), randf_range(0, size.y)))
		
	# 2. 細かいサンプル点（グリッド）を作り、それぞれの点が「どの母点に一番近いか」で分類する
	# ※これにより、本物のボロノイ分割をシミュレートします
	var cell_points = {}
	for i in range(cell_count):
		cell_points[i] = PackedVector2Array()
		
	# 外枠の4隅は必ずどこかのセルに含める
	var corners = [Vector2(0,0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]
	
	# 画像全体を細かく走査して頂点を集める（解像度）
	var steps_x = 20
	var steps_y = 20
	var all_points = PackedVector2Array(corners)
	for y in range(steps_y + 1):
		for x in range(steps_x + 1):
			all_points.append(Vector2(x * (size.x / steps_x), y * (size.y / steps_y)))
			
	# 各サンプル点を、一番近い母点のグループに振り分ける
	for p in all_points:
		var closest_idx = 0
		var min_dist = INF
		for i in range(cell_count):
			var dist = p.distance_squared_to(centers[i])
			if dist < min_dist:
				min_dist = dist
				closest_idx = i
		cell_points[closest_idx].append(p)

	var offset = size / 2.0 if sprite.centered else Vector2.ZERO
	
	# 3. グループごとに外周（Convex Hull）を計算して、1つずつの独立した多角形（破片）にする
	for i in range(cell_count):
		var pts = cell_points[i]
		# 点が少なすぎるグループ（端っこなど）はスキップ
		if pts.size() < 3:
			continue
			
		# そのグループの点たちを包み込む「1つの綺麗な凸多角形」を作成（ダブりや巨大化が起きない）
		var poly = Geometry2D.convex_hull(pts)
		if poly.size() < 3:
			continue
			
		# 多角形の正確な重心を計算
		var center = Vector2.ZERO
		for p in poly:
			center += p
		center /= poly.size()
		
		# 破片ノードの生成
		var shard = SHARD_SCENE.instantiate() as Shard
		var poly_node = shard.get_node("Polygon2D")
		var coll_node = shard.get_node("CollisionPolygon2D")
		
		get_parent().add_child(shard)
		
		# 位置と回転の同期
		var local_spawn_pos = -offset + center
		shard.global_position = global_position + local_spawn_pos.rotated(global_rotation)
		shard.global_rotation = global_rotation
		
		# 重心を(0,0)としたローカルポリゴン
		var local_poly = PackedVector2Array()
		for p in poly:
			local_poly.append(p - center)
			
		# 見た目とコリジョンの設定
		poly_node.texture = sprite.texture
		poly_node.polygon = local_poly
		poly_node.uv = poly
		coll_node.polygon = local_poly
		
		# 物理的な力を加える
		shard.linear_velocity = linear_velocity
		var push_dir = (center - offset).normalized().rotated(global_rotation)
		shard.apply_central_impulse(push_dir * randf_range(impulse_force * 0.5, impulse_force))
		
		fade_out_shard(shard)
		
	queue_free()


func fade_out_shard(shard: Shard):
	var timer_lifetime = randf_range(1.5, 3.0)
	shard.lifetime = timer_lifetime
