extends "res://tools/outing_sim_run.gd"
## The economy sim. Modes (all print markdown tables):
##   acts                         exact odds and yield of hunt, forage and fish by party skill bonus (no dice)
##   road [trips=N party=duo|trio|quad route=town,pass ration=filling|meager|bare camp=first|best|dark|every
##         evening=food|morale|mixed|none food=12 grace=0 morale=70 map_days=3 map_loot=15 heal_need=12 fishp=0.6]
##                                the road's nights: campsites, rough camps, food eaten and found, morale
##   chain [runs=N weapons=sword,daggers,bow heal=none|meat|both road=0|1 attempts=6 upg=0 keep=4 foe_hp=70 gap=30]
##                                the pass trip fight by fight with the real fight engine: HP per fight, XP, the Lich by attempt
##   levels [fights=N lvls=3,5,7,9,12]  the Lich from set arrival HP at each level
## acts and road also take hunt_dc=13 hunt_food=4 forage_dc=9 forage_food=1 fish_dc=11 margin_div=2 (the dice in TravelRules.ACTS, tried here).
## chain and levels also take upg=N (weapon upgrade ranks), ally=hunter,bushberry (more party pieces), ally_lag=2 (levels they are behind).
## chain and levels also take boss_hp=125 (% of the Lich's HP), boss_dmg=1, boss_armor=1.
## chain also takes route=pass|north|forest|farm (which fights, in order), xp0=270 (XP the hero starts with) and
## ally_at=210,60 (the hero's XP when each ally joined: they start at level 1 and earn the same XP from then on);
## chain also takes loot_pct=50 (scale the loot's food), meat_heal=1 (HP a meat portion heals), home=20 (morale a night at home gives), nights=2.
## Other key=value pairs override a levels.csv, combat.csv, camp.csv or morale.csv row for this run only.

const PARTIES := {
	"duo": [{"id": "hero", "eat": 1, "hunt": 0, "forage": 0, "fish": 0}, {"id": "dog", "eat": 1, "hunt": 2, "forage": 2, "fish": 0}],
	"trio": [{"id": "hero", "eat": 1, "hunt": 0, "forage": 0, "fish": 0}, {"id": "dog", "eat": 1, "hunt": 2, "forage": 2, "fish": 0},
		{"id": "hunter", "eat": 1, "hunt": 5, "forage": 0, "fish": 3}],
	"quad": [{"id": "hero", "eat": 1, "hunt": 0, "forage": 0, "fish": 0}, {"id": "dog", "eat": 1, "hunt": 2, "forage": 2, "fish": 0},
		{"id": "hunter", "eat": 1, "hunt": 5, "forage": 0, "fish": 3}, {"id": "wizard", "eat": 1, "hunt": 0, "forage": 1, "fish": 0}],
}
const PORTIONS_PER_FISH := 1.80  ## road spot: weights minnow 40 (1), perch 30 (2), trout 18 (2), pike 10 (4) over 98
const INGREDIENT_PER_FISH := 0.29

const ROUTES := {
	"pass": [],  # the parent's ORDER: the pass, the den, the crypt and the throne
	"north": [["snow_pass", "pass_wolves"], ["snow_pass", "pass_bandits"], ["wolf_den", "den_wolves"], ["wolf_den", "den_lone"]],
	"forest": [["forest_roads", "forest_bandits"], ["forest_roads", "forest_wolves"], ["forest_roads", "forest_ogre"]],
	"farm": [["farmland", "farm_bandits"]],
}

