extends RefCounted
## One-based logical cells ↔ local presentation coordinates.
## The basis may be square or diamond-shaped; gameplay never reads its pixel values.
var _transform: Transform2D
var _origin: Vector2
var _axis_x: Vector2
var _axis_y: Vector2
var _determinant: float
func _init(origin: Vector2, axis_x: Vector2, axis_y: Vector2) -> void:
	_transform = Transform2D(axis_x,axis_y,origin)
	assert(not is_zero_approx(_transform.determinant()), "Grid projection needs independent axes")
	_origin = origin
	_axis_x = axis_x
	_axis_y = axis_y
	_determinant = axis_x.x*axis_y.y-axis_y.x*axis_x.y
func cell_anchor(cell: Vector2i) -> Vector2:
	return _transform * Vector2(cell-Vector2i.ONE)
func point_to_cell(point: Vector2) -> Vector2i:
	var delta := point-_origin
	# Scalar division avoids inverse-matrix rounding shifting exact tile boundaries.
	var x := (delta.x*_axis_y.y-delta.y*_axis_y.x)/_determinant
	var y := (_axis_x.x*delta.y-_axis_x.y*delta.x)/_determinant
	return Vector2i(floori(x)+1,floori(y)+1)
