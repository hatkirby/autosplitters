// Autosplitter script for The Looker 2022-06-28.
//
// Written by hatkirby, with inspiration from CaptainRektbeard's Marble Marcher
// autosplitter.

state("The Looker") {}

startup {
    // For logging!
    vars.Log = (Action<object>)((output) => print("[The Looker ASL] " + output));

    // Function for deallocating memory used by this process.
    vars.FreeMemory = (Action<Process>)(p => {
        vars.Log("Deallocating");
        foreach (IDictionary<string, object> hook in vars.hooks){
            if(((bool)hook["enabled"]) == false){
                continue;
            }
            p.FreeMemory((IntPtr)hook["outputPtr"]);
            p.FreeMemory((IntPtr)hook["funcPtr"]);
        }
    });

    vars.hooks = new List<ExpandoObject> {
        (vars.unlockAchievement = new ExpandoObject()),
    };

    // The unlockAchievement function will give us a pointer to the most
    // recently unlocked achievement.
    vars.unlockAchievement.name = "UnlockAchievement";
    vars.unlockAchievement.outputSize = 8;
    vars.unlockAchievement.overwriteBytes = 11;
    vars.unlockAchievement.payload = new byte[] { 0x49, 0x89, 0x08 }; // mov [r8], rcx
    vars.unlockAchievement.enabled = true;
    vars.unlockAchievement.offset = 0x96D700;

    // If this isn't checked, then it will only split on The Obelisk.
    settings.Add("ACH_AMMO", false, "Split on Reloaded");
    settings.Add("ACH_HORROR_BOO", false, "Split on BOO!!!");
    settings.Add("ACH_SHOOTING_GALLERY", false, "Split on On Rails");
    settings.Add("ACH_TELESCOPE", false, "Split on Dahh!");
    settings.Add("ACH_RECORDERS", false, "Split on Investigator");
    settings.Add("ACH_SNAKE", false, "Split on SNeK");
    settings.Add("ACH_LABYRINTH_BOOK", false, "Split on Student");
    settings.Add("ACH_LAST_PUZZLE", true, "Split on The Obelisk");
    settings.Add("ACH_DRAW_ON_WIRE", false, "Split on Outside the Box");
    settings.Add("ACH_CINEMATIC", false, "Split on Success");
}