var _args := {}
var _order: Array = []  ## the fights of this run's route, in order
var _xp_now := -1  ## the hero's XP at the fight being built (-1 in `levels`, which has none)
var _rng := RandomNumberGenerator.new()
var _acts_cfg := {}  ## a copy of TravelRules.ACTS; hunt_dc=13, hunt_food=4, forage_dc=9 ... override it for this run
var _margin_div := 2  ## a win adds its margin over the DC divided by this (margin_div=0: no margin food)


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var mode := String(args[0]) if args.size() > 0 else "acts"
	for a in args.slice(1):
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		_args[kv[0]] = kv[1]
		if Db.levels.has(kv[0]):
			Db.levels[kv[0]] = float(kv[1])
		elif Db.camp.has(kv[0]):
			Db.camp[kv[0]] = float(kv[1])
		elif Db.morale.has(kv[0]):
			Db.morale[kv[0]] = float(kv[1])
		elif Db.combat.has(kv[0]):
			Db.combat[kv[0]] = float(kv[1])
	_acts_cfg = TravelRules.ACTS.duplicate(true)
	for act: String in _acts_cfg:
		for k in ["dc", "food", "medicine"]:
			if _args.has("%s_%s" % [act, k]):
				_acts_cfg[act][k] = int(_args["%s_%s" % [act, k]])
	_margin_div = int(_num("margin_div", 2))
	boss_hp = int(_num("boss_hp", 100))  # the Lich at this % of his HP, and this much more damage and armor (tried here, never written)
	boss_dmg = int(_num("boss_dmg", 0))
	boss_armor = int(_num("boss_armor", 0))
	if _args.has("meat_heal"):  # meat_heal=1: what one portion of meat heals (items.csv `heal`)
		Db.items["meat"]["heal"] = int(_args.meat_heal)
	match mode:
		"acts":
			_acts()
		"road":
			_road()
		"chain":
			_chain_mode()
		"levels":
			_levels_mode()


func _num(key: String, fallback: float) -> float:
	return float(_args.get(key, fallback))


# --- acts: exact odds -------------------------------------------------------------------------------------

func _act_row(act: String, bonus: int) -> Dictionary:
	var a: Dictionary = _acts_cfg[act]
	var wins := 0
	var food := 0.0
	for roll in range(1, 21):
		var total := roll + bonus
		if roll == 20 or (roll != 1 and total >= int(a.dc)):
			wins += 1
			food += int(a.food) + _margin(total - int(a.dc), int(a.food))
	return {"p": wins / 20.0, "food": food / 20.0, "med": wins / 20.0 * int(a.medicine)}


func _acts() -> void:
	print("## hunt, forage and the fish quick cast by the party's best bonus (exact, d20 + bonus vs DC; natural 20 wins, natural 1 fails)")
	print("| bonus | hunt win | hunt food a try | forage win | forage food a try | forage potion a try | fish roll win | fish roll food a try |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for b in range(-3, 8):
		var h := _act_row("hunt", b)
		var f := _act_row("forage", b)
		var s := _act_row("fish", b)
		print("| %+d | %d%% | %.2f | %d%% | %.2f | %.2f | %d%% | %.2f |" % [b, roundi(h.p * 100), h.food, roundi(f.p * 100), f.food, f.med, roundi(s.p * 100), s.food])
	print("")
	print("## the fishing minigame at the road spot: a landed fish is %.2f portions (and %.2f ingredient) on average; a cast that catches nothing is the empty hand" % [PORTIONS_PER_FISH, INGREDIENT_PER_FISH])
	print("| chance a cast lands a fish | portions a cast | empty-handed |")
	print("| --- | --- | --- |")
	for p in [0.3, 0.45, 0.6, 0.75, 0.9]:
		print("| %d%% | %.2f | %d%% |" % [roundi(p * 100), p * PORTIONS_PER_FISH, roundi((1.0 - p) * 100)])


# --- road: nights, food and morale on the overworld -----------------------------------------------------------

func _road() -> void:
	var trips := int(_num("trips", 2000))
	var party: Array = PARTIES[String(_args.get("party", "duo"))]
	var route := String(_args.get("route", "town,pass")).split(",")
	var ration := CampRules.ration(Db.camp_rations, String(_args.get("ration", "filling")))
	var camp := String(_args.get("camp", "first"))
	var evening := String(_args.get("evening", "mixed"))
	var s := {"nights": 0.0, "rough": 0.0, "eaten": 0.0, "found": 0.0, "hunts": 0.0, "empty": 0.0, "hungry": 0.0, "end_food": 0.0, "dry": 0.0,
		"min_m": 0.0, "low": 0.0, "fights": 0.0, "loot": 0.0, "gold": 0.0}
	for i in trips:
		_rng.seed = 1000 + i
		var r := _road_trip(party, route, ration, camp, evening)
		for k in s:
			s[k] += float(r.get(k, 0.0))
	var n := float(trips)
	print("## road: party %s (eats %d a day), route %s, ration %s, camp %s, evening %s, start food %d portions, %d trips" % [_args.get("party", "duo"),
		_need(party), ",".join(route), ration.id, camp, evening, int(_num("food", 12)), trips])
	print("| nights | rough camps | portions eaten | found by hunt, forage, fish | found on the road | empty-handed tries | food left | trips that ran dry | hungry nights | worst morale | trips with someone under 40 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	print("| %.2f | %.2f | %.1f | %.1f | %.1f | %d%% | %.1f | %d%% | %.2f | %.0f | %d%% |" % [s.nights / n, s.rough / n, s.eaten / n, s.found / n, s.loot / n,
		roundi(100.0 * s.empty / maxf(1.0, s.hunts)), s.end_food / n, roundi(100.0 * s.dry / n), s.hungry / n, s.min_m / n, roundi(100.0 * s.low / n)])


