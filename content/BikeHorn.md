Title: Adding a horn to my Bike.
Date: 2022-06-01 14:00
Category: cycling
keywords: bikes, arduino, noise
lang: en
summary: Overkill, but reasonable.
status: draft

Hull is a remarkably flat city. The phrase in my native Sheffield is "You're always walking uphill, even when you get to the top"; in Hull, as soon as I have any height (or I'm on the train out of the city) I feel like my render distance is set too far.  
But that flatness makes it *really* great for cycling. I mean, the council did only start adding [protected bike lanes](https://www.hulldailymail.co.uk/news/hull-east-yorkshire-news/more-cycle-lanes-confirmed-hulls-6379590) during the pandemic, but in terms of terrain - you're only climbing 10, maybe 20 metres, at a ridiculously shallow gradient.  
On the other hand, I'm not the cleverest sod, and so until recently I never brought my bike to University - until this semester. Partially because I didn't have to go onto campus due to Covid, partially because my mother was using it for riding with a friend, but mostly because I couldn't convince myself I'd actually use it. But at the end of March I brought it back with me, and I've fallen back in love with cycling.

One minor problem: somehow the clapper on my bell has broken. It's essentially just a piece of plastic and I could 3D print a replacement. Or I could buy a new bell entirely. Or I could ride without a bell. However, I don't have a 3d printer, a new bell feels wasteful for just one part, and not having a bell... It's effectively where I'm at right now, and it's not fun.  
I do on the other hand have an arduino, some other components, and a penchant for overkill. Lets fit a horn to my bike.

# My Bike.
First thing is to think about mounting. I have a Claude Butler WHAT!!, gifted to me from the widow of a neighbour. It has a rear rack, that is relatively securely fixed to the rear; but I have no documentation on how much mass the bike or rack is rated for. Still, it's a point to consider mounting something.  
About mounting, there's a few places where I could mount *something*; the rack, under the top tube (although I would need to be careful of the cables), and the handlebar. Obviously any part of the system I interact with whilst riding should be on the handlebar, but the rest of it can be hidden away elsewhere.

# Options.
In the vein of maximum overkill, my immediate thought was "train horn"; loud enough that I'll likely burst my ear drums, but I doubt I'll ever get run over by a car if I have one. This thought was quickly kiboshed: train horns need serious amounts of air, which necessitates an air compressor - which itself needs a lot of power. [It has been done](https://youtu.be/cnr6uGIV8no), and I already thought "I could compress air at home and just take a cylinder with me"; but I don't have an air compressor, and a pressure cylinder is still going to be a lot of mass on its own. Hence we can rule train horns out.

## Specifications.
Ok, so if we're not allowed train horns, it might be worth sorting out some form of specification; that way we can actually make a choice.
