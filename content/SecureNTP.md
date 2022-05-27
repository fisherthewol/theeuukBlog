Title: Securing NTP on Fedora 34.
Date: 2021-10-25 16:30
Category: linux
keywords: linux, NTP, fedora
lang: en
summary: Setting up secured NTP on Fedora 34, using ChronyD.

<abbr title="Network Time Protocol">NTP</abbr> is the protocol through which your computer ensures that the clock is accurate. It is [insecure](https://www.cs.bu.edu/~goldbe/papers/NTPattack.pdf), but now can be secured through the use of <abbr title="Network Time Security">NTS</abbr>. This post goes through the process of configuring NTS on Fedora 34. 

## Background.
I recently purchased a new laptop; a Dell Inspiron 14 5415.  
With a Ryzen 7 5700U processor, it's ideal for my coursework; and I have my 
desktop for gaming, so it's lack of D-GPU isn't an issue.  
And since I'm meant to be learning how to administer Linux systems, I thought 
I would install Fedora on it.  
At the time, Fedora 34 was the released version; Fedora 35 will likely be 
released on [the 2nd of November](https://fedorapeople.org/groups/schedule/f-35/f-35-key-tasks.html); and I plan on upgrading when released.  

## NTP During install.
During the install of Fedora, you are asked to set your Time Zone, and choose whether to use Network Time (and if not, to set your Time and Date manually). If you click the configuration icon, you get this image:

![A dialog window allowing you to add or remove NTP pools from your system configuration](https://docs.fedoraproject.org/en-US/fedora/f34/install-guide/_images/anaconda/DateTimeSpoke_AddNTP.png)
<figcaption>From: https://docs.fedoraproject.org/en-US/fedora/f34/install-guide/install/Installing_Using_Anaconda/</figcaption>

This is a nice visual configuration page for underlying NTP clients; and as you can see, it even allows you to set NTS!  
However, this tool doesn't necessarily handle various issues you could have: the main issue being your <abbr title="Real Time Clock">RTC</abbr> could be set "wrong" (IE in UTC when the NTP client expects it in your local-time, or vice versa).  
Hence, it makes a lot of sense to go and manually inspect your NTP configuration; even if you don't have a bug, it's still a learning experience!  

## A Brief Review of NTP.
Full disclosure: Here I am just re-hashing the contents of [this wikipedia chapter](https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_strata). However understanding this is useful (if not essential) for understanding configuration.  

NTP operates based on "stratum".  
At the heart of the protocol is Stratum 0; these are highly accurate hardware clocks (often Nuclear Clocks using caesium decay), that generate an interrupt at a regular interval, and this interrupt generates a timestamp.  
To retain accuracy, these stratum 0 clocks do not talk to the network, or run any other software (ideally). Hence, they are physically attached to Stratum 1 server(s), who deal with network requests, sanity checks (by peering with ), etc.  
You cannot generally access stratum 0 or 1 servers from your NTP client; although stratum 1 servers are generally connected to the public internet, they generally don't allow enough bandwidth to deal with millions of requests, hence delegating to lower stratums.  
Below this, servers synchronise with the stratum above themselves for the reference time, and with other same-stratum servers to perform sanity checks; Your client will likely connect with stratum 3 or 4 servers to get the time.  
When connecting to a server, your client does fancy maths with timestamps, and works out the **offset** (and <abbr title="Round Trip Time Delay">RTD</abbr>) between your system's RTC and the Server's System Time.  
By changing your system clock gradually and then polling again, your client eventually syncs your clock with the remote clock.  

## Choice of Client.
The reference NTP client (on GNU/Linux) is NTPD; this has many implementations, such as OpenBSD's [OpenNTPD](https://www.openntpd.org/).  
However, reference clients are designed for systems that are connected to the internet consistently. Most modern devices aren't connected consistently; they go to sleep, resume, have spotty connections, and so on. Hence the reference clients aren't ideal anymore, outside of the realm of servers.  
Enter [chrony](https://chrony.tuxfamily.org/). chrony is a modern NTP client, and self-describes as "performing well" in many situations, including "systems that do not run continuosly[sic]" and "intermittent network connections".  
And, at least on Fedora Workstation 34, chrony is the default NTP client for Fedora! So all that remains is to configure it.  

## Configuration.
chrony provides `chronyc`, a command line client for configuring `chronyd` (the daemon for synchronising time).  
Configuration can be made through `chronyc`, but using the configuration file provides a more well-defined configuration.  
The relevant configuration file is `/etc/chrony.conf`.  
The main thing you should be altering is the start of the file, the lines that start with `pool` or `server`.  

### Choice of Servers.
I personally chose [Cloudflare's Time Service](https://blog.cloudflare.com/secure-time/), `time.cloudflare.com`, as the first server in my config. They support NTS (the linked blog says to use port 1234, but **this has since changed**; now just point your NTS client at the default address), is operated over their CDN (so you will get a relatively local server), and is operated by a (relatively) reputable group.  
Following cloudflare, I chose to use [pool.ntp.org](https://www.ntppool.org)'s Europe servers, `[0-3].europe.pool.ntp.org`. There are country-specific servers availiable, but they are few in number, and this can cause you to lose accuracy, should they fail.  
Hence, the beginning of my config looks like this:

    # Servers of user's choice:
    server time.cloudflare.com iburst nts
    pool 0.europe.pool.ntp.org iburst
    pool 1.europe.pool.ntp.org iburst
    pool 2.europe.pool.ntp.org iburst
    pool 3.europe.pool.ntp.org iburst

Note the difference between the `server` and `pool` directives; time.cloudflare uses a CDN to distribute requests, but presents itself as a singular NTP server; the pool.ntp.org servers are actual NTP Pools, where you make a request to the IP and expect to get back some IP address to make the actual NTP request.  
The `iburst` directive informs chrony to send a burst of requests to do the first (initial, hence *i*burst) update sooner; and to do the same on network resumption (this ability is one of the reasons chrony is more suitable for modern devices).  
I declared NTS for cloudflare, because it is the primary source for the time on my device and they support it. I could't find explicit information on whether pool.ntp.org supports NTS, so I don't use it for their servers; and they aren't my primary source, so it's not a large issue.  

### Further Hardening of Chrony.
By default, chronyd runs as a privileged process.  
To drop it to an un-privileged process after the start-up, you can either invoke the binary with `-u`, or specify a `user` directive in `chrony.conf`:

    # Drop to chrony user
    user chrony

This means if chrony does have a vulnerability, there is another layer of defense between the attacker and your system.  

Similarly, you can disable the usage of chronyc (except by root or the `chrony` user) by disabling the IPv4|6 command sockets:
    
    # Disable cmdport
    cmdport 0

There is the option to filter system calls, but this requires chrony to be built with `seccomp` support, and requires that you check the filter will work on your system. I am unclear as to how you check this last section, so I haven't investigated it.  

After making these changes, reload the `chronyd` service (`systemctl restart chronyd` on systemd), and check if the changes took effect.

## Verifying Configuration.
The only thing to note: Your network's DHCP can effect what time servers are configured. For example, when I am on eduroam at Hull, the DHCP changes my servers to `infoblox[0-<unknown>]west.hull.ac.uk`.  
Barring this, you can check your configuration using various commands.  
First, check `cmdport 0` took effect by trying to run `chronyc tracking` as a normal user; you shouldn't be able to connect to chronyd:

    $ chronyc tracking
    506 Cannot talk to daemon

Then, running it as root should get you a response with your preferred server:

    $ sudo chronyc tracking
    Reference ID    : HEXHEXHEX (<Preferred Server>)
    Stratum         : 3
    Ref time (UTC)  : Mon Oct 25 14:44:55 2021
    System time     : 0.000081310 seconds slow of NTP time
    Last offset     : -0.000012204 seconds
    RMS offset      : 0.102439336 seconds
    Frequency       : 0.738 ppm slow
    Residual freq   : +0.005 ppm
    Skew            : 0.447 ppm
    Root delay      : 0.011256067 seconds
    Root dispersion : 0.003665966 seconds
    Update interval : 256.4 seconds
    Leap status     : Normal

Using chronyc you can also check which sources are specifically in use; the entry beginning with `^*` is your primary/reference server.  

    $ sudo chronyc sources
    MS Name/IP address         Stratum Poll Reach LastRx Last sample               
    ===============================================================================
    ^* time.cloudflare.com           3   7    21    93   -278us[-1490ms] +/-   16ms
    ^- 168.119.4.163.polisystem>     3   6   377    33   -842us[ -842us] +/-   57ms
    ^- ntp-1.arkena.net              2   6   377    33  +3679us[+3679us] +/-   40ms
    ^- docker01.rondie.nl            3   6   377    32  +8376us[+8376us] +/-   83ms
    ...

You can also check `timedatectl` for some errors. A valid output is something like this:

    $ timedatectl
                   Local time: Mon 2021-10-25 15:48:21 BST
               Universal time: Mon 2021-10-25 14:48:21 UTC
                     RTC time: Mon 2021-10-25 14:48:20
                    Time zone: Europe/London (BST, +0100)
    System clock synchronized: yes
                  NTP service: active
              RTC in local TZ: no

As you can see, my RTC (the time set in the BIOS/UEFI) is set to <abbr title="Universal Coordinated Time">UTC</abbr>, while my current timezone is BST (UTC+0100).  
If this is not the case, you may get an error:
>    Warning: The system is configured to read the RTC time in the local time zone.  
>             This mode can not be fully supported. It will create various problems  
>             with time zone changes and daylight saving time adjustments. The RTC  
>             time is never updated, it relies on external facilities to maintain it.  
>             If at all possible, use RTC in UTC by calling  
>             'timedatectl set-local-rtc 0'.  

If you get this error, you should follow the instructions, and ensure that your RTC is set to the UTC time.  

## Conclusion.
Now, you should have an NTP client using NTS configured.  
However, this all depends on your DNS requests being valid. What happens if, for example, someone MitMs your DNS request for `time.cloudflare.com` and redirects it to their server?  
Securing DNS is the topic of my next post, and it's likely going to be a long one. See you then!  
(PS Apologies for not following on from my prior post; I'll circle back to it soon enough.)