func _need(party: Array) -> int:
	var n := 0
	for m in party:
		n += int(m.eat)
	return n


## One walk along the route, camping by the policy. Returns the numbers the table prints.
func _road_trip(party: Array, route: Array, ration: Dictionary, camp: String, evening: String) -> Dictionary:
	var out := {"nights": 0, "rough": 0, "eaten": 0, "found": 0.0, "hunts": 0, "empty": 0, "hungry": 0, "end_food": 0, "dry": 0, "min_m": 100, "low": 0,
		"fights": 0, "loot": 0.0, "gold": 0.0}
	var food := int(_num("food", 12))
	var morale := {}
	for m in party:
		morale[m.id] = int(_num("morale", 70))
	var grace := int(_num("grace", 0)) == 1
	var nights_done := 0
	var since := 0.0
	var cfg: Dictionary = Db.camp
	for li in route.size() - 1:
		var p := TravelRules.path_between(Db.world_paths, route[li], route[li + 1])
		var seconds := float(p.get("seconds", 60))
		var sites := CampRules.leg_sites(p, String(route[li]))
		var stops := TravelRules.plan(_rng, seconds, int(p.get("enc_min", 1)), int(p.get("enc_max", 2)))
		var t := 0.0
		var si := 0
		var ei := 0
		while t < seconds - 0.001:
			var dusk := t + maxf(0.0, TravelRules.DAY_SECONDS - since)
			var site_t: float = float(sites[si].t) if si < sites.size() else INF
			var enc_t: float = float(stops[ei]) if ei < stops.size() else INF
			var t1 := minf(seconds, minf(dusk, minf(site_t, enc_t)))
			since += t1 - t
			t = t1
			var at_dusk := t >= dusk - 0.001
			var at_enc := ei < stops.size() and t >= enc_t - 0.001
			var at_site := si < sites.size() and t >= site_t - 0.001
			if at_dusk:  # the light ran out on the road: a rough camp
				food = _night(party, morale, food, ration, evening, Db.campsites.get("dark", {}), cfg, out, nights_done == 0 and grace)
				nights_done += 1
				out.rough += 1
				since = 0.0
			if at_enc:
				ei += 1
				_road_event(party, morale, out)
				food += int(out.get("_food", 0))
				out["_food"] = 0
			if at_site:
				var row: Dictionary = Db.campsites.get(String(sites[si].id), {})
				si += 1
				if not at_dusk and not at_enc and CampRules.ask_at(since) and _take_site(camp, String(row.get("id", "")), since):
					food = _night(party, morale, food, ration, evening, row, cfg, out, nights_done == 0 and grace)
					nights_done += 1
					since = 0.0
	# days on the explore maps: no camp there, so a cold meal a day (a proposal, map_days=3), with the fights' food (map_loot)
	# coming in and the meat eaten to heal (heal_need) going out, spread over those days
	var map_days := int(_num("map_days", 0))
	for d in map_days:
		food += int(_num("map_loot", 0)) / map_days
		var ate := mini(maxi(0, food), int(_num("heal_need", 0)) / map_days)
		food -= ate
		food = _night(party, morale, food, ration, "none", {"slots": -99}, cfg, out, false)
		nights_done += 1
	out.nights = nights_done
	out.end_food = food
	out.dry = 1 if food <= 0 else 0
	for m in party:
		out.min_m = mini(int(out.min_m), int(morale[m.id]))
		if int(morale[m.id]) < 40:
			out.low = 1
	return out


