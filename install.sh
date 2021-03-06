#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OHMYZSH_CUSTOM_GITHUB_REPO="gillisandrew/ohmyzsh-custom"
NAME_LOWER=$(echo $NAME | tr '[:upper:]' '[:lower:]')
EMAIL="gillis.andrew+$NAME_LOWER@gmail.com"


sudo apt update
sudo apt install socat zsh


if [[ ! -f "$HOME/.ssh/${NAME_LOWER}_rsa" ]]; then
    ssh-keygen -f "$HOME/.ssh/${NAME_LOWER}_rsa" -t rsa -b 4096 -C "$EMAIL"
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    rm -rf "$ZSH/custom/*"
    git clone "https://github.com/$OHMYZSH_CUSTOM_GITHUB_REPO.git" "$ZSH/custom" --recurse-submodules --remote-submodules
fi

for filename in $DIR/linux/.*; do
    if [[ -f "$filename" ]]; then
        basename="$(basename -- $filename)"

        if [[ -f "$HOME/$basename" && ! -L "$HOME/$basename" ]]; then
            mv "$HOME/$basename" "$HOME/$basename.bkp"
        else 
            rm "$HOME/$basename"
        fi

        ln -s $filename "$HOME/$basename"        
    fi
done