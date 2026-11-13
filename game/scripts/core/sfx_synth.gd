class_name SfxSynth
extends RefCounted
## Placeholder audio made in code (Sfx plays it): short sounds from tones and filtered noise, and mood loops from
## pads, a bass line, plucks from a scale and, for fights, a soft drum. Pure and deterministic (seeded), so it
## runs on a thread and in tests. Real audio files replace any of it (see Sfx).

const TAU_F := TAU

## mood -> tempo (bpm), root (MIDI), scale, chord roots (scale degrees, one a bar), pluck chance, drums, pad level
const MOODS := {
	"menu": {"bpm": 66, "root": 50, "scale": [0, 2, 4, 7, 9], "chords": [0, 5, 3, 4], "pluck": 0.28, "drums": false, "pad": 0.16},
	"village": {"bpm": 84, "root": 55, "scale": [0, 2, 4, 7, 9], "chords": [0, 4, 5, 3], "pluck": 0.42, "drums": false, "pad": 0.13},
	"wild": {"bpm": 72, "root": 52, "scale": [0, 3, 5, 7, 10], "chords": [0, 5, 3, 4], "pluck": 0.25, "drums": false, "pad": 0.15},
	"road": {"bpm": 96, "root": 53, "scale": [0, 2, 4, 7, 9], "chords": [0, 3, 4, 0], "pluck": 0.5, "drums": false, "pad": 0.12},
	"fight": {"bpm": 132, "root": 50, "scale": [0, 3, 5, 7, 10], "chords": [0, 0, 5, 4], "pluck": 0.55, "drums": true, "pad": 0.11},
	"boss": {"bpm": 120, "root": 45, "scale": [0, 1, 5, 7, 8], "chords": [0, 1, 0, 4], "pluck": 0.45, "drums": true, "pad": 0.14},
}
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const MINOR := [0, 2, 3, 5, 7, 8, 10]


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## A one-shot sound by name; null for a name it doesn't know.
static func sound(name: String, rate: int) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	match name:
		"click":
			b = _buf(0.05, rate)
			_tone(b, rate, 0.0, 0.035, 1500.0, 1100.0, "tri", 0.35, 0.002)
		"hover":
			b = _buf(0.03, rate)
			_tone(b, rate, 0.0, 0.02, 2400.0, 2400.0, "sine", 0.2, 0.002)
		"open":
			b = _buf(0.16, rate)
			_tone(b, rate, 0.0, 0.14, 420.0, 880.0, "sine", 0.3, 0.01)
		"close":
			b = _buf(0.14, rate)
			_tone(b, rate, 0.0, 0.12, 820.0, 380.0, "sine", 0.28, 0.005)
		"confirm":
			b = _buf(0.18, rate)
			_tone(b, rate, 0.0, 0.07, 660.0, 660.0, "tri", 0.3, 0.004)
			_tone(b, rate, 0.07, 0.1, 990.0, 990.0, "tri", 0.3, 0.004)
		"error":
			b = _buf(0.2, rate)
			_tone(b, rate, 0.0, 0.18, 170.0, 150.0, "square", 0.18, 0.005)
		"hit":
			b = _buf(0.22, rate)
			_noise(b, rate, 0.0, 0.09, 0.55, 0.25, 7)
			_tone(b, rate, 0.0, 0.16, 140.0, 55.0, "sine", 0.7, 0.002)
		"crit":
			b = _buf(0.5, rate)
			_noise(b, rate, 0.0, 0.11, 0.6, 0.35, 11)
			_tone(b, rate, 0.0, 0.18, 160.0, 50.0, "sine", 0.75, 0.002)
			_tone(b, rate, 0.04, 0.42, 1320.0, 1320.0, "sine", 0.25, 0.004)
			_tone(b, rate, 0.04, 0.42, 1980.0, 1980.0, "sine", 0.12, 0.004)
		"miss":
			b = _buf(0.2, rate)
			_noise(b, rate, 0.0, 0.18, 0.3, 0.6, 3, true)
		"down":
			b = _buf(0.5, rate)
			_tone(b, rate, 0.0, 0.45, 300.0, 70.0, "tri", 0.4, 0.005)
			_noise(b, rate, 0.0, 0.12, 0.3, 0.2, 5)
		"hurt":
			b = _buf(0.16, rate)
			_tone(b, rate, 0.0, 0.12, 260.0, 180.0, "saw", 0.22, 0.002)
			_noise(b, rate, 0.0, 0.06, 0.3, 0.3, 13)
		"pickup":
			b = _buf(0.22, rate)
			_tone(b, rate, 0.0, 0.08, 880.0, 880.0, "tri", 0.3, 0.003)
			_tone(b, rate, 0.07, 0.14, 1320.0, 1320.0, "tri", 0.3, 0.003)
		"coin":
			b = _buf(0.3, rate)
			_tone(b, rate, 0.0, 0.06, 1568.0, 1568.0, "square", 0.12, 0.002)
			_tone(b, rate, 0.05, 0.24, 2093.0, 2093.0, "square", 0.12, 0.002)
		"levelup":
			b = _buf(0.9, rate)
			var notes := [60, 64, 67, 72]
			for i in notes.size():
				_tone(b, rate, i * 0.09, 0.5 if i == 3 else 0.12, hz(notes[i]), hz(notes[i]), "tri", 0.3, 0.004)
			_tone(b, rate, 0.27, 0.6, hz(79), hz(79), "sine", 0.12, 0.01)
		"victory":
			b = _buf(1.4, rate)
			var fan := [55, 60, 64, 67]
			for i in fan.size():
				_tone(b, rate, i * 0.12, 0.14, hz(fan[i]), hz(fan[i]), "square", 0.14, 0.004)
			for n in [60, 64, 67, 72]:
				_tone(b, rate, 0.48, 0.85, hz(n), hz(n), "tri", 0.17, 0.01)
		"defeat":
			b = _buf(1.6, rate)
			var down := [64, 62, 60, 57]
			for i in down.size():
				_tone(b, rate, i * 0.3, 0.5, hz(down[i]), hz(down[i]), "tri", 0.25, 0.02)
			_tone(b, rate, 0.9, 0.7, hz(45), hz(45), "sine", 0.3, 0.05)
		"door":
			b = _buf(0.3, rate)
			_tone(b, rate, 0.0, 0.2, 90.0, 60.0, "sine", 0.55, 0.003)
			_noise(b, rate, 0.0, 0.15, 0.3, 0.15, 17)
		"hint":
			b = _buf(0.6, rate)
			_tone(b, rate, 0.0, 0.5, 1046.0, 1046.0, "sine", 0.22, 0.004)
			_tone(b, rate, 0.08, 0.45, 1568.0, 1568.0, "sine", 0.14, 0.004)
		"stone":
			b = _buf(1.6, rate)
			for i in 5:
				var f := hz(72 + [0, 4, 7, 11, 14][i])
				_tone(b, rate, i * 0.1, 1.2, f * 0.99, f * 1.01, "sine", 0.12, 0.2)
		"camp":
			b = _buf(0.7, rate)
			for i in 9:
				_noise(b, rate, i * 0.07, 0.03, 0.25, 0.4, 19 + i)
		"move":
			b = _buf(0.08, rate)
			_noise(b, rate, 0.0, 0.06, 0.25, 0.15, 23)
		"step_turn":
			b = _buf(0.07, rate)
			_tone(b, rate, 0.0, 0.05, 520.0, 520.0, "sine", 0.22, 0.003)
		_:
			return null
	return _wav(b, rate, false)