## Camp at this site? first: the first that asks; best: only a river or hilltop or ruins (a rough camp risked for it); every: all.
func _take_site(camp: String, id: String, since: float) -> bool:
	match camp:
		"every", "first":
			return true
		"best":
			return id in ["river", "hill", "ruins"] or since >= TravelRules.DAY_SECONDS * 0.8
		"dark":
			return false
	return true


## One night: the evening's actions, then the pot. Returns the food left.
func _night(party: Array, morale: Dictionary, food: int, ration: Dictionary, evening: String, site: Dictionary, cfg: Dictionary, out: Dictionary, free: bool) -> int:
	var slots := CampRules.slots_at(cfg, site)
	var plan := {"food": ["fish", "hunt", "forage", "rest", "talk"], "morale": ["rest", "cook", "talk", "forage", "hunt"],
		"mixed": ["hunt", "rest", "forage", "fish", "talk"], "none": []}[evening] as Array
	var free_act := String(site.get("free", ""))
	if free_act != "":
		food += _try_act(party, morale, free_act, site, out)
	var done := 0
	for id: String in plan:
		if done >= slots:
			break
		if id == "fish" and int(site.get("fish", 0)) != 1:
			continue
		if id == "rest":
			for m in party:
				morale[m.id] = mini(100, int(morale[m.id]) + int(Db.morale.get("camp", 10)))
		elif id == "cook":
			for m in party:
				morale[m.id] = mini(100, int(morale[m.id]) + int(cfg.get("hot_pot", 5)))
		elif id in ["hunt", "forage", "fish"]:
			food += _try_act(party, morale, id, site, out)
		done += 1
	var need := ceili(float(_need(party)) * float(ration.get("share", 100)) / 100.0)
	var took := mini(need, food)
	food -= took
	out.eaten += took
	var short := need - took if float(ration.get("share", 100)) > 0.0 else _need(party)
	var cost := int(ration.get("morale", 0))
	var hungry := false
	var order := party.duplicate()
	order.reverse()
	var left_short := short
	for m in order:  # the companions go hungry before the hero
		var miss := mini(left_short, int(m.eat)) if left_short > 0 else 0
		left_short -= miss
		if miss > 0:
			hungry = true
			if not free:
				morale[m.id] = maxi(0, int(morale[m.id]) + MoraleRules.hunger_loss(miss, int(m.eat), Db.morale))
		elif cost != 0 and not free:
			morale[m.id] = maxi(0, int(morale[m.id]) + cost)
	if int(site.get("morale", 0)) != 0 and not free:
		for m in party:
			morale[m.id] = maxi(0, int(morale[m.id]) + int(site.morale))
	out.hungry += 1 if hungry else 0
	return food


## A hunt, forage or fish try: the party's best roll (each member's skill plus their morale band). Returns food gained.
func _try_act(party: Array, morale: Dictionary, act: String, _site: Dictionary, out: Dictionary) -> int:
	out.hunts += 1
	if act == "fish":
		var p := _num("fishp", 0.6)
		if _rng.randf() < p:
			var n := int(round(PORTIONS_PER_FISH + _rng.randf_range(-1.0, 1.0)))
			out.found += maxi(1, n)
			return maxi(1, n)
		out.empty += 1
		return 0
	var a: Dictionary = _acts_cfg[act]
	var best := -99
	for m in party:
		best = maxi(best, int(m.get(act, 0)) + MoraleRules.check_mod(int(morale[m.id]), Db.morale_bands))
	var r := Dice.check(_rng, best, int(a.dc))
	if not r.success:
		out.empty += 1
		return 0
	var f := int(a.food) + _margin(int(r.total) - int(a.dc), int(a.food))
	out.found += f
	return f


func _margin(over: int, base_food: int) -> int:
	return maxi(0, over) / _margin_div if base_food > 0 and _margin_div > 0 else 0


