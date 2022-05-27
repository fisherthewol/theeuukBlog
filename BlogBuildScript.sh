#!/bin/bash
cd location-of-repo
pipenv run pelican --ignore-cache -s publishconf.py content
cp -r ./output/ /path/to/destination
chown user:group /destination/
chmod MODE /destination/
