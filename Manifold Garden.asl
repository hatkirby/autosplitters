// AutoSplit script for Manifold Garden
//
// Written by hatkirby, with help from preshing and Gelly.
//
// Automatically starts the timer when a new game is started. You must still
// reset the timer manually between runs.
//
// A split is also triggered after being in one of the ending cutscenes for 1.1
// seconds, since this is when the kaleidoscope appears.
//
// If you check "All God Cubes waypoints" in the script's Advanced settings
// (below), the script will only split at mandala scenes. This is useful when
// running "All God Cubes" categories.
//
// This should be mostly version-independent, but it works best on 1.0.0.14704
// (Steam "Speedrunning Branch").
//
// To view debug output (print statements from this script), use DebugView:
// https://technet.microsoft.com/en-us/Library/bb896647.aspx

state("ManifoldGarden") {}

startup {
    var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
    var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
    vars.Helper = Activator.CreateInstance(type, timer, this);
    vars.Helper.LoadSceneManager = true;

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
    vars.inEnding = false;
    vars.noSplitScenes = new List<String>{
        "StudioLogoScreen",
        "RequiredComponents",
        "StartScreen_01",
        "StartScreen_02",
        "StartScreen_03",
        "StartScreen_15",
        "StartScreen_51",
        "StartScreen_53",
        "StartScreen_63"
    };
    vars.startScreens = new List<String>{
        "StartScreen_01",
        "StartScreen_02",
        "StartScreen_03",
        "StartScreen_15",
        "StartScreen_51",
        "StartScreen_53",
        "StartScreen_63"
    };
    vars.endings = new List<string>{
        "World_905_EndingCollapseCutscene_Optimized",
        "World_907_EndingZeroCollapseCutscene_Optimized",
        "World_906_EndingDarkCollapseCutscene_Optimized"
    };
    vars.fall = new List<string>{
        "World_903_EndingFallTwo_Optimized",
        "World_904_EndingFallThree_Optimized",
        "World_905_EndingCollapseCutscene_Optimized",
        "World_923_AlternateEndingFallTwo_Optimized",
        "World_924_AlternateEndingFallThree_Optimized",
        "World_907_EndingZeroCollapseCutscene_Optimized",
        "World_906_EndingDarkCollapseCutscene_Optimized"
    };
    vars.mandalaScenes = new List<string>{
        "AudioVisual_001_Optimized",
        "AudioVisual_002_Optimized",
        "AudioVisual_053_Optimized",
        "AudioVisual_051_Optimized",
        "AudioVisual_003_Optimized",
        "AudioVisual_063_Optimized",
        "AudioVisual_071_Optimized"
    };
    vars.zeroPercentPoints = new List<string>{
        "Hallway_W000_W052_Optimized",
        "World_002_Optimized",
        "Hallway_W026_W015_Optimized",
        "Hallway_W612_W057_Optimized",
        "Hallway_W073_W026_Optimized",
        "World_804_Optimized",
        "World_071_AkshardhamTemple_Optimized"
    };
}

init {
    vars.studioScreenDone = true;
    vars.doneFirstLook = false;
    vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono =>
    {
        var gameMan = mono.GetClass("GameManager");
        vars.Helper["isLoadingGameFromUI"] = gameMan.Make<bool>("isLoadingGameFromUI");

        var versionNum = mono.GetClass("VersionNumber");
        vars.Helper["version"] = versionNum.MakeString("instance", "_text");

        current.onStartScreen = false;

        return true;
    });

    vars.Helper.Load();
}

update {
    if (!vars.Helper.Update())
		return false;

    current.level = vars.Helper.Scenes.Active.Index;
    current.isLoadingGameFromUI = vars.Helper["isLoadingGameFromUI"].Current;

    if (!vars.doneFirstLook) {
        vars.doneFirstLook = true;
        print(String.Format("Connected to Manifold Garden version {0}", vars.Helper["version"].Current));

        current.onStartScreen = vars.startScreens.Contains(vars.Helper.Scenes.Active.Name);

        // The "isLoadingGameFromUI" boolean is set while the studio screen is
        // showing during game startup, which means that if the autosplitter is
        // running before the game opens, it'll erroneously start a run. To
        // avoid this, when the autosplitter initialises, we check if we are on
        // a noSplitScene (the game usually reports itself as being on a start
        // screen rather than the studio screen) and if the game is loading. If
        // so, we disable starting a run until the load is complete. If the
        // splitter is opened after the game starts up, this shouldn't activate,
        // which means run starting should work as expected.
        if (vars.noSplitScenes.Contains(vars.Helper.Scenes.Active.Name)
            && current.isLoadingGameFromUI) {
            vars.studioScreenDone = false;
        }
    } else {
        if (current.level != old.level) {
            current.onStartScreen = vars.startScreens.Contains(vars.Helper.Scenes.Active.Name);
        }
        if (!vars.studioScreenDone) {
            vars.studioScreenDone = !current.isLoadingGameFromUI;
        }
    }
}

start {
    // Start the timer as soon as a game is being loaded (specifically the
    // moment you click a save slot to start a new game in, although it will
    // also start if you just load a file). This boolean is set to true during
    // the studio logo when the game starts up, so we check for that as well.
    if (vars.studioScreenDone && current.isLoadingGameFromUI) {
        print(String.Format("Level changed from {0} to {1}: START", old.level, current.level));
        if (settings["zero"]) {
            vars.waypoints = vars.zeroPercentPoints;
        } else if (settings["allGodCubes"]) {
            vars.waypoints = vars.mandalaScenes;
        } else {
            vars.waypoints = null;
        }
        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        vars.prev.Clear();
        vars.firstRoom = false;
        vars.inEnding = false;
        return true;
    }
}

split {
    // Split when level index changes. We don't split for the first room change
    // in a run, because that is always going to be changing from 3 to 73, and
    // it happens a couple of seconds after the timer starts.
    if (vars.firstRoom
        && current.level != vars.prevLevel
        && current.level > 0
        && !vars.noSplitScenes.Contains(vars.Helper.Scenes.Active.Name)) {
        print(String.Format("{0}: '{1}'", current.level, vars.Helper.Scenes.Active.Name));

        string action = "NO SPLIT";

        if (vars.prevLevel != 0) {
            // Split rules:
            if (settings["every"]) {
                if (settings["fall"] || !vars.fall.Contains(vars.Helper.Scenes.Active.Name)) {
                    action = "SPLIT";
                }
            } else if (vars.waypoints != null) {
                if (vars.waypoints.Contains(vars.Helper.Scenes.Active.Name)) {
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

        if (vars.endings.Contains(vars.Helper.Scenes.Active.Name)) {
            vars.inEnding = true;
        }

        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        return action.StartsWith("SPLIT");
    } else if (!vars.firstRoom && vars.Helper.Scenes.Active.Name == "World_000_Optimized") {
        vars.firstRoom = true;
        vars.prevLevel = current.level;
        vars.prev.Add(current.level);
    }

    // Final split of the game:
    // Split after being in one of the ending cutscenes for 1.1 seconds.
    if (settings["raymarchitecture"]
        && vars.inEnding
        && vars.stopwatch != null
        && vars.stopwatch.ElapsedMilliseconds >= 1100) {
        print("SPLIT on Raymarchitecture");
        vars.stopwatch = null;
        return true;
    }
}

reset {
    return current.onStartScreen && !old.onStartScreen;
}

exit
{
	vars.Helper.Dispose();
}

shutdown
{
	vars.Helper.Dispose();
}
