class_name UIKit
extends RefCounted
## Building blocks for the "dispatcher's desk" UI: paper tickets with ink
## outlines and a heavy bottom edge, condensed signage headers, typewriter numbers.

static var _fonts := {}


static func font(name: String) -> Font:
	if not _fonts.has(name):
		var path: String = {
			"body": "res://fonts/Barlow-Medium.ttf",
			"bold": "res://fonts/Barlow-SemiBold.ttf",
			"head": "res://fonts/BarlowCondensed-Bold.ttf",
			"head_semi": "res://fonts/BarlowCondensed-SemiBold.ttf",
			"mono": "res://fonts/IBMPlexMono-Medium.ttf",
			"mono_bold": "res://fonts/IBMPlexMono-Bold.ttf",
		}[name]
		var f: FontFile = load(path)
		if name.begins_with("head"):
			var fv := FontVariation.new()
			fv.base_font = f
			fv.spacing_glyph = 1
			_fonts[name] = fv
		else:
			_fonts[name] = f
	return _fonts[name]


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 15
	t.set_color("font_color", "Label", Palette.TEXT)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Palette.INK
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Palette.TEXT_INV)
	return t


## Paper ticket: cream fill, ink outline, heavier bottom edge.
static func paper_style(bg := Palette.PAPER, pad := 14, bottom := 5, border := Palette.INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = bottom
	s.set_corner_radius_all(4)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = false
	return s


static func ink_style(pad := 12, bg := Palette.INK_2) -> StyleBoxFlat:
	var s := paper_style(bg, pad, 4, Palette.INK)
	return s


static func flat(bg: Color, radius := 3, pad_x := 8, pad_y := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func paper(pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_style(Palette.PAPER, pad))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func ink(pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ink_style(pad))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func label(text: String, size := 15, color := Palette.TEXT, f := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(f))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func head(text: String, size := 18, color := Palette.TEXT) -> Label:
	return label(text.to_upper(), size, color, "head")


static func mono(text: String, size := 15, color := Palette.TEXT, bold := false) -> Label:
	return label(text, size, color, "mono_bold" if bold else "mono")


## Rubber-stamp style status tag: outlined, condensed caps.
static func stamp(text: String, color: Color, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color, 0.12)
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	var l := label(text.to_upper(), size, color.darkened(0.15), "head")
	l.name = "L"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func set_stamp(p: PanelContainer, text: String, color: Color) -> void:
	var l: Label = p.get_node("L")
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", color.darkened(0.15))
	var s := p.get_theme_stylebox("panel") as StyleBoxFlat
	s.border_color = color
	s.bg_color = Color(color, 0.12)


static func hbox(sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func vbox(sep := 6) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func rule(color := Palette.RULE, dashed := true) -> Control:
	var r := LMRule.new()
	r.color = color
	r.dashed = dashed
	return r


## Chunky press-able button. kind: "go" (orange), "ink", "paper".
static func button(text: String, kind := "paper", size := 15) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	var bg: Color
	var fg: Color
	match kind:
		"go":
			bg = Palette.ORANGE
			fg = Palette.INK
		"ink":
			bg = Palette.INK_2
			fg = Palette.TEXT_INV
		"green":
			bg = Color("8fb07a")
			fg = Palette.INK
		_:
			bg = Palette.PAPER_2
			fg = Palette.INK
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	var normal := paper_style(bg, 0, 4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 2
	pressed.border_width_top = 4
	pressed.bg_color = bg.darkened(0.08)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(bg, 0.35)
	disabled.border_color = Color(Palette.INK, 0.35)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var snd := "confirm" if kind == "go" else "click"
	b.pressed.connect(func(): GameAudio.sfx(snd, randf_range(0.97, 1.03), -9.0 if snd == "click" else -6.0))
	return b


static func avatar(initials: String, col: Color, size := 30) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = Palette.INK
	s.set_border_width_all(2)
	s.set_corner_radius_all(size)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(size, size)
	var l := label(initials, 12, Palette.INK, "head")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func slider(lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size.y = 22
	var track := flat(Palette.PAPER_3, 2, 0, 3)
	var fill := flat(Palette.INK, 2, 0, 3)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s


## Gives any control a hover explanation. Long text is wrapped to ~56 columns.
static func tip(c: Control, text: String) -> Control:
	c.tooltip_text = wrap_text(text)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


static func wrap_text(text: String, width := 56) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			if line.length() + word.length() + 1 > width and line != "":
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		out.append(line)
	return "\n".join(out)


static func money(v: float) -> String:
	var neg := v < 0.0
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out
