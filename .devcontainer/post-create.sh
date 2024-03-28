#!/bin/sh

# this runs at Codespace creation - not part of pre-build

echo "post-create start"
echo "$(date)    post-create start" >> "$HOME/status"

# update the repos
git -C /workspaces/vets-api-mockdata pull
git -C /workspaces/vets-api pull

mkdir /workspaces/vets-api/.vscode
{
{
  "rubyLsp.rubyVersionManager": "none"
}
} >> /workspaces/vets-api/.vscode/settings.json

bundle install

echo "post-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-create complete" >> "$HOME/status"
