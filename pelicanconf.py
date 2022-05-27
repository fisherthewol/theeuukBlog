#!/usr/bin/env python
# -*- coding: utf-8 -*- #

# Settings for development.

AUTHOR = 'Fisher'
SITENAME = "Fisher's Blog"
SITEURL = ''
THEME = 'blue-penguin'
TYPOGRIFY = True

PATH = 'content'

TIMEZONE = 'Europe/London'

DEFAULT_LANG = 'en'

# Feed generation is usually not desired when developing
FEED_ALL_ATOM = None
CATEGORY_FEED_ATOM = None
TRANSLATION_FEED_ATOM = None
AUTHOR_FEED_ATOM = None
AUTHOR_FEED_RSS = None

# Menu (blue-penguin)
MENUITEMS = (('Main Site', 'https://theeu.uk'),
             ('Github',    'https://github.com/fisherthewol'),
             ('Flickr',    'https://flickr.com/fisherthewol'),)

DEFAULT_PAGINATION = 10

# Uncomment following line if you want document-relative URLs when developing
RELATIVE_URLS = True

SUMMARY_MAX_LENGTH = 50
