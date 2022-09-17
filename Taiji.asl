// Autosplitter script for Taiji, by hatkirby.
//
// Requires v9.17.2022 or later.
//
// Massive thanks to the game developer, mvandevander, for working with me to
// make this possible.

state("Taiji") {}

startup
{
    vars.log = (Action<string>)((string logLine) => {
        print("[Taiji ASL] " + logLine);
    });

    settings.Add("solveCount", true, "Split on solve count increasing");
    settings.Add("world", false, "Split on completing a world");
    settings.Add("tutorial", false, "Split on Tutorial completion");
    settings.Add("black", true, "Split on Black ending");
    settings.Add("white", false, "Split on White ending");

    vars.log("Autosplitter loaded");
}

init
{
    // magic byte array format:
    // [0-7]: 7b 08 ec f9 87 1d b7 d6 (random bytes used for sigscanning)
    // [8]: New file flag. Gets set to 1 when "start a new game" is selected.
    //      Gets reset to 0 when the pause menu is opened.
    // [9-17]: A copy of the world completion flags.
    // [18]: Solve count / 256.
    // [19]: Solve count % 256.
    // [20]: Tutorial completion flag.
    // [21]: Black ending flag. Gets set to 1 when the square that starts the
    //       interactive ending is clicked.
    // [22]: White ending flag. Gets set to 1 when the square that enables the
    //       prison is clicked.
    // [23]: Loading flag. Set to 1 during loads, 0 otherwise.
    IntPtr ptr = IntPtr.Zero;
    foreach (var page in game.MemoryPages(true).Reverse()) {
        var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
        ptr = scanner.Scan(new SigScanTarget(0, "7b 08 ec f9 87 1d b7 d6"));
        if (ptr != IntPtr.Zero) {
            break;
        }
    }
    if (ptr == IntPtr.Zero) {
        throw new Exception("Could not find magic autosplitter array!");
    }
    vars.newFileFlag = new MemoryWatcher<byte>(ptr + 8);
    vars.worldCompletion = new List<MemoryWatcher<byte>>();
    for (int i = 0; i < 9; i++) {
        vars.worldCompletion.Add(new MemoryWatcher<byte>(ptr + 9 + i));
    }
    vars.solveCountHigh = new MemoryWatcher<byte>(ptr + 18);
    vars.solveCountLow = new MemoryWatcher<byte>(ptr + 19);
    vars.tutorialCompletion = new MemoryWatcher<byte>(ptr + 20);
    vars.blackEnding = new MemoryWatcher<byte>(ptr + 21);
    vars.whiteEnding = new MemoryWatcher<byte>(ptr + 22);
    vars.loadingFlag = new MemoryWatcher<byte>(ptr + 23);

    vars.log(String.Format("Magic autosplitter array: {0}", ptr.ToString("X")));
}

update
{
    vars.newFileFlag.Update(game);
    vars.tutorialCompletion.Update(game);
    vars.blackEnding.Update(game);
    vars.whiteEnding.Update(game);
    vars.loadingFlag.Update(game);

    vars.solveCountHigh.Update(game);
    vars.solveCountLow.Update(game);
    current.solveCount = vars.solveCountHigh.Current * 256 + vars.solveCountLow.Current;

    int curWorlds = 0;
    for (int i = 0; i < 9; i++) {
        vars.worldCompletion[i].Update(game);
        if (vars.worldCompletion[i].Current == 1) {
            curWorlds++;
        }
    }
    current.numWorlds = curWorlds;
}

start
{
    return vars.newFileFlag.Old == 0 && vars.newFileFlag.Current == 1;
}

split
{
    if (settings["solveCount"] && current.solveCount > old.solveCount) {
        vars.log(String.Format("Solve count increased from {0} to {1}", old.solveCount, current.solveCount));
        return true;
    }
    if (settings["world"] && current.numWorlds > old.numWorlds) {
        vars.log(String.Format("World count increased from {0} to {1}", old.numWorlds, current.numWorlds));
        return true;
    }
    if (settings["tutorial"] && vars.tutorialCompletion.Old == 0 && vars.tutorialCompletion.Current == 1) {
        vars.log("Split on tutorial completion");
        return true;
    }
    if (settings["black"] && vars.blackEnding.Old == 0 && vars.blackEnding.Current == 1) {
        vars.log("Split on Black ending");
        return true;
    }
    if (settings["white"] && vars.whiteEnding.Old == 0 && vars.whiteEnding.Current == 1) {
        vars.log("Split on White ending");
        return true;
    }
}

isLoading
{
    return vars.loadingFlag.Current == 1;
}
