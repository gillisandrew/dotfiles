OHMYZSH_CUSTOM_GITHUB_REPO="gillisandrew/ohmyzsh-custom"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm -rf "$ZSH/custom/*"
git clone "https://github.com/$OHMYZSH_CUSTOM_GITHUB_REPO.git" "$ZSH/custom"