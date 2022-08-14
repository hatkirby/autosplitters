// AutoSplit script for Manifold Garden 1.0.30.14704
//
// Written by hatkirby, with a lot of help from preshing and Gelly.
//
// Automatically starts the timer ~2.4 seconds after starting a new game, and splits the timer
// when transitioning between game levels. You must still reset the timer manually between runs.
// If you accidentally backtrack through a portal, causing an unwanted split, you'll have
// to undo it manually (default NumPad8 in LiveSplit).
//
// To compensate for the late start, you should delay your start timer by 2.4 seconds in LiveSplit.
// (Right-click -> Edit Splits -> Start timer at:)
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
    // This pointer path seems to work with Manifold Garden 1.1.0.14704 (2020-11-09):
    int level: "UnityPlayer.dll", 0x01800AB8, 0x10, 0xB8, 0x10, 0x28, 0x18, 0x60, 0x7CC;

    // This pointer path seems to work with Manifold Garden 1.0.30.13294 (2020-02-25):
    //int level: "UnityPlayer.dll", 0x014BE300, 0x60, 0xA8, 0x38, 0x30, 0xB0, 0x118, 0x5C;
    
    // These ones also seem to work with version 13294, and can be tried as backups in case
    // the one above stops working:
    //int level:  "UnityPlayer.dll", 0x01552858, 0x8, 0x0, 0xB8, 0x80, 0x80, 0x28, 0x5C;
    //int level:  "UnityPlayer.dll", 0x01552858, 0x28, 0x8, 0xB8, 0x80, 0x80, 0x28, 0x5C;

    // This pointer path worked with Manifold Garden 1.0.29.12904 (2020-02-??)
    //                             & Manifold Garden 1.0.29.12830 (2019-12-18)
    //                             & Manifold Garden 1.0.29.12781 (2019-12-11):
    //int level: "UnityPlayer.dll", 0x01507BE0, 0x0, 0x928, 0x38, 0x30, 0xB0, 0x118, 0x5C;

    // This pointer path worked with older versions:
    //int level: "UnityPlayer.dll", 0x01507C68, 0x8, 0x38, 0xA8, 0x58, 0x118, 0x5C;
}

startup {
    settings.Add("allGodCubes", false, "All God Cubes waypoints");
    settings.Add("zero", false, "Zero% waypoints");
    settings.Add("norepeats",false,"Split only on the first encounter of each level");
    vars.waypoints = null;
    vars.prevLevel = 0;
    vars.seqIndex = 0;
    vars.stopwatch = null;  // Used for the final split
    vars.prev = new List<int>();
    vars.prev.Add(9);
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
    if (old.level == -1 && current.level == 9) {
        print(String.Format("Level changed from {0} to {1}: START", old.level, current.level));
        if (settings["zero"]) {
            vars.waypoints = new List<int>{106, 17, 110, 115, 111, 36, 44};
        } else {
            vars.waypoints = null;
        }
        vars.prevLevel = 9;
        vars.seqIndex = 0;
        vars.stopwatch = Stopwatch.StartNew();
        vars.prev.Clear();
        vars.prev.Add(current.level);
        return true;
    }
}

split {
    // Split when level index changes, but avoid splitting during a loading screen
    // or when the pointer path stops working:
    if (current.level != vars.prevLevel && current.level >= 0) {
        string action = "NO SPLIT";

        // Ignore the split rules when script is reloaded mid-game:
        if (vars.prevLevel != 0) {
            // Split rules:
            if (vars.waypoints == null) {
                if (settings["allGodCubes"]) {
                    if (current.level >= 82 && current.level <= 88) {
                        action = "SPLIT";
                    }
                } else {
                    action = "SPLIT";
                }
            } else if (vars.seqIndex < vars.waypoints.Count) {
                if (current.level == vars.waypoints[vars.seqIndex]) {
                    vars.seqIndex++;
                    action = String.Format("SPLIT (new seqIndex = {0})", vars.seqIndex);
                } else {
                    action = String.Format("NO SPLIT (seqIndex = {0}, {1} expected)",
                        vars.seqIndex, vars.waypoints[vars.seqIndex]);
                }
            } else {
                action = String.Format("NO SPLIT (seqIndex = {0}, end of waypoint sequence)", vars.seqIndex);
            }

            print(String.Format("Level changed from {0} to {1}: {2}", vars.prevLevel, current.level, action));

            if (settings["norepeats"]) {
                if (vars.prev.Contains(current.level)) {
                    action = "NO SPLIT";
                }
                vars.prev.Add(current.level);
            }
        }

        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        return action.StartsWith("SPLIT");
    }

    // Final split of the game:
    // Split after being in one of the ending cutscenes for 1.1 seconds.
    if ((current.level == 99 || current.level == 103 || current.level == 104)
        && vars.stopwatch != null
        && vars.stopwatch.ElapsedMilliseconds >= 1100) {
        vars.stopwatch = null;
        return true;
    }
}
