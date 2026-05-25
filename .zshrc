for file in ~/.zsh/**/*.zsh(.N); do
  [[ "$file" == "$HOME/.zshrc" ]] && continue
  source "$file"
done

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

