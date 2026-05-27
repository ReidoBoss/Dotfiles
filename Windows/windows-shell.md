Yes, Windows has equivalents depending on which shell you use. The closest match is PowerShell, which has a profile script that runs on startup, just like .zshrc.


PowerShell (the modern default)


Your profile file lives at:


$PROFILE



Run that in PowerShell and it'll print the path, typically:


C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1



If it doesn't exist yet:


New-Item -Path $PROFILE -ItemType File -Force
notepad $PROFILE



Then define functions exactly like in zsh:


function test-func {
    Write-Host "hello from my function"
}

function gs { git status }

function mkcd($path) {
    New-Item -ItemType Directory -Path $path
    Set-Location $path
}



Save, then reload with:


. $PROFILE



(The leading dot is PowerShell's equivalent of source. You can also use . ./some-other-file.ps1 to source additional files, just like in zsh.)


Git Bash / WSL


If you installed Git for Windows, it comes with Git Bash, which uses ~/.bashrc exactly like Linux. Your home is C:\Users\<you> and you can source ~/.bashrc normally.


WSL (Windows Subsystem for Linux) is even closer — it's a full Linux environment, so your ~/.zshrc works identically. If you want the real zsh experience on Windows, WSL is the way.


CMD (the old shell)


CMD has no real equivalent. You can fake it with doskey macros loaded via a cmd /k startup script through registry AutoRun, but it's clunky. If you're on CMD, switching to PowerShell is the upgrade path.


Quick recommendation: if you want the zsh-like experience, install WSL (wsl --install in an admin PowerShell). If you want to embrace the native Windows way, use PowerShell with $PROFILE.


Yes, PowerShell has the same pattern — you can split your config across multiple files and source them all from $PROFILE.


The pattern


In your $PROFILE, just dot-source other files (the leading . is PowerShell's source):


# $PROFILE — Microsoft.PowerShell_profile.ps1

. "$HOME\Documents\PowerShell\aliases.ps1"
. "$HOME\Documents\PowerShell\git-functions.ps1"
. "$HOME\Documents\PowerShell\work-stuff.ps1"



Then in git-functions.ps1:


function gs { git status }
function gp { git pull }
function gco { git checkout $args }



Open a new PowerShell session and gs, gp, etc. all work.


A common organized setup


Many people keep a folder of scripts and loop over them, so you don't have to edit $PROFILE every time you add a new file:


# $PROFILE
$scriptsDir = "$HOME\Documents\PowerShell\scripts"

Get-ChildItem -Path $scriptsDir -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}



Now any .ps1 file you drop into scripts\ gets auto-loaded. This is the PowerShell version of zsh's for f in ~/.zsh/*.zsh; do source $f; done.


One gotcha: execution policy


If you get an error like "running scripts is disabled on this system" the first time, run this once in an admin PowerShell:


Set-ExecutionPolicy -Scope CurrentUser RemoteSigned



RemoteSigned lets your own local scripts run freely while still blocking unsigned scripts downloaded from the internet — a sensible default.


After that, dot-sourcing works exactly like source in zsh: nested sources are fine (a sourced file can itself dot-source others), variables and functions propagate up to your session, and reloading with . $PROFILE picks up changes without restarting the shell.
