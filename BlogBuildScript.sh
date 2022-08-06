#!/usr/bin/env bash
cd /var/www/blogbuild/
curl -LO  https://nightly.link/fisherthewol/theeuukBlog/workflows/main/main/BlogOutput.zip
unzip BlogOutput.zip
rm BlogOutput.zip
chown -R nginx:fisher-web .
find ./ -type f -exec chmod 0570 {} \;
find ./ -type d -exec chmod 2570 {} \;
cp -r ./* /srv/www/theeuuk/blog/
