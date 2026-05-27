# MSYS2 ceveat
```bash
wget -O msys2.tar.zst https://github.com/msys2/msys2-installer/releases/download/2025-12-13/msys2-base-x86_64-20251213.tar.zst
pacman -Syu zip unzip
wget -O win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip
unzip win32yank/ win32yank.zip
cd win32yank
chmod +x win32yank.exe
mv win32yank.exe /ucrt64/bin/
echo "alias win32yank='/ucrt64/bin/win32yank.exe'" >> ~/.zshrc && source ~/.zshrc
```

## Set `zsh` as your default MSYS2 shell

1. Locate MSYS2 installation folder in windows. In my case, it's in `C:\msys64`.
2. Open `msys2_shell.cmd`.
3. Locate line `set "LOGINSHELL=bash"` and change it to `set "LOGINSHELL=zsh"`

```bash
pacman -Syu mingw-w64-ucrt-x86_64-neovim
echo "alias nvim='/ucrt64/bin/nvim.exe'" >> ~/.zshrc && source ~/.zshrc
echo "export PROMPT='%F{cyan}%n%f %F{magenta}➜%f %F{yellow}%~%f $ '" >> ~/.zshrc
pacman -S mingw-w64-x86_64-clip
pacman -Syu git


pacman -Syu man
pacman -Syu openssh rsync make
pacman -Syu zip unzip
pacman -Syu mingw64/mingw-w64-x86_64-jq
```
