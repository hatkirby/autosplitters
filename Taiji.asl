state("Taiji")
{
    // v9.10.2022, v9.12.2022.6
    int solveCount: "GameAssembly.dll", 0x0168ED88, 0x80, 0x100, 0xD94;
    byte10 worldsCompleted: "GameAssembly.dll", 0x015C8010, 0x48, 0x40, 0x80, 0x290, 0xB8, 0x10, 0x20;
}

startup
{
    vars.log = (Action<string>)((string logLine) => {
        print("[Taiji ASL] " + logLine);
    });

    settings.Add("solveCount", true, "Split on solve count increasing");
    settings.Add("world", false, "Split on completing a world");

    vars.log("Autosplitter loaded");
}

onStart
{
    vars.maxSolve = 0;
    vars.numWorlds = 0;
}

split
{
    if (settings["solveCount"] && current.solveCount > vars.maxSolve) {
        vars.log(String.Format("Solve count increased from {0} to {1}", vars.maxSolve, current.solveCount));
        vars.maxSolve = current.solveCount;
        return true;
    }
    if (settings["world"]) {
        int curWorlds = 0;
        foreach (byte b in current.worldsCompleted) {
            if (b == 1) {
                curWorlds += 1;
            }
        }
        if (curWorlds > vars.numWorlds) {
            vars.log(String.Format("World count increased from {0} to {1}", vars.numWorlds, curWorlds));
            vars.numWorlds = curWorlds;
            return true;
        }
    }
}
