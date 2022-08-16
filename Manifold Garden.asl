// AutoSplit script for Manifold Garden 1.0.30.14704
//
// Written by hatkirby, with help from preshing and Gelly.
//
// Automatically starts the timer when a new game is started. You must still reset the timer
// manually between runs.
//
// A split is also triggered after being in one of the ending cutscenes for 1.1 seconds,
// since this is when the kaleidoscope appears.
//
// If you check "All God Cubes waypoints" in the script's Advanced settings (below), the script
// will only split at mandala scenes. This is useful when running "All God Cubes" categories.
//
// The pointer path to the current level often changes when a new version of Manifold Garden is
// released. When that happens, a new pointer path must be found using CheatEngine. If the
// current pointer path stops working (even for a frame or two), a message is logged to the
// debug output.
//
// To view debug output (print statements from this script), use DebugView:
// https://technet.microsoft.com/en-us/Library/bb896647.aspx

state("ManifoldGarden") {
    // These pointer paths seem to work with Manifold Garden 1.1.0.14704 (2020-11-09):
    int level: "mono-2.0-bdwgc.dll", 0x00494DC8, 0x48, 0x120, 0x120, 0x120, 0x120, 0x120, 0xC60, 0x1A0;
    bool transitionFadeHeld: "UnityPlayer.dll", 0x017945A8, 0x80, 0x10, 0x48, 0xA0, 0x10, 0xE40;
    bool isLoadingGameFromUI: "UnityPlayer.dll", 0x017945A8, 0x90, 0x100, 0xC0, 0xC0, 0xC0, 0xC0, 0xDC1;
    bool startScreenActive: "UnityPlayer.dll", 0x0178BBC0, 0x3B8, 0x38, 0x18, 0x8, 0x198, 0x0, 0x8ab;

    // Older pointer paths:
    //int level: "UnityPlayer.dll", 0x014BE300, 0x60, 0xA8, 0x38, 0x30, 0xB0, 0x118, 0x5C; // 1.0.30.13294 (2020-02-25)
    //int level:  "UnityPlayer.dll", 0x01552858, 0x8, 0x0, 0xB8, 0x80, 0x80, 0x28, 0x5C; // 13294
    //int level:  "UnityPlayer.dll", 0x01552858, 0x28, 0x8, 0xB8, 0x80, 0x80, 0x28, 0x5C; // 13294
    //int level: "UnityPlayer.dll", 0x01507BE0, 0x0, 0x928, 0x38, 0x30, 0xB0, 0x118, 0x5C; //  1.0.29.12904 (2020-02-??), 1.0.29.12830 (2019-12-18), 1.0.29.12781 (2019-12-11)
    //int level: "UnityPlayer.dll", 0x01507C68, 0x8, 0x38, 0xA8, 0x58, 0x118, 0x5C;
}

startup {
    settings.Add("every",true,"Split on every level change");
    settings.Add("fall",false,"Including all ending falling scenes","every");
    settings.Add("allGodCubes", false, "All God Cubes waypoints");
    settings.Add("zero", false, "Zero% waypoints");
    settings.Add("raymarchitecture", true, "Split on Raymarchitecture (ending cutscene)");
    settings.Add("norepeats",false,"Split only on the first encounter of each level");
    vars.waypoints = null;
    vars.prevLevel = 0;
    vars.stopwatch = null;  // Used for the final split
    vars.prev = new List<int>();
    vars.firstRoom = false;
    vars.fall = new List<int>{97, 98, 99, 101, 102, 103, 104};
}

init {
    print(String.Format("**** AUTOSPLIT: Game found, pointer path {0} ****",
        current.level == 0 ? "DOESN'T work (this is normal at startup)" : "works"));
}

update {
    // Log a message when the pointer path starts/stops working:
    if (current.level == 0 && old.level != 0) {
        print("**** AUTOSPLIT: Pointer path STOPPED working ****");
    } else if (current.level != 0 && old.level == 0) {
        print("**** AUTOSPLIT: Pointer path STARTED working ****");
    }
}

start {
    // Start the timer as soon as a game is being loaded (specifically the moment you click
    // a save slot to start a new game in, although it will also start if you just load a file).
    // This boolean is set to true during the studio logo when the game starts up, so we check
    // for that as well.
    if (current.transitionFadeHeld && current.isLoadingGameFromUI) {
        print(String.Format("Level changed from {0} to {1}: START", old.level, current.level));
        if (settings["zero"]) {
            vars.waypoints = new List<int>{106, 17, 110, 115, 111, 36, 44};
        } else if (settings["allGodCubes"]) {
            vars.waypoints = new List<int>{82, 83, 84, 85, 86, 87, 88};
        } else {
            vars.waypoints = null;
        }
        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        vars.prev.Clear();
        vars.firstRoom = false;
        return true;
    }
}

split {
    // Split when level index changes. We don't split for the first room change in a run,
    // because that is always going to be changing from -1 to 9, and it happens a couple of
    // seconds after the timer starts.
    if (vars.firstRoom && current.level != vars.prevLevel && current.level > 0) {
        string action = "NO SPLIT";

        // Ignore the split rules when script is reloaded mid-game:
        if (vars.prevLevel != 0) {
            // Split rules:
            if (settings["every"]) {
                if (settings["fall"] || !vars.fall.Contains(current.level)) {
                    action = "SPLIT";
                }
            } else if (vars.waypoints != null) {
                if (vars.waypoints.Contains(current.level)) {
                    action = "SPLIT";
                }
            }

            if (settings["norepeats"]) {
                if (vars.prev.Contains(current.level)) {
                    action = "NO SPLIT";
                }
                vars.prev.Add(current.level);
            }

            print(String.Format("Level changed from {0} to {1}: {2}", vars.prevLevel, current.level, action));
        }

        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        return action.StartsWith("SPLIT");
    } else if (!vars.firstRoom && current.level == 9) {
        vars.firstRoom = true;
        vars.prevLevel = current.level;
        vars.prev.Add(9);
    }

    // Final split of the game:
    // Split after being in one of the ending cutscenes for 1.1 seconds.
    if (settings["raymarchitecture"]
        && (current.level == 99 || current.level == 103 || current.level == 104)
        && vars.stopwatch != null
        && vars.stopwatch.ElapsedMilliseconds >= 1100) {
        print("SPLIT on Raymarchitecture");
        vars.stopwatch = null;
        return true;
    }
}

reset {
    return current.startScreenActive;
}