## A road encounter by the travel_events weights; the player takes option 1 (fight, take, rummage, push on). The food it gives lands in out._food.
func _road_event(party: Array, morale: Dictionary, out: Dictionary) -> void:
	var pool: Array = Db.travel_events.filter(func(e: Dictionary) -> bool: return float(e.weight) > 0.0)
	var total := 0.0
	for e: Dictionary in pool:
		total += float(e.weight)
	var x := _rng.randf() * total
	var ev: Dictionary = pool[0]
	for e: Dictionary in pool:
		x -= float(e.weight)
		if x <= 0.0:
			ev = e
			break
	var o: Dictionary = ev.options[0]
	var win := true
	if String(o.check) not in ["none", "fight"]:
		var bonus := {"sneak": 1, "nerve": 2, "persuade": 1, "tame": 1}.get(String(o.check), 0) as int
		win = Dice.check(_rng, bonus, int(o.dc)).success
	var fx := String(o.win if win else o.lose)
	var food := 0
	for part in fx.split(";", false):
		var kv := part.split(":")
		if kv[0] == "food":
			food += int(kv[1])
		elif kv[0] == "gold":
			out.gold += float(int(kv[1]))
		elif kv[0] == "combat":
			out.fights += 1
			var enc: Dictionary = Db.encounters.get(kv[1], {})
			for lp in String(enc.get("loot", "")).split(";", false):
				var lkv := lp.split(":")
				if lkv[0] == "food":
					food += int(lkv[1])
				elif lkv[0] == "gold":
					out.gold += float(int(lkv[1]))
			for m in party:  # a won fight with nobody down: win morale
				morale[m.id] = mini(100, int(morale[m.id]) + int(Db.morale.get("win", 2)))
	out.loot += food
	out["_food"] = int(out.get("_food", 0)) + food


# --- chain: the pass trip through the real fight engine ------------------------------------------------------

func _setup_maps() -> void:
	_helper = load("res://tools/explore_balance_run.gd").new()
	_order = ROUTES.get(String(_args.get("route", "pass")), [])
	if _order.is_empty():
		_order = ORDER
	for name in ["snow_pass", "wolf_den", "crypt", "forest_roads", "farmland"]:
		var m := ExploreMap.load_named(name)
		_helper.call("_open_ways", m)
		_maps[name] = m


func _chain_mode() -> void:
	_setup_maps()
	foe_hp = int(_num("foe_hp", int(CombatRules.num("explore_foe_hp_pct"))))
	var runs := int(_num("runs", 40))
	var gap := float(_num("gap", 30))
	var heal := String(_args.get("heal", "none"))
	var attempts := int(_num("attempts", 6))
	var upg := int(_num("upg", 0))
	var keep := int(_num("keep", 4))
	var weapons := String(_args.get("weapons", "sword,daggers,bow")).split(",")
	print("## chain: route `%s` fight by fight (heal %s, keep %d portions back, weapon upgrade +%d, foes at %d%%, gap %.0f tiles, %d runs a weapon, a fall sends the party home with its levels and its morale)" % [String(_args.get("route", "pass")), heal, keep, upg, foe_hp, gap, runs])
	var per_fight := {}  # fight index -> [n, wins, hp lost %, xp]
	var tries := []
	var arrival := {"hp": 0.0, "n": 0, "lvl": 0.0, "food": 0.0}
	var early_falls := 0
	for w in weapons:
		var wins := {}
		for i in runs:
			var xp := int(_num("xp0", 0))
			var morale := 70
			var food0 := 12
			var at_throne := 0
			for attempt in attempts:
				var r := _trip(String(w), xp, morale, gap, heal, upg, keep, food0, i * 97 + attempt)
				xp = r.xp
				morale = r.morale
				for f in r.fights:
					var row: Array = per_fight.get(f.n, [0, 0, 0.0, 0.0])
					row[0] += 1
					row[1] += 1 if f.won else 0
					row[2] += float(f.lost)
					row[3] += float(f.xp)
					per_fight[f.n] = row
				morale = mini(100, morale + int(_num("home", 20)))  # the bed at home
				if not r.reached:
					early_falls += 1
				if r.reached:
					at_throne += 1
					var k := at_throne
					wins[k] = wins.get(k, [0, 0])
					wins[k][0] += 1
					wins[k][1] += 1 if r.won else 0
					if k == 1:
						arrival.hp += float(r.arrive_hp)
						arrival.n += 1
						arrival.lvl += float(r.level)
						arrival.food += float(r.food_left)
					if r.won:
						break
		tries.append([w, wins])
	print("| weapon | last fight of the route (the Lich on `pass`), try 1 | try 2 | try 3 | try 4 | try 5 |")
	print("| --- | --- | --- | --- | --- | --- |")
	for t in tries:
		var line := "| %s |" % t[0]
		for k in range(1, 6):
			var v: Array = t[1].get(k, [0, 0])
			line += " %s |" % ("%d%% (%d)" % [roundi(100.0 * v[1] / v[0]), v[0]] if v[0] > 0 else "-")
		print(line)
	print("")
	print("first arrival at the throne: HP %d%%, level %.1f, food left %.1f portions (%d runs); trips that fell before the throne: %.2f a run" % [roundi(arrival.hp / maxi(1, arrival.n)),
		arrival.lvl / maxi(1, arrival.n), arrival.food / maxi(1, arrival.n), arrival.n, float(early_falls) / maxf(1.0, float(runs * weapons.size()))])
	print("")
	print("| fight | group | fought | won | party HP lost a fight (% of max) | XP a win |")
	print("| --- | --- | --- | --- | --- | --- |")
	for n in _order.size():
		var row: Array = per_fight.get(n, [0, 0, 0.0, 0.0])
		if row[0] == 0:
			continue
		print("| %d | %s | %d | %d%% | %d%% | %.0f |" % [n + 1, _order[n][1], row[0], roundi(100.0 * row[1] / row[0]), roundi(row[2] / row[0]), row[3] / maxi(1, row[1])])


