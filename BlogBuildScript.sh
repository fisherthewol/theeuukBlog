#!/usr/bin/env bash
cd /var/www/blogbuild/
git pull
pipenv lock
pipenv sync
pipenv run pelican --ignore-cache -s publishconf.py content
cd ./output
chown -R nginx:fisher-web .
find ./ -type f -exec chmod 0570 {} \;
find ./ -type d -exec chmod 2570 {} \;
cp -r ./* /srv/www/theeuuk/blog/
