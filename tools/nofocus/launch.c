// Starts Claude's private Godot copy with nofocus.dylib loaded. A small binary of our own sets the
// variable, because macOS strips DYLD_* variables when they pass through system tools like bash.
// Usage: launch <godot binary> <dylib> <godot args...>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv) {
	if (argc < 3) { fprintf(stderr, "usage: launch <godot> <dylib> [args...]\n"); return 2; }
	setenv("DYLD_INSERT_LIBRARIES", argv[2], 1);
	argv[2] = argv[1];
	execv(argv[1], argv + 2);
	perror("execv");
	return 127;
}
