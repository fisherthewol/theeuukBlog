Title: Summary of Linux Distribution's actions on Mesa Hardware Acceleration Changes.
Date: 2023-11-21 23:00
Category: linux
keywords: linux, mesa, hwaccel,
lang: en
summary: Patent issues are painful.
state: published

In March 2022, the mesa libraries reviewed the patent licensing issues around h264, h265, and vc1; and [added a build-time flag](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/15258/diffs) to allow en/dis-abling these codecs. In response, various linux distributions either reconfigured their builds of mesa to either manually enable or disable the build flag. In response to the response to the library changes due to patent issues on hardware acceleration[^1], various people/builders/repos changed theirs to enable the build flag.  
This article is an attempt to summarise this for various distributions.  

| Distribution | Action Taken | Can you re-enable? How? | Notes. |
|---|---|---|---|
| Fedora (& downstream including CentOS) | [Disabled](https://src.fedoraproject.org/rpms/mesa/c/94ef544b3f2125912dfbff4c6ef373fe49806b52?branch=rawhide) in the default repositories. | Replace mesa packages with those from rpmfusion's freeworld. | This is my lived experience and, whilst it doesn't *break*, I often get "cannot upgrade package X" because of it. I think this would be solved by an `@mesa-freeworld` group in rpmfusion, which currently doesn't exist. |
| OpenSUSE | [Followed suite](https://build.opensuse.org/request/show/1006922). | Get the package from another repo in pac*k*man, or branch the build and edit the spec file. | I'm not an OpenSUSE user so I'm not giving either option as advice. I would imagine branching the build is more painful than using another repository? |
| Debian | Appears to be [Enabled](https://buildd.debian.org/status/fetch.php?pkg=mesa&arch=amd64&ver=22.3.6-1%2Bdeb12u1&stamp=1679519132&raw=0) by default in bookworm. |  | As far as I can tell with Meson, -D just means to pass an option; looking at the "User defined options" section of the build log suggests that it's enabled. |
| Ubuntu | As far as I can tell, does not patch the upstream build to disable codecs, unless LibVA is not enabled.... I think. |  |  |
| Arch | [Enabled](https://gitlab.archlinux.org/archlinux/packaging/packages/mesa/-/blob/main/PKGBUILD?ref_type=heads) as far as I understand. |  |  |
| Manjaro | [Disabled](https://gitlab.manjaro.org/packages/extra/mesa/-/blob/master/PKGBUILD), in that the build flag is removed from the PKGBUILD. | Install [mesa-git](https://aur.archlinux.org/packages/mesa-git) from the AUR, or manually build the package with Paru, re-adding the option to the PKGBUILD. |  |

Apologies for the poor formatting of the table; I can't work out how to make the table extend outside of the block in my pelican theme.  
Also if there's any other major distros that want adding, or if I've got anything wrong, please feel free to contact me.


[^1]: In response to the Oratrice Mecanique d'Analyse Cardinale. No I don't play Genshin, I just like the meme.