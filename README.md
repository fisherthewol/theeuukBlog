# theeuukBlog  
Files for my blog (at https://theeu.uk/blog). I intend on writing a script to pull this repo and build the blog, to run on a regular basis.  
Alternative thought would be a CI flow on github, but then I'd have to give github access to my system :)

## Quickstart
1. Clone this repo.
2. Clone [blue-penguin](https://github.com/jody-frankowski/blue-penguin) somewhere (adjacent is good).
3. Within this repo, run `pipenv sync`.
4. Within this repo, run `pipenv run pelican-themes --install <blue-penguin location>`.
5. Within this repo, run `pipenv run pelican -l -s ./pelicanconf.py`.