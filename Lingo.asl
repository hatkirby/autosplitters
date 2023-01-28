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
    settings.Add("end", false, "Split on The End");
    settings.Add("unchallenged", false, "Split on The Unchallenged");
    settings.Add("master", false, "Split on The Master");
    settings.Add("pilgrimage", false, "Split on Pilgrimage");
    settings.Add("levelOneThePanels",false,"Split on LL1 achievement panels (besides End and Master)");
    settings.Add("levelOneOranges",false,"Split on orange panels that open up the LL1 tower");
    settings.Add("showLastPanel",false, "Override first text component with the name of the most recently solved panel");

    vars.prevPanel = "";

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
    if (settings["showLastPanel"]) {
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

    if (settings["showLastPanel"] && vars.updateText) {
        vars.tcs.Text1 = "Last Panel:";
        vars.tcs.Text2 = "";
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
        }

        vars.prevPanel = vars.panel.Current;
        return action.StartsWith("SPLIT");
    }
}
