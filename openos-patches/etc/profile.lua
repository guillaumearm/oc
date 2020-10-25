local shell = require("shell")
local tty = require("tty")
local fs = require("filesystem")

if tty.isAvailable() then
  if io.stdout.tty then
    io.write("\27[40m\27[37m")
    tty.clear()
  end
end
dofile("/etc/motd")

-- Environment
os.setenv("EDITOR", "/bin/edit")
os.setenv("HISTSIZE", "10")
os.setenv("HOME", "/home")
os.setenv("IFS", " ")
os.setenv("MANPATH", "/man:/usr/man:.")
os.setenv("PAGER", "shedit -r")
os.setenv("PS1", "\27[40m\27[31m$HOSTNAME$HOSTNAME_SEPARATOR$PWD # \27[37m")
os.setenv("LS_COLORS", "di=0;36:fi=0:ln=0;33:*.lua=0;32")

-- Aliases
shell.setAlias("dir", "ls")
shell.setAlias("move", "mv")
shell.setAlias("rename", "mv")
shell.setAlias("copy", "cp")
shell.setAlias("del", "rm")
shell.setAlias("md", "mkdir")
shell.setAlias("cls", "clear")
shell.setAlias("rs", "redstone")
shell.setAlias("view", "edit -r")
shell.setAlias("help", "man")
shell.setAlias("cp", "cp -i")
shell.setAlias("l", "ls -lhp")
shell.setAlias("..", "cd ..")
shell.setAlias("df", "df -h")
shell.setAlias("grep", "grep --color")
shell.setAlias("more", "less --noback")
shell.setAlias("reset", "resolution `cat /dev/components/by-type/gpu/0/maxResolution`")

-- Working directory
shell.setWorkingDirectory(os.getenv("HOME"))

-- Source files
local sourceShellFile = function(shrc_path)
  if fs.exists(shrc_path) then
    loadfile(shell.resolve("source", "lua"))(shrc_path)    
  end
end

sourceShellFile('/etc/shrc')
sourceShellFile(shell.resolve('.shrc'))
