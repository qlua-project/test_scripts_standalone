--[[---------------------------------------------------------------------------
    File: test_luapath.lua
    Desc: Diagnostic tool to audit package.path/cpath in QUIK vs. CLI.

    MODIFICATION APPROACHES:
    1. Short Form (Global Scope)
        package.path = ("%s;./scripts/?.lua"):format(package.path)
        package.cpath = ("%s;./bin/?.dll"):format(package.cpath)
    2. "Safe" Way (Avoiding Duplicates)
        if not package.path:find(new_path, 1, true) then
           package.path = ("%s;%s"):format(package.path, new_path)
        end
    3. Common Placeholders
        ./?.lua         - modname.lua
        ./?/init.lua    - modname/init.lua
        ./bin/?.dll     - require(modname) [Windows Binaries]
    4. Pro Tip: Instead of hardcoding, use os.getenv
        local custom = os.getenv("LUA_ADDON_PATH")
        if custom then
            package.path = ("%s;%s/?.lua"):format(package.path, custom)
        end
       4.1 The "Project Local" Way (Shell Session)
           PowerShell: $env:LUA_ADDON_PATH = "C:\MyLibs"
           CMD:        set LUA_ADDON_PATH=C:\MyLibs
       4.2 .env files (Project Level)
           Lua does not read .env files automatically.
           - Snippet: Use a loop with f:lines() and line:match()
           - Library: 'lua-dotenv' (luarocks install lua-dotenv)
       4.3 Pro Tip: LUA_INIT
           Executes before every script. Use '@' prefix for files.
           set LUA_INIT=@C:\path\to\env_init.lua
    5. The "Lua Native" Way (LUA_PATH & LUA_CPATH)
       set LUA_PATH=C:\MyLibs\?.lua;;
       - ';;' is a startup sequence feature; it expands to default paths.
       - Note: Does not expand if assigned as a literal string in-script.

    THEMES INCLUDED:
    1. LUA 5.4 SAFETY: Uses <close> on pipes: local p <close> = io.popen("cd")
    2. ENV IDIOM: 'not not message' to check if running inside QUIK terminal.
    3. FORMATTING: Use ("%q"):format(str) for safe path quoting in logs.
    4. PATTERNS: Split paths via gmatch("[^;]+") to handle semicolon delimiters.
---------------------------------------------------------------------------]]
local isRunningFromQuik = not not message

-- Safely capture CWD using Lua 5.4 to-be-closed variables
-- io.popen("cd") triggers a visible console window (Console Blink)
local cwd = function() local pipe<close> = io.popen("cd"); return pipe:read('l') end
local getLuaExePath = arg and function() return ("%s\\%s"):format(cwd(), arg[-1]:match("(.*)[\\/]")) end or cwd
local getLuaScriptPath = function() return debug.getinfo(1, "S").source:sub(2):match("(.*)[\\/]") end
-- Initialize environment bridges
getWorkingFolder = getWorkingFolder or getLuaExePath
getScriptPath    = getScriptPath or getLuaScriptPath
message          = message or print

message("test_luapath")

message(package.path)
-- QUIK\lua\?.lua
-- QUIK\lua\?\init.lua
-- QUIK\?.lua
-- QUIK\?\init.lua
-- QUIK\..\share\lua\5.4\?.lua
-- QUIK\..\share\lua\5.4\?\init.lua
-- .\?.lua
-- .\?\init.lua

message(package.cpath)
-- QUIK\?.dll
-- QUIK\..\lib\lua\5.4\?.dll
-- QUIK\loadall.dll
-- .\?.dll

-- require works in QUIK, failed in LUA
-- message("test_luapath_require: " .. tostring(require('test_luapath_require')))

local function escape_pattern(text) return text:gsub("([^%w])", "%%%1") end

function main()
	message(("getWorkingFolder: %q"):format(getWorkingFolder()))
	message(("getScriptPath: %q"):format(getScriptPath()))
	message(("cwd: %q"):format(cwd()))   -- same as getScriptPath

	local filename = isRunningFromQuik and "test_luapath_quik.txt" or "test_luapath_lua.txt"
	local filepath = getScriptPath() .."\\".. filename
	local file = assert(io.open(filepath, "w"))

	message(string.format("file: %q", filepath))

	file:write("getWorkingFolder\n")
	file:write(getWorkingFolder() .. "\n")
	file:write("getScriptPath\n")
	file:write(getScriptPath() .. "\n")
	file:write("cwd\n")
	file:write(cwd() .. "\n")
	file:write("\n")

	local runtime = isRunningFromQuik and "QUIK" or "LUA"

	local path = package.path
	path = path:gsub(escape_pattern(getWorkingFolder()), runtime)
	file:write("package.path\n")
	file:write(path)
	file:write("\n\n")
	for line in path:gmatch("[^;]+") do
		file:write(line)
		file:write("\n")
	end

	file:write("\n\n")

	local cpath = package.cpath
	cpath = cpath:gsub(escape_pattern(getWorkingFolder()), runtime)
	file:write("package.cpath\n")
	file:write(cpath)
	file:write("\n\n")
	for line in cpath:gmatch("[^;]+") do
		file:write(line)
		file:write("\n")
	end

    -- path = path:gsub(os.getenv("USERPROFILE"), "%%USERPROFILE%%")

	file:write("\n")

	file:close()
end

if not isRunningFromQuik then
	main()
end