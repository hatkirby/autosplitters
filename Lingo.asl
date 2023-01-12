// Autosplitter script for Lingo, by hatkirby.
//
// Requires a version released January 10th, 2023 or later.
//
// Massive thanks to the game developer, Brenton, for working with me to
// make this possible.

state("Lingo") {}

startup
{
    vars.log = (Action<string>)((string logLine) => {
        print("[Lingo ASL] " + logLine);
    });

    settings.Add("end", false, "Split on The End");
    settings.Add("unchallenged", false, "Split on The Unchallenged");
    settings.Add("master", false, "Split on The Master");
    settings.Add("pilgrimage", false, "Split on Pilgrimage");
    settings.Add("showLastPanel",false, "Override first text component with the name of the most recently solved panel");

    vars.log("Autosplitter loaded");
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
    vars.lastPanel = new StringWatcher(ptr + 9, 32);

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
    vars.lastPanel.Update(game);

    if (settings["showLastPanel"] && vars.updateText && vars.lastPanel.Old != vars.lastPanel.Current) {
        vars.tcs.Text2 = vars.lastPanel.Current;
    }
}

start
{
    return vars.firstInput.Old == 0 && vars.firstInput.Current == 255;
}

onStart
{
    if (settings["showLastPanel"] && vars.updateText) {
        vars.tcs.Text1 = "Last Panel:";
        vars.tcs.Text2 = "";
    }
}

split
{
    if (settings["end"] && vars.lastPanel.Old != "Panel_end_end" && vars.lastPanel.Current == "Panel_end_end") {
        vars.log("Split on The End");
        return true;
    }
    if (settings["unchallenged"] && vars.lastPanel.Old == "Panel_challenged_unchallenged" && vars.lastPanel.Current == "Panel_challenged_unchallenged") {
        vars.log("Split on The Unchallenged");
        return true;
    }
    if (settings["master"] && vars.lastPanel.Old == "Panel_master_master" && vars.lastPanel.Current == "Panel_master_master") {
        vars.log("Split on The Master");
        return true;
    }
    if (settings["pilgrimage"] && vars.lastPanel.Old == "Panel_pilgrim" && vars.lastPanel.Current == "Panel_pilgrim") {
        vars.log("Split on Pilgrimage");
        return true;
    }
}
