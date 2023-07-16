// AutoSplit script for Temple of Starlight, by hatkirby

state("Temple of Starlight") {}

startup {
    // Relative to Livesplit.exe
    vars.logFilePath = Directory.GetCurrentDirectory() + "\\autosplitter_starlight.log";
    vars.log = (Action<string>)((string logLine) => {
        print("[Temple of Starlight ASL] " + logLine);
        string time = System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss.fff");
        // AppendAllText will create the file if it doesn't exist.
        System.IO.File.AppendAllText(vars.logFilePath, time + ": " + logLine + "\r\n");
    });

    var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
    var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
    vars.Helper = Activator.CreateInstance(type, timer, this);
    vars.Helper.LoadSceneManager = true;

    vars.prevLevel = 0;
    vars.prev = new List<int>();
    vars.firstRoom = false;

    vars.noSplitScenes = new List<String>{
        "StartScene",
        "LevelSelect"
    };

    vars.log("Autosplitter loaded");
}

init {
    vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono =>
    {
        return true;
    });

    vars.Helper.Load();
}

update {
    if (!vars.Helper.Update())
		return false;

    current.level = vars.Helper.Scenes.Active.Index;
}

onStart {
    vars.prevLevel = current.level;
    vars.prev.Clear();
    vars.firstRoom = false;
}

split {
    // Split when level index changes. We don't split for the first room change
    // in a run, because that is always going to be changing to the first room,
    // and it happens a couple of seconds after the timer starts.
    if (vars.firstRoom
        && current.level != vars.prevLevel
        && current.level > 0
        && !vars.noSplitScenes.Contains(vars.Helper.Scenes.Active.Name)) {
        vars.log(String.Format("{0}: '{1}'", current.level, vars.Helper.Scenes.Active.Name));

        string action = "NO SPLIT";

        if (vars.prevLevel != 0) {
            action = "SPLIT";
            
            if (vars.prev.Contains(current.level)) {
                action = "NO SPLIT";
            }
            vars.prev.Add(current.level);
            vars.log(String.Format("Level changed from {0} to {1}: {2}", vars.prevLevel, current.level, action));
        }

        vars.prevLevel = current.level;
        return action.StartsWith("SPLIT");
    } else if (!vars.firstRoom && vars.Helper.Scenes.Active.Name == "Level01") {
        vars.firstRoom = true;
        vars.prevLevel = current.level;
        vars.prev.Add(current.level);
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