## One attempt from the village. heal: none, meat (eat the loot's meat between fights, 2 HP a portion) or both (and drink potions).
func _trip(weapon: String, xp0: int, morale0: int, gap: float, heal: String, upg: int, keep: int, food0: int, seed_i: int) -> Dictionary:
	var xp := xp0
	var morale := morale0
	var food := food0
	var meds := 0
	var state: Array = []
	var trickle := 0.0
	var out := {"won": false, "reached": false, "xp": xp, "morale": morale, "arrive_hp": 0, "level": 1, "food_left": 0, "fights": []}
	_rng.seed = seed_i * 31 + 7
	# the road out: two nights of food, and the morale the first ones cost under a FILLING pot are nothing; the sim only takes the food
	food -= int(_num("nights", 2)) * 2
	for n in _order.size():
		var m: ExploreMap = _maps[_order[n][0]]
		var g := {}
		for x: Dictionary in m.groups:
			if x.id == _order[n][1]:
				g = x
		var last_fight: bool = n == _order.size() - 1
		trickle += gap / maxf(1.0, float(Db.levels.get("trickle_steps", 10)))
		while trickle >= 1.0:
			trickle -= 1.0
			for s in state:
				if not s.full and s.res < s.res_max:
					s.res += 1
		var level := _level(xp)
		_xp_now = xp
		var party: Array = _party_for(level, weapon, upg)
		for i in party.size():
			var u: CombatUnit = party[i]
			var mods := MoraleRules.fight_mods(morale, Db.morale_bands)
			u.damage = maxi(1, u.damage + int(mods.get("damage", 0)))
			u.armor = maxi(0, u.armor + int(mods.get("defense", 0)))
			if i >= state.size():
				state.append({"hp": u.max_hp, "max": u.max_hp, "res": u.res_max, "tick": 0, "full": true, "res_max": u.res_max})
			var s: Dictionary = state[i]
			u.hp = clampi(int(s.hp) + (u.max_hp - int(s.max)), 1, u.max_hp)
			s["max"] = u.max_hp
			s["res_max"] = u.res_max
			if u.res_kind in ["mana", "charges"] and not s.full:
				u.res = clampi(int(s.res), 0, u.res_max)
				u.res_tick = int(s.tick)
		var hp_before := _unit_pct(party)
		if last_fight:
			out.reached = true
			out.level = level
			out.arrive_hp = roundi(hp_before)
			out.food_left = food
		var r := _fight2(m, g, party, state, seed_i * 31 + n)
		var won: bool = r.winner == 0
		var rec := {"n": n, "won": won, "lost": 0.0, "xp": 0}
		if not won:
			out.fights.append(rec)
			out.xp = xp
			morale = maxi(0, morale - 25)  # everyone down: the down cost, the bleed-out and the wipe
			out.morale = morale
			return out
		if last_fight:
			out.won = true
		var gain := LevelRules.fight_xp(int(r.foes), bool(g.get("boss", false)), Db.levels)
		if bool(g.get("elite", false)):
			gain = gain * int(CombatRules.num("elite_xp_pct")) / 100
		xp += gain
		out.xp = xp
		rec.xp = gain
		var hp_after := _hp_pct(state, party)
		rec.lost = hp_before - hp_after
		morale = mini(100, morale + (int(Db.morale.get("big_win", 5)) if bool(g.get("boss", false)) else int(Db.morale.get("win", 2))))
		out.fights.append(rec)
		# the loot's food and potions
		for lp in String(g.get("loot", "")).split(";", false):
			var kv := lp.split(":")
			if kv[0] == "food":
				food += roundi(int(kv[1]) * _num("loot_pct", 100) / 100.0)
			elif kv[0] == "medicine":
				meds += int(kv[1])
		if heal != "none":
			food = _eat_between(state, party, food, keep)
			if heal == "both":
				meds = _drink_between(state, party, meds)
		out.morale = morale
	return out


