#!/usr/bin/env bash
cd /var/www/blogbuild/

chown -R nginx:fisher-web .
find ./ -type f -exec chmod 0570 {} \;
find ./ -type d -exec chmod 2570 {} \;
#cp -r ./output/* /srv/www/theeuuk/blog/
