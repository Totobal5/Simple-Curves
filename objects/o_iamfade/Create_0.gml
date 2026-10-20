/// @description

test_reverse_next = false;

struct = {
	image_alpha: 1,
	image_angle: 0,
    
    image_xscale: 1,
    image_yscale: 1,
}

test_patrol = new SCurve(SCURVE.EASE, false)
	.Target(self)
	.Patrol(1.0, 0.5, 1.0, "image_angle", 359, "image_xscale", 2, "image_yscale", 2)
    .Repeat()
    .Play()