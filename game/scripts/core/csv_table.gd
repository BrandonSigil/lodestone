class_name CsvTable
extends RefCounted
## Reads a data CSV (imported with "keep") into an array of row dictionaries.


static func load_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CsvTable: can't open %s" % path)
		return rows
	var header := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size() or line[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i].strip_edges()
		rows.append(row)
	return rows