## One fight as the game sets it up (ExploreScene): elites get the elite numbers, ordinary groups the road's HP cut, a boss its
## hand-tuned numbers (and this run's boss_hp, boss_dmg, boss_armor), and a unit with `char` is that character on the foes' side
## (Bushberry beside the ogre). The carried HP and bars are stored back into `state`, as the outing sim's _fight does.
func _fight2(m: ExploreMap, g: Dictionary, party: Array, state: Array, seed_i: int) -> Dictionary:
	var grid := m.grid
	var enemies: Array = []
	var boss := bool(g.get("boss", false))
	var elite := bool(g.get("elite", false))
	for e: Dictionary in g.units:
		var u: CombatUnit
		if e.has("char"):
			u = CombatUnit.from_def(Db.character(StringName(e.char)))
			u.team = 1
		else:
			var cls := Db.class_def(e.id)
			var mods := LevelRules.merge(ExploreRules.elite_mods() if elite else {},
				ExploreRules.depth_mods(m.map_name, ExploreRules.group_depth(m.level, g), String(g.id), g.units.find(e), cls))
			if not elite and not boss and foe_hp != 100:
				mods["hp_pct"] = foe_hp
			if boss and g.units.find(e) == 0:
				mods["hp_pct"] = int(mods.get("hp_pct", 100)) * boss_hp / 100
				mods["damage"] = int(mods.get("damage", 0)) + boss_dmg
			u = CombatUnit.enemy(cls, mods)
			u.elite = elite
			if boss and g.units.find(e) == 0:
				u.armor += boss_armor
		u.place(e.cell, grid.height_at(e.cell))
		u.summon_cells = g.get("summon", [] as Array[Vector2i])
		for c in g.get("exit", []):
			u.summon_avoid[Vector2i(int(c[0]), int(c[1]))] = true
		enemies.append(u)
	var cells: Array = enemies.map(func(u: CombatUnit) -> Vector2i: return u.cell)
	var blocked := {}
	for c in cells:
		blocked[c] = true
	var path := ExploreRules.find_path(grid, m.start[0], _helper.call("_near", grid, cells[0], blocked), 2, blocked)
	var at: Vector2i = m.start[0]
	for c in path:
		at = c
		if ExploreRules.sees(grid, [c], cells, ExploreRules.PARTY_SIGHT) or ExploreRules.sees(grid, cells, [c], int(g.sight)):
			break
	for u: CombatUnit in party:
		u.place(at, grid.height_at(at))
	var spots := ExploreRules.auto_deploy(grid, party, "party", blocked)
	var units: Array = []
	for u: CombatUnit in party:
		if spots.has(u):
			u.place(spots[u], grid.height_at(spots[u]))
			units.append(u)
	units.append_array(enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 7919 + 13
	CombatUnit.pack_belts(units, {})
	for u: CombatUnit in units:
		var carried: bool = u.team == 0 and u.res_kind in ["mana", "charges"] and not state[party.find(u)].full
		if not carried:
			u.reset_resource()
	var rounds := 0
	var winner := -1
	while rounds < CombatSim.MAX_ROUNDS and winner < 0:
		rounds += 1
		for team in [0, 1]:
			var w := CombatSim.run_phase(rng, grid, units, team)
			if w >= 0:
				winner = w
				break
	for i in party.size():
		var u: CombatUnit = party[i]
		var s: Dictionary = state[i]
		s.hp = maxi(1, u.hp)
		if u.res_kind in ["mana", "charges"]:
			s.res = u.res
			s.tick = u.res_tick
			s.full = false
	return {"winner": winner, "foes": enemies.filter(func(u: CombatUnit) -> bool: return not u.alive()).size(), "rounds": rounds}


## The hero and Doggo as the outing sim builds them, with the hero's weapon upgrades (+1 damage a rank) and the allies named in `ally=hunter,bushberry`.
func _party_for(level: int, weapon: String, upg: int) -> Array:
	var party: Array = _helper.call("_party", level, weapon)
	(party[0] as CombatUnit).damage += upg
	var ids := String(_args.get("ally", "")).split(",", false)
	var at := String(_args.get("ally_at", "")).split(",", false)
	for i in ids.size():
		var id := ids[i]
		var d := Db.character(StringName(id))
		# a recruit joins at level 1 and earns the same XP as the hero from then on (Game.award_xp): ally_at is the hero's XP when each joined
		var lv := maxi(1, level - int(_num("ally_lag", 0)))
		if i < at.size() and _xp_now >= 0:
			lv = _level(maxi(0, _xp_now - int(at[i])))
		party.append(CombatUnit.from_def(d, LevelRules.bonus(_helper.call("_rolled", id, lv), Db.levels)))
	return party


func _unit_pct(party: Array) -> float:
	var now := 0.0
	var mx := 0.0
	for u: CombatUnit in party:
		now += float(u.hp)
		mx += float(u.max_hp)
	return 100.0 * now / maxf(1.0, mx)


func _hp_pct(state: Array, party: Array) -> float:
	var now := 0.0
	var mx := 0.0
	for i in party.size():
		now += float(state[i].hp)
		mx += float((party[i] as CombatUnit).max_hp)
	return 100.0 * now / maxf(1.0, mx)


## Eat meat (2 HP a portion) on the most hurt piece until nobody is hurt or only `keep` portions are left.
func _eat_between(state: Array, party: Array, food: int, keep: int) -> int:
	var heal_each := int(Db.items.get("meat", {}).get("heal", 2))
	while food > keep:
		var worst := -1
		var gap := 0
		for i in party.size():
			var g := (party[i] as CombatUnit).max_hp - int(state[i].hp)
			if g > gap:
				gap = g
				worst = i
		if worst < 0:
			break
		state[worst].hp = mini((party[worst] as CombatUnit).max_hp, int(state[worst].hp) + heal_each)
		food -= 1
	return food


## Drink a potion (5 HP) on any piece under 40% HP.
func _drink_between(state: Array, party: Array, meds: int) -> int:
	while meds > 0:
		var pick := -1
		for i in party.size():
			if float(state[i].hp) < 0.4 * (party[i] as CombatUnit).max_hp:
				pick = i
		if pick < 0:
			break
		state[pick].hp = mini((party[pick] as CombatUnit).max_hp, int(state[pick].hp) + 5)
		meds -= 1
	return meds


# --- levels: the Lich from arrival HP at each level ------------------------------------------------------

func _levels_mode() -> void:
	_setup_maps()
	var n := int(_num("fights", 30))
	var lvls := String(_args.get("lvls", "3,5,7,9,12")).split(",")
	var m: ExploreMap = _maps["crypt"]
	var g := {}
	for x: Dictionary in m.groups:
		if x.id == "throne":
			g = x
	print("## the Lich from arrival HP by level (resources full, %d fights a cell): win %%" % n)
	for weapon in ["sword", "daggers", "bow"]:
		print("| %s | HP 40%% | 60%% | 80%% | 100%% |" % weapon)
		print("| --- | --- | --- | --- | --- |")
		for lv in lvls:
			var line := "| level %s |" % lv
			for hp_pct in [40, 60, 80, 100]:
				var wins := 0
				for i in n:
					var party: Array = _party_for(int(lv), weapon, int(_num("upg", 0)))
					var state: Array = []
					for u: CombatUnit in party:
						state.append({"hp": maxi(1, roundi(u.max_hp * hp_pct / 100.0)), "max": u.max_hp, "res": u.res_max, "tick": 0, "full": true, "res_max": u.res_max})
					for k in party.size():
						(party[k] as CombatUnit).hp = state[k].hp
					wins += 1 if _fight2(m, g, party, state, i).winner == 0 else 0
				line += " %d%% |" % roundi(100.0 * wins / n)
			print(line)
