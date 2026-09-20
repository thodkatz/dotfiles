# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a
package whose contents mirror `$HOME`, using Stow's `--dotfiles` convention: a path segment
named `dot-foo` gets symlinked as `.foo`.

## Install

```shell
sudo apt install stow   # if not already installed
stow -t "$HOME" --dotfiles -R zsh vim doom x11 git alacritty autostart dunst i3 nvim picom polybar rofi sxhkd systemd vscode
```

(run from the repo root; `-R` restows, so it's safe to rerun after editing a package or to
apply just the packages you list, e.g. `stow -t "$HOME" --dotfiles -R git` for a single one).

The `git` package includes `dot-config/git/ignore`, which Git treats as the default global
excludes file, so patterns there (currently `.agentvm.yml`) are ignored in every repo without
touching any project's own `.gitignore`.

### xorg-conf (edge case)

`xorg-conf` is the one package that doesn't target `$HOME` — it targets `/etc`, so it needs
root and a separate command instead of being included in the bulk install above:

```shell
sudo stow -t /etc --dotfiles -R xorg-conf
```

## Code

```shell
cat ./code/extensions.txt | xargs -L1 code --install-extension
```
