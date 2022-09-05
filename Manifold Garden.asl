// AutoSplit script for Manifold Garden
//
// Written by hatkirby, with help from preshing, Gelly, and darkid.
//
// Automatically starts the timer when a new game is started. You must still
// reset the timer manually between runs.
//
// A split is also triggered after being in one of the ending cutscenes for 1.1
// seconds, since this is when the kaleidoscope appears.
//
// The following options are mutually exclusive:
// - Split on every level change
// - All God Cubes waypoints
// - Zero% waypoints
// - Split based on a configuration file
//
// If you want to customize which levels the autosplitter splits at, create a
// file with a .mg_config extension and put it in the same directory as your
// splits. This file should contain a list of level names, one per line. These
// level names must exactly match the names shown in-game using the
// toggle_beta_message feature.
//
// This should be mostly version-independent, but it works best on 1.0.0.14704
// (Steam "Speedrunning Branch").
//
// To view debug output (print statements from this script), use DebugView:
// https://technet.microsoft.com/en-us/Library/bb896647.aspx

state("ManifoldGarden") {}

startup {
    // Relative to Livesplit.exe
    vars.logFilePath = Directory.GetCurrentDirectory() + "\\autosplitter_manifold.log";
    vars.log = (Action<string>)((string logLine) => {
        print("[Manifold Garden ASL] " + logLine);
        string time = System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss.fff");
        // AppendAllText will create the file if it doesn't exist.
        System.IO.File.AppendAllText(vars.logFilePath, time + ": " + logLine + "\r\n");
    });

    var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
    var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
    vars.Helper = Activator.CreateInstance(type, timer, this);
    vars.Helper.LoadSceneManager = true;

    settings.Add("raymarchitecture", true, "Split on Raymarchitecture (ending cutscene)");
    settings.Add("norepeats",false,"Split only on the first encounter of each level");
    settings.Add("gravChanges",false, "Override first text component with a Gravity Changes count");
    settings.Add("every",true,"Split on every level change");
    settings.Add("fall",false,"Including all ending falling scenes","every");
    settings.Add("allGodCubes", false, "All God Cubes waypoints");
    settings.Add("zero", false, "Zero% waypoints");

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

    vars.configFiles = null;
    vars.settings = settings;
    var findConfigFiles = (Action<string>)((string folder) => {
        var files = new List<string>();
        if (folder != null) {
            vars.log("Searching for config files in '" + folder + "'");
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.mg_config"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.mg_config.txt"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.mg_conf"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.mg_confi"));
            vars.log("Found " + files.Count + " config files");
        }

        // Only add the parent setting the first time we call this function
        if (vars.configFiles == null) {
            vars.configFiles = new Dictionary<string, string>();
            vars.settings.Add("configs", (files.Count > 0), "Split based on configuration file:");
        }

        foreach (var file in files) {
            string fileName = file.Split('\\').Last();
            if (vars.configFiles.ContainsKey(fileName)) continue;
            vars.configFiles[fileName] = file;
            vars.settings.Add(fileName, false, null, "configs");
        }
    });
    // Search for config files relative to LiveSplit.exe
    findConfigFiles(Directory.GetCurrentDirectory());
    // Search for config files relative to the current layout
    findConfigFiles(System.IO.Path.GetDirectoryName(timer.Layout.FilePath));
    // Search for config files relative to the current splits
    findConfigFiles(System.IO.Path.GetDirectoryName(timer.Run.FilePath));

    vars.log("Autosplitter loaded");
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

        var rigidCon = mono.GetClass("RigidbodyController");
        vars.Helper["gravity"] = gameMan.Make<int>("playerController", rigidCon["_gravityDirection"]);

        current.onStartScreen = false;
        current.onMandalaScene = false;

        return true;
    });

    vars.Helper.Load();

    vars.configWaypoints = null;
    if (settings["configs"]) {
        string[] lines = {""};
        foreach (var configFile in vars.configFiles.Keys) {
            if (settings[configFile]) {
                // Full path is saved in the dictionary.
                vars.configWaypoints = System.IO.File.ReadAllLines(vars.configFiles[configFile]);
                vars.log("Selected config file: " + configFile);
                vars.log("Config contains " + vars.configWaypoints.Length + " lines");
                break;
            }
        }
    }

    vars.updateText = false;
    if (settings["gravChanges"]) {
        foreach (LiveSplit.UI.Components.IComponent component in timer.Layout.Components) {
            if (component.GetType().Name == "TextComponent") {
                vars.tc = component;
                vars.tcs = vars.tc.Settings;
                vars.updateText = true;
                vars.log("Found text component at " + component);
                break;
            }
        }
    }
}

update {
    if (!vars.Helper.Update())
		return false;

    current.level = vars.Helper.Scenes.Active.Index;
    current.isLoadingGameFromUI = vars.Helper["isLoadingGameFromUI"].Current;

    if (!vars.doneFirstLook) {
        vars.doneFirstLook = true;
        vars.log(String.Format("Connected to Manifold Garden version {0}", vars.Helper["version"].Current));

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
            current.onMandalaScene = vars.mandalaScenes.Contains(vars.Helper.Scenes.Active.Name);
        }
        if (!current.onMandalaScene) {
            current.gravity = vars.Helper["gravity"].Current;
        }
        if (!vars.studioScreenDone) {
            vars.studioScreenDone = !current.isLoadingGameFromUI;
        }
        if (current.gravity != old.gravity) {
            vars.gravChanges += 1;
            if (settings["gravChanges"] && vars.updateText) {
                vars.tcs.Text2 = vars.gravChanges.ToString();
            }
        }
    }
}

isLoading {
    return current.isLoadingGameFromUI;
}

start {
    // Start the timer as soon as a game is being loaded (specifically the
    // moment you click a save slot to start a new game in, although it will
    // also start if you just load a file). This boolean is set to true during
    // the studio logo when the game starts up, so we check for that as well.
    if (vars.studioScreenDone && current.isLoadingGameFromUI) {
        vars.log("START based on file load");
        if (settings["zero"]) {
            vars.waypoints = vars.zeroPercentPoints;
        } else if (settings["allGodCubes"]) {
            vars.waypoints = vars.mandalaScenes;
        } else if (settings["configs"] && vars.configWaypoints != null) {
            vars.waypoints = new List<string>(vars.configWaypoints);
        } else {
            vars.waypoints = null;
        }
        vars.prevLevel = current.level;
        vars.stopwatch = Stopwatch.StartNew();
        vars.prev.Clear();
        vars.firstRoom = false;
        vars.inEnding = false;
        vars.gravChanges = 0;
        if (settings["gravChanges"] && vars.updateText) {
            vars.tcs.Text1 = "Gravity Changes:";
            vars.tcs.Text2 = "0";
        }
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
        vars.log(String.Format("{0}: '{1}'", current.level, vars.Helper.Scenes.Active.Name));

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

            vars.log(String.Format("Level changed from {0} to {1}: {2}", vars.prevLevel, current.level, action));
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
        vars.log("SPLIT on Raymarchitecture");
        vars.stopwatch = null;
        return true;
    }
}

reset {
    return current.onStartScreen && !old.onStartScreen;
}

onReset {
    if (settings["gravChanges"] && vars.updateText) {
        vars.tcs.Text1 = "Gravity Changes:";
        vars.tcs.Text2 = "0";
    }
}

exit
{
	vars.Helper.Dispose();
}

shutdown
{
	vars.Helper.Dispose();
}
