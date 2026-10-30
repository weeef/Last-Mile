extends SceneTree
## Checks the audio system: every sound loads, the buses exist, and players
## actually start. Run: godot --headless --path . -s tools/audio_test.gd
var audio: GameAudio
var frame := 0

func _init() -> void:
	audio = GameAudio.new()
	root.add_child(audio)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		var ok := true
		for b in ["Master"] + GameAudio.BUSES:
			var i := AudioServer.get_bus_index(b)
			print("bus %-9s %s" % [b, "ok" if i >= 0 else "MISSING"])
			ok = ok and i >= 0
		var missing: Array = []
		for n in GameAudio.SFX:
			if not audio._sfx.has(n):
				missing.append(n)
		print("sfx loaded: %d/%d %s" % [audio._sfx.size(), GameAudio.SFX.size(), missing])
		ok = ok and missing.is_empty()
		for t in GameAudio.MUSIC.keys():
			var s := GameAudio._load(GameAudio.MUSIC[t])
			print("music %-6s %s %.1fs" % [t, "ok" if s else "MISSING", s.get_length() if s else 0.0])
			ok = ok and s != null
		for n in GameAudio.AMBIENCE.keys():
			var p: AudioStreamPlayer = audio._amb[n]
			print("ambience %-6s %s" % [n, "ok" if p.stream else "MISSING"])
			ok = ok and p.stream != null
		print("engine loop %s" % ("ok" if audio._engine.stream else "MISSING"))
		GameAudio.music("day")
		GameAudio.sfx("ding")
		GameAudio.ambience(false, true)
		GameAudio.engine(1.0)
		print("ALL AUDIO FILES OK" if ok else "AUDIO PROBLEMS")
	if frame == 30:
		var playing := 0
		for p in audio._players:
			if p.playing: playing += 1
		print("music playing: %s · sfx voices playing: %d · rain playing: %s · engine playing: %s" % [audio._a.playing, playing, audio._amb["rain"].playing, audio._engine.playing])
		quit()
	return false
