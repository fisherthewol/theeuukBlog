#!/usr/bin/env bash
cd /var/www/blogbuild/
curl https://nightly.link/fisherthewol/theeuukBlog/workflows/main/main/BlogOutput
chown -R nginx:fisher-web .
find ./ -type f -exec chmod 0570 {} \;
find ./ -type d -exec chmod 2570 {} \;
#cp -r ./output/* /srv/www/theeuuk/blog/