init {
    // Install hooks
    IntPtr baseAddress = modules.Where(m => m.ModuleName == "UnityPlayer.dll").First().BaseAddress;
    foreach (IDictionary<string, object> hook in vars.hooks)
    {
        if(((bool)hook["enabled"]) == false){
            continue;
        }
        vars.Log("Installing hook for " + hook["name"]);

        // Get pointer to function
        hook["injectPtr"] = baseAddress + (int)hook["offset"];

        // Find nearby 14 byte code cave to store long jmp
        int caveSize = 0;
        int dist = 0;
        hook["cavePtr"] = IntPtr.Zero;
        vars.Log("Scanning for code cave");
        for(int i=1;i<0xFFFFFFFF;i++){
            try {
                byte b = game.ReadBytes((IntPtr)hook["injectPtr"] + i, 1)[0];
                if (b == 0xCC){
                    caveSize++;
                    if (caveSize == 14){
                        hook["caveOffset"] = i - 11;
                        hook["cavePtr"] = (IntPtr)hook["injectPtr"] + (int)hook["caveOffset"];
                        break;
                    }
                }else{
                    caveSize = 0;
                }
            } catch {
                caveSize = 0;
            }
        }
        if ((IntPtr)hook["cavePtr"] == IntPtr.Zero){
            throw new Exception("Unable to locate nearby code cave");
        }
        vars.Log("Found cave " + ((int)hook["caveOffset"]).ToString("X") + " bytes away");

        // Allocate memory for output
        hook["outputPtr"] = game.AllocateMemory((int)hook["outputSize"]);

        // Build the hook function
        var funcBytes = new List<byte>() { 0x49, 0xB8 }; // mov r8, ...
        funcBytes.AddRange(BitConverter.GetBytes((UInt64)((IntPtr)hook["outputPtr"]))); // ...outputPtr
        funcBytes.AddRange((byte[])hook["payload"]);

        // Allocate memory to store the function
        hook["funcPtr"] = game.AllocateMemory(funcBytes.Count + (int)hook["overwriteBytes"] + 14);

        // Write the detour:
        // - Copy bytes from the start of original function which will be overwritten
        // - Overwrite those bytes with a 5 byte jump instruction to a nearby code cave
        // - In the code cave, write a 14 byte jump to the memory allocated for our hook function
        // - Write the hook function
        // - Write a copy of the overwritten code at the end of the hook function
        // - Following this, write a jump back the original function
        game.Suspend();
        try {
            // Copy the bytes which will be overwritten
            byte[] overwritten = game.ReadBytes((IntPtr)hook["injectPtr"], (int)hook["overwriteBytes"]);

            // Write short jump to code cave
            List<byte> caveJump = new List<byte>() { 0xE9 }; // jmp ...
            caveJump.AddRange(BitConverter.GetBytes((int)hook["caveOffset"] - 5)); // ...caveOffset - 5
            game.WriteBytes((IntPtr)hook["injectPtr"], caveJump.ToArray());
            hook["origBytes"] = overwritten;

            // NOP out excess bytes
            for(int i=0;i<(int)hook["overwriteBytes"]-5;i++){
                game.WriteBytes((IntPtr)hook["injectPtr"] + 5 + i, new byte[] { 0x90 });
            }

            // Write jump to hook function in code cave
            List<byte> firstJump = new List<byte>() { 0x49, 0xb8 }; // mov r8, ...
            firstJump.AddRange(BitConverter.GetBytes((long)(IntPtr)hook["funcPtr"])); // ...funcPtr
            firstJump.AddRange(new byte[] { 0x41, 0xff, 0xe0 }); // jmp r8
            game.WriteBytes((IntPtr)hook["cavePtr"], firstJump.ToArray());

            // Write the hook function
            game.WriteBytes((IntPtr)hook["funcPtr"], funcBytes.ToArray());

            // Write the overwritten code
            game.WriteBytes((IntPtr)hook["funcPtr"] + funcBytes.Count, overwritten);

            // Write the jump to the original function
            List<byte> secondJump = new List<byte>() { 0x49, 0xb8 }; // mov r8, ...
            secondJump.AddRange(BitConverter.GetBytes((long)((IntPtr)hook["injectPtr"] + (int)hook["overwriteBytes"]))); // ...funcPtr
            secondJump.AddRange(new byte[] { 0x41, 0xff, 0xe0 }); // jmp r8
            game.WriteBytes((IntPtr)hook["funcPtr"] + funcBytes.Count + (int)hook["overwriteBytes"], secondJump.ToArray());
        }
        catch {
            vars.FreeMemory(game);
            throw;
        }
        finally{
            game.Resume();
        }

        // Calcuate offset of injection point from module base address
        UInt64 offset = (UInt64)((IntPtr)hook["injectPtr"]) - (UInt64)baseAddress;

        vars.Log("Output: " + ((IntPtr)hook["outputPtr"]).ToString("X"));
        vars.Log("Injection: " + ((IntPtr)hook["injectPtr"]).ToString("X") + " (UnityPlayer.dll+" + offset.ToString("X") + ")");
        vars.Log("Function: " + ((IntPtr)hook["funcPtr"]).ToString("X"));
    }

    vars.Watchers = new MemoryWatcherList
    {
        (vars.lastAchievement = new MemoryWatcher<IntPtr>((IntPtr)vars.unlockAchievement.outputPtr))
    };
}

update
{
    vars.Watchers.UpdateAll(game);
}

split {
    if (vars.lastAchievement.Current != vars.lastAchievement.Old) {
        string result;
        game.ReadString((IntPtr)(vars.lastAchievement.Current + 0x14), ReadStringType.UTF16, 40, out result);
        vars.Log(result);

        return settings[result];
    }
}

shutdown
{
	if (game == null)
        return;

    game.Suspend();
    try
    {
        vars.Log("Restoring memory");
        foreach (IDictionary<string, object> hook in vars.hooks){
            if(((bool)hook["enabled"]) == false){
                continue;
            }
            // Restore overwritten bytes
            game.WriteBytes((IntPtr)hook["injectPtr"], (byte[])hook["origBytes"]);

            // Remove jmp from code cave
            for(int i=0;i<12;i++){
                game.WriteBytes((IntPtr)hook["cavePtr"] + i, new byte[] { 0xCC });
            }

        }
        vars.Log("Memory restored");
    }
    catch
    {
        throw;
    }
    finally
    {
        game.Resume();
        vars.FreeMemory(game);
    }
}
