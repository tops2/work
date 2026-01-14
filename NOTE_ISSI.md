# Note
This repo from VS code can push/pull to my ISSI's:
/user/dpeng/GIT/work/

But when directly workign this this directory from commandline, I can't run
`git push` without it asking for user name and password (or personal account
key). Using Claude.ai, it offered manual menthod to store credentials. It did
suggest using ssh, but my ssh key must be too old/out of date, and I didn't
want to generate a new one cause it would affect my ISSI accounts.


## Create credentials file
touch ~/.git-credentials
chmod 600 ~/.git-credentials

## Add your credentials (replace with your info)
echo "https://YOUR_USERNAME:YOUR_PAT@github.com" > ~/.git-credentials

## Tell git to use it
git config --global credential.helper store
