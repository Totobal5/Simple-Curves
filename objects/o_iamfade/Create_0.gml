/// @description
struct = {image_alpha: 1, image_angle: 0}
first = false;

scurve = new SCurve("Linear")
		.Target(struct)
		.Once(1, "image_alpha", 0);