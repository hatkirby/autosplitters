// Autosplitter script for Lingo, by hatkirby.
//
// Requires a version released January 27th, 2023 or later.
//
// Massive thanks to the game developer, Brenton, for working with me to
// make this possible.

state("Lingo") {}

startup
{
    vars.log = (Action<string>)((string logLine) => {
        print("[Lingo ASL] " + logLine);
    });

    settings.Add("every",false,"Split on every panel solve");
    settings.Add("end", false, "Split on The End / The Ascendant");
    settings.Add("unchallenged", false, "Split on The Unchallenged");
    settings.Add("master", false, "Split on The Master");
    settings.Add("pilgrimage", false, "Split on Pilgrimage");
    settings.Add("levelOneThePanels",false,"Split on LL1 achievement panels (besides End and Master)");
    settings.Add("levelOneOranges",false,"Split on orange panels that open up the LL1 tower");
    settings.Add("levelTwoThePanels",false,"Split on LL2 achievement panels (besides Ascendant)");
    settings.Add("showLastPanel",false, "Override first text component with the name of the most recently solved panel");

    vars.prevPanel = "";

    vars.configFiles = null;
    vars.settings = settings;
    var findConfigFiles = (Action<string>)((string folder) => {
        var files = new List<string>();
        if (folder != null) {
            vars.log("Searching for config files in '" + folder + "'");
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.lingo_config"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.lingo_config.txt"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.lingo_conf"));
            files.AddRange(System.IO.Directory.GetFiles(folder, "*.lingo_confi"));
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

    vars.levelOneThePanels = new List<String>{
        "Panel_seeker_seeker",
        "Panel_traveled_traveled",
        "Panel_illuminated_initiated",
        "Panel_intelligent_wise",
        "Panel_tenacious_tenacious",
        "Panel_disagreeable_agreeable",
        "Panel_colorful_colorful",
        "Panel_observant_observant",
        "Panel_perceptive_perceptive",
        "Panel_deterred_undeterred",
        "Panel_emboldened_bold",
        "Panel_steady_steady",
        "Panel_bearer_bearer",
        "Panel_optimistic_optimistic",
        "Panel_discerning_scramble",
        "Panel_wondrous_wondrous",
        "Panel_fearless_fearless",
        "Panel_challenged_unchallenged",
        "Panel_grandfathered_red",
        "Panel_ecstatic_ecstatic",
        "Panel_artistic_artistic",
        "Panel_scientific_scientific",
        "Panel_incomparable_incomparable"
    };

    vars.levelOneOranges = new List<String>{
        "Panel_dads_ale_dead_1",
        "Panel_art_art_eat_2",
        "Panel_deer_wren_rats_3",
        "Panel_learns_unsew_unrest_4",
        "Panel_drawl_runs_enter_5",
        "Panel_reads_rust_lawns_6"
    };

    vars.levelTwoThePanels = new List<String>{
        "Panel_the_analytical",
        "Panel_the_mythical",
        "Panel_the_unforgettable",
        "Panel_the_fuzzy",
        "Panel_the_sharp",
        "Panel_the_structured",
        "Panel_the_devious",
        "Panel_the_amazing",
        "Panel_the_frozen",
        "Panel_the_lunar",
        "Panel_the_learned",
        "Panel_the_arcadian",
        "Panel_the_stellar",
        "Panel_the_handy",
        "Panel_orange_8",
        "Panel_the_ethereal",
        "Panel_the_sapient",
        "Panel_the_worldly",
        "Panel_the_seen",
        "Panel_the_perennial",
        "Panel_the_memorable",
        "Panel_the_exemplary",
        "Panel_the_fresh",
        "Panel_the_veteran",
        "Panel_the_royal",
        "Panel_the_unscrambled",
        "Panel_the_appreciated",
        "Panel_the_exact",
        "Panel_the_unopposed",
        "Panel_the_unsullied",
        "Panel_the_multitalented",
        "Panel_the_sweet",
        "Panel_the_tasty",
        "Panel_the_hidden",
        "Panel_the_magnificent",
        "Panel_the_magnanimous",
        "Panel_the_magnate",
        "Panel_the_magnetic",
        "Panel_the_archaeologist",
        "Panel_end",
        "Panel_the_lonely",
        "Panel_the_lucky",
        "Panel_the_lettered",
        "Panel_the_knowledgeable",
        "Panel_the_welcoming",
        "Panel_the_direct",
        "Panel_the_expert",
        "Panel_the_infallible"
    };
}

init
{
    // magic byte array format:
    // [0-7]: 5b a6 7d fe b8 69 f1 80 (random bytes used for sigscanning)
    // [8]: First input
    // [9-40]: Name of last solved panel
    IntPtr ptr = IntPtr.Zero;
    foreach (var page in game.MemoryPages(true).Reverse()) {
        var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
        ptr = scanner.Scan(new SigScanTarget(0, "5b a6 7d fe b8 69 f1 80"));
        if (ptr != IntPtr.Zero) {
            break;
        }
    }
    if (ptr == IntPtr.Zero) {
        throw new Exception("Could not find magic autosplitter array!");
    }
    vars.firstInput = new MemoryWatcher<byte>(ptr + 8);
    vars.panel = new StringWatcher(ptr + 9, 32);

    vars.log(String.Format("Magic autosplitter array: {0}", ptr.ToString("X")));

    vars.updateText = false;
    vars.configWaypoints = null;
}

update
{
    vars.firstInput.Update(game);
    vars.panel.Update(game);

    if (settings["showLastPanel"] && vars.updateText && vars.panel.Old != vars.panel.Current) {
        vars.tcs.Text2 = vars.panel.Current;
    }
}

start
{
    return vars.firstInput.Old == 0 && vars.firstInput.Current == 255;
}

onStart
{
    vars.prevPanel = vars.panel.Current;

    vars.updateText = false;
    if (settings["showLastPanel"]) {
        foreach (LiveSplit.UI.Components.IComponent component in timer.Layout.Components) {
            if (component.GetType().Name == "TextComponent") {
                vars.tc = component;
                vars.tcs = vars.tc.Settings;
                vars.tcs.Text1 = "Last Panel:";
                vars.tcs.Text2 = "";
                vars.updateText = true;
                vars.log("Found text component at " + component);
                break;
            }
        }
    }

    vars.configWaypoints = null;
    if (settings["configs"]) {
        string[] lines = {""};
        foreach (var configFile in vars.configFiles.Keys) {
            if (settings[configFile]) {
                // Full path is saved in the dictionary.
                var splitlist = System.IO.File.ReadAllLines(vars.configFiles[configFile]);
                if (splitlist != null) {
                    vars.configWaypoints = new List<string>(splitlist);
                }
                vars.log("Selected config file: " + configFile);
                vars.log("Config contains " + splitlist.Length + " lines");
                break;
            }
        }
    }
}

split
{
    if (vars.panel.Current != vars.prevPanel) {
        string action = "NO SPLIT";

        if (settings["every"]) {
            action = "SPLIT";
            vars.log("Split on any panel: " + vars.panel.Current);
        } else if (settings["end"] && vars.panel.Current == "Panel_end_end") {
            action = "SPLIT";
            vars.log("Split on The End");
        } else if (settings["unchallenged"] && vars.panel.Current == "Panel_challenged_unchallenged") {
            action = "SPLIT";
            vars.log("Split on The Unchallenged");
        } else if (settings["master"] && vars.panel.Current == "Panel_master_master") {
            action = "SPLIT";
            vars.log("Split on The Master");
        } else if (settings["pilgrimage"] && vars.panel.Current == "Panel_pilgrim") {
            action = "SPLIT";
            vars.log("Split on Pilgrimage");
        } else if (settings["levelOneThePanels"] && vars.levelOneThePanels.Contains(vars.panel.Current)) {
            action = "SPLIT";
            vars.log("Split on LL1 THE panel");
        } else if (settings["levelOneOranges"] && vars.levelOneOranges.Contains(vars.panel.Current)) {
            action = "SPLIT";
            vars.log("Split on LL1 tower orange");
        } else if (settings["levelTwoThePanels"] && vars.levelTwoThePanels.Contains(vars.panel.Current)) {
            action = "SPLIT";
            vars.log("Split on LL2 THE panel");
        } else if (settings["configs"] && vars.configWaypoints != null && vars.configWaypoints.Contains(vars.panel.Current)) {
            action = "SPLIT";
            vars.log("Split on config file");
        }

        vars.prevPanel = vars.panel.Current;
        return action.StartsWith("SPLIT");
    }
}
