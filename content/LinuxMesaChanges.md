Title: Summary of Linux Distribution's actions on Mesa Hardware Acceleration Changes.
Date: 2023-11-18 18:00
Category: linux
keywords: linux, mesa, hwaccel,
lang: en
summary: Patent issues are painful.
state: draft

Earlier (when??) the mesa libraries stopped building in hardware acceleration for some codecs (WHICH??) by default(; hiding it behind a flag?? might have been behind a flag already but changed default). In response, various distributions either reconfigured their builds to either manually enable or disable the build flag. In response to the response to the library changes due to patent issues on hardware acceleration[^1], various people/builders/repos changed theirs to enable the build flag.  
This article is an attempt to summarise this for various distributions.  

| Distribution | Action Taken                          | Can you re-enable? How?                                      | Notes. |
|--------------|---------------------------------------|--------------------------------------------------------------|--------|
| Fedora       | Disabled in the default repositories. | Replace mesa packages with those from rpmfusion's freeworld. |        |
|              |                                       |                                                              |        |
|              |                                       |                                                              |        |
|              |                                       |                                                              |        |

[^1]: In response to the Oratrice Mecanique d'Analyse Cardinale. No I don't play Genshin, I just like the meme.