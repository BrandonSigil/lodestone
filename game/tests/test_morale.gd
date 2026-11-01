extends TestCase
## Per-character morale ([USER] 2026-10-31 design-goodboy, design-morale; docs/systems/morale.md): bands, falls and
## wins, Doggo's softening, journey days for whoever stays home, the bed, and morale in fights and checks.

const NUMS := {"start": 70, "max": 100, "down": -5, "left_down": -10, "wipe": -10, "win": 2, "big_win": 5,
	"home_day": 3, "dog_soften_pct": 20}


func _db() -> void:
	if Db.levels.is_empty() or Db.morale.is_empty():
		Db.reload()


func test_bands_from_data() -> void:
	_db()
	var bands := Db.morale_bands
	eq(String(MoraleRules.band(100, bands).band), "heartened")
	eq(String(MoraleRules.band(80, bands).band), "heartened", "80 to 100 is high morale ([USER] Pitch B)")
	eq(String(MoraleRules.band(79, bands).band), "steady")
	eq(String(MoraleRules.band(70, bands).band), "steady", "everyone starts steady")
	eq(String(MoraleRules.band(45, bands).band), "shaken")
	eq(String(MoraleRules.band(20, bands).band), "low")
	eq(String(MoraleRules.band(0, bands).band), "broken")
	eq(MoraleRules.fight_mods(70, bands), {}, "steady changes nothing")
	eq(MoraleRules.fight_mods(90, bands), {"attack": 2}, "high morale: a passive bonus")
	eq(MoraleRules.fight_mods(25, bands), {"damage": -1, "move": -1})
	eq(MoraleRules.fight_mods(5, bands), {"damage": -2, "move": -1, "defense": -1, "res_max": -1})
	eq(MoraleRules.check_mod(90, bands), 1)
	eq(MoraleRules.check_mod(70, bands), 0)
	eq(MoraleRules.check_mod(25, bands), -2)
	eq(MoraleRules.check_mod(5, bands), -3)
	for b: Dictionary in bands:
		ok(Txt.has(String(b.name_key)), "band name %s in the text table" % b.name_key)
		ok(MoraleRules.describe(b) != "", "band %s says what it does" % b.band)


func test_change_clamps_and_dog_softens() -> void:
	var h := {}
	eq(MoraleRules.of(h, "lead", NUMS), 70, "a new character starts at 70")
	eq(MoraleRules.change(h, "lead", -5, NUMS), -5)
	eq(int(h.lead), 65)
	eq(MoraleRules.change(h, "lead", 50, NUMS), 35, "never past 100")
	eq(MoraleRules.change(h, "lead", -500, NUMS), -100, "never under 0")
	eq(MoraleRules.softened(-5, true, NUMS), -4, "Good Boy: -5 is -4")
	eq(MoraleRules.softened(-10, true, NUMS), -8)
	eq(MoraleRules.softened(-15, true, NUMS), -12)
	eq(MoraleRules.softened(-5, false, NUMS), -5, "only while Doggo is along")
	eq(MoraleRules.softened(10, true, NUMS), 10, "gains are untouched")


func test_after_fight() -> void:
	var pieces := [{"id": "lead", "downs": 0, "out": false}, {"id": "dog", "downs": 1, "out": false},
		{"id": "bushberry", "downs": 1, "out": true}]
	eq(MoraleRules.after_fight(pieces, "won", false, NUMS), {"lead": 2, "dog": -5, "bushberry": -15},
		"a win lifts who stayed up; a fall costs 5, a fall nobody picked up 15")
	eq(MoraleRules.after_fight(pieces, "won", true, NUMS).lead, 5, "an elite or boss win: +5")
	eq(MoraleRules.after_fight(pieces, "escaped", false, NUMS), {"dog": -5, "bushberry": -15}, "no win bonus for running")
	var wipe := [{"id": "lead", "downs": 1, "out": true}, {"id": "dog", "downs": 1, "out": false}]
	eq(MoraleRules.after_fight(wipe, "lost", false, NUMS), {"lead": -25, "dog": -15}, "everyone down: another -10 each")


