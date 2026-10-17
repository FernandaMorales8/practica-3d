// Altura de las olas en un punto del mar. La comparten el agua y los anillos
// de espuma para que la espuma flote siempre sobre la superficie.
float wave_at(vec2 p, float t) {
	return sin(p.x * 0.31 + t) * 0.5
		+ sin(p.y * 0.23 + t * 1.3) * 0.5
		+ sin((p.x + p.y) * 0.57 + t * 2.1) * 0.25;
}
