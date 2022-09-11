state("Taiji")
{
    // v9.10.2022
    int solveCount: "GameAssembly.dll", 0x0168ED88, 0x80, 0x100, 0xD94;
}

startup
{
    vars.log = (Action<string>)((string logLine) => {
        print("[Taiji ASL] " + logLine);
    });

    vars.log("Autosplitter loaded");
}

onStart
{
    vars.maxSolve = 0;
}

split
{
    if (current.solveCount > vars.maxSolve) {
        vars.log(String.Format("Solve count increased from {0} to {1}", vars.maxSolve, current.solveCount));
        vars.maxSolve = current.solveCount;
        return true;
    }
}