## A mood loop: eight bars, seamless.
static func music(mood: String, rate: int) -> AudioStreamWAV:
	var m: Dictionary = MOODS.get(mood, MOODS.menu)
	var beat := 60.0 / float(m.bpm)
	var bars := 8
	var length := beat * 4.0 * bars
	var b := _buf(length, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(mood)
	var minor: bool = (m.scale as Array).has(3)
	var key: Array = MINOR if minor else MAJOR
	var chords: Array = m.chords
	for bar in bars:
		var deg := int(chords[bar % chords.size()])
		var root := int(m.root) + int(key[deg % 7])
		var t0 := bar * beat * 4.0
		# pad: the chord's three tones, slow in and out within the bar
		for k in [0, 2, 4]:
			var n := int(m.root) + int(key[(deg + k) % 7]) + (12 if deg + k >= 7 else 0)
			_tone(b, rate, t0, beat * 4.0, hz(n), hz(n), "pad", float(m.pad), beat * 1.2, beat * 1.6)
		# bass: the root on beats 1 and 3
		for q in [0, 2]:
			_tone(b, rate, t0 + q * beat, beat * 1.6, hz(root - 12), hz(root - 12), "tri", 0.2, 0.01, beat * 0.4)
		# plucks: eighth notes from the scale, near the chord's root
		for e in 8:
			if rng.randf() < float(m.pluck):
				var sc: Array = m.scale
				var n := int(m.root) + 12 + int(sc[rng.randi() % sc.size()]) + (12 if rng.randf() < 0.25 else 0)
				_tone(b, rate, t0 + e * beat * 0.5, beat * 0.9, hz(n), hz(n), "pluck", 0.14, 0.003)
		if bool(m.drums):
			for q in 4:
				_tone(b, rate, t0 + q * beat, 0.18, 110.0, 45.0, "sine", 0.4, 0.002)
				_noise(b, rate, t0 + (q + 0.5) * beat, 0.04, 0.12, 0.85, 31 + q, true)
	return _wav(b, rate, true)


# --- building blocks ---------------------------------------------------------------------------

static func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


## A tone from start for dur seconds, sliding f0 -> f1. wave: sine, tri, square, saw, pad (soft, detuned), pluck
## (bright, fast decay). attack: seconds in; release: seconds out at the end (default: the tone decays).
static func _tone(b: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, wave: String, amp: float,
		attack: float, release := -1.0) -> void:
	var i0 := int(start * rate)
	var n := int(dur * rate)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var at := i0 + i
		if at < 0:
			continue
		if at >= b.size():
			at -= b.size()  # a loop's tail wraps to its head, so it stays seamless
			if at >= b.size():
				break
		var t := float(i) / float(rate)
		var u := float(i) / float(n)
		var f := lerpf(f0, f1, u)
		ph += f / rate
		ph2 += f * 1.006 / rate
		var x := 0.0
		match wave:
			"sine":
				x = sin(TAU_F * ph)
			"tri":
				x = 1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)
			"square":
				x = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
			"saw":
				x = 2.0 * fposmod(ph, 1.0) - 1.0
			"pad":
				x = 0.6 * sin(TAU_F * ph) + 0.4 * sin(TAU_F * ph2) + 0.15 * sin(TAU_F * ph * 2.0)
			"pluck":
				x = (1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)) * 0.7 + sin(TAU_F * ph * 2.0) * 0.3
		var env := minf(1.0, t / maxf(attack, 0.0005))
		if release >= 0.0:
			env *= clampf((dur - t) / maxf(release, 0.0005), 0.0, 1.0)
		elif wave == "pluck":
			env *= exp(-t * 9.0)
		else:
			env *= pow(1.0 - u, 2.0)
		b[at] += x * env * amp


## Filtered noise: smooth (0..1) is a one-pole low pass (high = darker); high_pass keeps only the hiss.
static func _noise(b: PackedFloat32Array, rate: int, start: float, dur: float, amp: float, smooth: float, seed_n: int,
		high_pass := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var i0 := int(start * rate)
	var n := int(dur * rate)
	var lp := 0.0
	for i in n:
		var at := i0 + i
		if at >= b.size():
			at -= b.size()
			if at >= b.size():
				break
		var w := rng.randf_range(-1.0, 1.0)
		lp = lerpf(w, lp, smooth)
		var x := (w - lp) if high_pass else lp
		var u := float(i) / float(n)
		b[at] += x * amp * pow(1.0 - u, 2.0) * minf(1.0, float(i) / 40.0)


## 16-bit mono WAV, soft-limited.
static func _wav(b: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var v := b[i]
		v = v / (1.0 + absf(v) * 0.6)  # soft limit, so stacked voices never clip hard
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w