func test_days_and_home() -> void:
	var clock := {}
	eq(MoraleRules.days_in(clock, 100.0, 150.0), 0)
	eq(MoraleRules.days_in(clock, 100.0, 150.0), 1, "the part of a day carries over")
	eq(MoraleRules.days_in(clock, 300.0, 150.0), 2)
	var h := {"dog": 50}
	eq(MoraleRules.home_days(h, ["dog", "bushberry"], 4, NUMS), {"dog": 12, "bushberry": 12},
		"[USER] design-morale: every day gone, X for each character at home")
	eq(int(h.dog), 62)
	eq(MoraleRules.home_days(h, ["dog"], 0, NUMS), {})


## The real Game: morale lives in meta, rides into fights and checks, and the trip's days rest the bench.
func test_game_morale() -> void:
	_db()
	var keep_save := Game.save_enabled
	var keep_meta := Game.meta
	var keep_run := Game.run
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.run = null
	Game.set_flag("met_dog")
	Game.ensure_run()
	ok(Game.run.hearts == Game.meta.morale and is_same(Game.run.hearts, Game.meta.morale), "the run's hearts are meta's")
	eq(int(Game.meta.morale.get("lead", -1)), 70, "everyone met has a morale from the start")
	eq(int(Game.meta.morale.get("dog", -1)), 70)
	# a fight: the hero went down and bled out, the dog stayed up
	var lead := CombatUnit.from_member(Game.run.members[0])
	var dog := CombatUnit.from_member(Game.run.members[1])
	lead.hp = 0  # down: bleeding
	lead.bleed = 0  # ...and out
	var lines := Game.fight_morale([lead, dog], "won", false)
	eq(Game.morale_of("lead"), 58, "-15 softened by Doggo: -12")
	eq(Game.morale_of("dog"), 72)
	eq(lines.size(), 2)
	# bands reach the fight numbers
	Game.meta.morale.lead = 10
	Game.refresh_party()
	var broken := CombatUnit.from_member(Game.run.members[0])
	Game.meta.morale.lead = 70
	Game.refresh_party()
	var steady := CombatUnit.from_member(Game.run.members[0])
	eq(steady.damage - broken.damage, mini(2, steady.damage - 1), "broken: -2 damage")
	eq(steady.move - broken.move, 1, "broken: -1 move")
	# checks: each member's own band
	var base := TrailRules.party_bonus(Game.run, "nerve")
	Game.meta.morale.lead = 10
	Game.meta.morale.dog = 10
	eq(TrailRules.party_bonus(Game.run, "nerve"), base - 3, "broken: -3 on checks")
	Game.meta.morale.lead = 70
	Game.meta.morale.dog = 70
	# an event's morale is the whole party's
	TrailRules.apply_effects(Game.run, "morale:-10")
	eq(Game.morale_of("lead"), 62, "-10 softened to -8 with Doggo along")
	eq(Game.morale_of("dog"), 62)
	# leave the dog home; the trip's days rest him
	Game.dismiss("dog")
	ok(not Game.in_party("dog"))
	Game.start_trip()
	Game.pass_days(4)
	eq(Game.morale_of("dog"), 62 + 4 * int(Db.morale.home_day), "a day gone: home_day for whoever stayed home")
	eq(Game.morale_of("lead"), 62, "the party gets nothing from days")
	Game.homecoming = {}
	Game.home_again(true)
	eq(int(Game.homecoming.get("days", 0)), 4, "the page counts the days gone")
	ok(Game.homecoming.morale.any(func(r: Dictionary) -> bool: return String(r.id) == "dog"), "and the dog's rest")
	# the bed: once a trip, everyone
	ok(Game.sleep_at_home())
	eq(Game.morale_of("lead"), 62 + int(Db.morale.bed))
	ok(not Game.sleep_at_home(), "once a trip")
	Game.start_trip()
	ok(Game.sleep_at_home(), "a new trip, a new night")
	Game.meta = keep_meta
	Game.run = keep_run
	Game.save_enabled = keep_save
	Game.homecoming = {}


func test_data_rows() -> void:
	_db()
	for id in Db.recipes:
		ok(int(Db.recipes[id].get("morale", 0)) > 0, "meal %s lifts morale" % id)
	ok(Db.explore_events.has("home_bed"), "the bed's event")
	for k in ["UI_MORALE_CHANGE", "UI_LS_MORALE", "UI_PARTY_HEART", "UI_HC_DAYS", "UI_SLEPT", "UI_BED_USED", "EX_KIND_BED", "EX_HOME_BED"]:
		ok(Txt.has(k), k)
