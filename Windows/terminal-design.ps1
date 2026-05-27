Here are PowerShell equivalents for both blocks, with the gotchas called out.


Block 1: Recursive sourcing + plugin


Zsh original:


for file in ~/.zsh/**/*.zsh(.N); do
  [[ "$file" == "$HOME/.zshrc" ]] && continue
  source "$file"
done

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh



PowerShell equivalent:


# Recursively source all .ps1 files under ~/.ps1-config, skipping $PROFILE itself
Get-ChildItem -Path "$HOME\.ps1-config" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $PROFILE } |
    ForEach-Object { . $_.FullName }

# Load a "plugin" — PSReadLine is the closest thing to zsh-autosuggestions
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView



A few notes on the mapping:


(.N) in zsh means "regular files, null glob if no match" — -ErrorAction SilentlyContinue plus Get-ChildItem's default file-filtering covers that.
**/* recursion is -Recurse in PowerShell.
For autosuggestions specifically, PSReadLine ships with modern PowerShell and gives you fish-style inline history prediction — exactly what zsh-autosuggestions does. Set it once and you get gray-text suggestions as you type, accepted with →.


Block 2: Banner + custom prompt


Zsh original:


cat <<"EOF"
⠀Hello Stephen!
EOF

export PROMPT='%F{cyan}%n%f %F{magenta}➜%f %F{yellow}%~%f $ '



PowerShell equivalent:


# Banner on shell start
@"
⠀Hello Stephen!
"@ | Write-Host

# Custom prompt — must be a function literally named "prompt"
function prompt {
    $user = $env:USERNAME
    $path = $PWD.Path.Replace($HOME, "~")

    Write-Host $user -ForegroundColor Cyan -NoNewline
    Write-Host " ➜ " -ForegroundColor Magenta -NoNewline
    Write-Host $path -ForegroundColor Yellow -NoNewline
    return " $ "
}



How the prompt mapping works:


Zsh uses $PROMPT with %F{color}...%f escape codes. PowerShell uses a function named prompt that PowerShell calls before every command line — whatever it returns becomes the prompt.
%n (username) → $env:USERNAME
%~ (home-shortened cwd) → $PWD.Path.Replace($HOME, "~")
Colors are done with Write-Host -ForegroundColor plus -NoNewline, and the final return " $ " gives you the trailing prompt character without color.


Worth knowing: Oh My Posh


If you want zsh + Oh My Zsh-level prompt polish (git status in the prompt, segments, themes, etc.), the PowerShell community has converged on Oh My Posh:


winget install JanDeDobbeleer.OhMyPosh
oh-my-posh init pwsh | Invoke-Expression



It works across PowerShell, CMD, and bash, has tons of themes, and is what most people use instead of hand-rolling a prompt function. Worth a look once you've got the basics wired up.
