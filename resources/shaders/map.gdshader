shader_type spatial;

// Maximum height.
uniform float height;

// Update progress in [0, 1].
uniform float progress;

// Size of the update wave.
uniform float band : hint_range(0.0, 1.0, 0.01) = .2;

// Update attenuation with the distance in [0, 1].
// 0 = no attenuation, 1 = full merge.
uniform float distance_smooth : hint_range(0., 1.) = .5;

// INSTANCE_CUSTOM :
// x => [0, 1] : Distance from the center.
// y => Old cell height.
// z => New cell height.
void vertex() {
	float mb = band * .5;
	float apex = (band * (.5 - INSTANCE_CUSTOM.x)) + INSTANCE_CUSTOM.x;

	float ratio;
	if(progress >= 1.) {
		ratio = INSTANCE_CUSTOM.z;
	} else {
		float p;
		if(progress < (apex - mb) || progress > (apex + mb)) {
			p = 0.;
		} else {
			p = (cos( 2. * PI * (((apex - progress) / band) + 1.) ) + 1.) / 2.;
		}

		float target;
		if (progress < apex) {
			target = INSTANCE_CUSTOM.y;
		} else {
			target = INSTANCE_CUSTOM.z;
		}

		float updated_target = (INSTANCE_CUSTOM.z * distance_smooth) + (height * (1. - distance_smooth));
		float updated_height = (updated_target * INSTANCE_CUSTOM.x) + (height * (1. - INSTANCE_CUSTOM.x));
		ratio = updated_height * p + (target * (1. - p));
	}

	VERTEX.y *= ratio;
	VERTEX.y += ratio / 2.;
}
