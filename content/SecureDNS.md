Title: Securing DNS on Fedora 35.
Date: 2022-02-01 14:03
Category: linux
keywords: linux, DNS, Fedora
lang: en
summary: It's always the DNS...

In the [previous article]({filename}/SecureNTP.md) we secured our NTP configuration. However you will have likely noticed that the NTP servers are given as domain names, rather than IP addresses. This has benefits; as mentioned, one name can map to multiple actual hosts, allowing for better geolocation, and for load-balancing.
However it also poses a risk; an attacker could modify the address an NTP domain resolves to, either at the authoritative nameservers or (more likely) at a local nameserver, in an attack known as [DNS cache poisoning](https://en.wikipedia.org/wiki/DNS_spoofing). And since having accurate time is needed for good security (among others, a good few attacks are mitigated through accurate checking of certificate expiry), having "secure" NTP is not much use if the resolution of domain names is insecure.  
So, in a similar vein to NTS for NTP, DNS can equally be secured. This post looks in to how to do so on Fedora, initially with Fedora 34 but later updated to 35, on the same laptop as the previous article.  

## DNS and Secure DNS.
I won't describe the nature of DNS here; there are better explanations from [Computerphile](https://youtu.be/uOfonONtIuk) and from [Noah Kantrowitz](https://coderanger.net/) as part of their talk, [How the Internet Works](https://youtu.be/rLojliq6n0Q). However in short, DNS is the method by which your computer translates theeu.uk into 185.52.3.128; or vice versa since my PTR record is correct. I am embedding the Computerphile video here for your convenience.  
<iframe width="600" height="338" src="https://www.youtube-nocookie.com/embed/uOfonONtIuk" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
For this article, we are configuring what I would describe as a *local stub resolver* on our system.  

### Options for securing DNS.
There are two main options for securing DNS. There is [DNS over HTTPS](https://en.wikipedia.org/wiki/DNS_over_HTTPS), in which the DNS request is sent to a HTTPS endpoint, using the *application/dns-message* MIME type. Alternatively, there is [DNS over TLS](https://en.wikipedia.org/wiki/DNS_over_TLS), in which the request and answers of a query are encrypted using TLS (Note that DNSoTLS doesn't ensure that the server answering your response is actually valid; this is provided by [DNSSEC](https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions)).  
My preference is towards DNSoT, as it behaves like normal DNS traffic except encrypted; this means that most assumptions around DNS still hold, and for easy "downgrades" back to DNS when needed (EG if you're on an internal network, aren't allowed to use DoT, and need functional DNS; reverting your system back from DoT is likely easier than from DoH). DNSoH has its merits; for example it can be implemented in any application with HTTPS functionality, bypassing the system's DNS configuration. But today I'd rather have one central system-level DNS setup instead of multiple places where DNS could be configured.

## Which resolver?
In Fedora 34/35 the default DNS resolver is `systemd-resolved`; a change that was made in [Fedora 33](https://fedoraproject.org/wiki/Changes/systemd-resolved). Systemd-resolved is a daemonized stub resolver; the binary is located at `/usr/lib/systemd/systemd-resolved` and is provided by `systemd-resolved-249.9-1.fc35.x86_64` on my system. We can validate that it is our stub resolver by checking what is listening on port 53, the DNS port, using [`ss`](https://man7.org/linux/man-pages/man8/ss.8.html):

    $ sudo ss -pat '( dport = :53 or sport = :53 )'
    Place your finger on the fingerprint reader
    State      Recv-Q     Send-Q               Local Address:Port                 Peer Address:Port          Process
    LISTEN     0          32                   192.168.122.1:domain                    0.0.0.0:*              users:(("dnsmasq",pid=1743,fd=6))
    LISTEN     0          4096                 127.0.0.53%lo:domain                    0.0.0.0:*              users:(("systemd-resolve" pid=1315,fd=17))

You'll notice that I have two services listening on port 53. dnsmasq is listening on `192.168.122.1`, whereas resolved is listening on `127.0.0.53`. The former is a private IP address, the latter is a loopback address. dnsmasq is installed because libvirt is installed; libvirt is needed for virtualisation and I use it specifically for Android development. Still, we can see that clients can interact with systemd-resolved through the loopback address. Clients can also interact with it through D-Bus on [`org.freedesktop.resolve1`](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html), or through glibc calls.  

## Configuring resolved.
The next question, then, is how do we configure systemd-resolved? We could send it commands through D-Bus, but that doesn't necessarily store the configuration. A configuration file would be useful. A cursory search leads us to the [Arch Wiki](https://wiki.archlinux.org/title/Systemd-resolved) that says the configuration file is `/etc/systemd/resolved.conf`. Checking this file, after having already attempted to setup DNSoT, I find that it hasn't been modified, but it does include a useful note:

    # Entries in this file show the compile time defaults. Local configuration
    # should be created by either modifying this file, or by creating "drop-ins" in
    # the resolved.conf.d/ subdirectory. The latter is generally recommended.
    # Defaults can be restored by simply deleting this file and all drop-ins.
    #
    # Use 'systemd-analyze cat-config systemd/resolved.conf' to display the full config.

And running `systemd-analyze cat-config systemd/resolved.conf` reveals that I have indeed used a drop-in, `10-DNSoverTLS.conf`:

    [Resolve]
    DNS=1.1.1.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com
    DNSOverTLS=true
    DNSSEC=true
    FallbackDNS=8.8.8.8#dns.google 2001:4860:4860::8888#dns.google
    Domains=~.

This tells resolved that:  

* Our default resolver should be 1.1.1.1 on ipv4 and equivalent on v6; with `cloudlfare-dns.com` as the <abbr title="Server Name Indication">SNI</abbr> (part of TLS).  
* Use DNSoTLS.  
* Enable DNSSEC.  
* If we can't contact 1.1.1.1, use 8.8.8.8  
* And, importantly, ~. means prefer this rule for all domains.  

This seems to be what we want. We've got DNSoTLS working, with DNSSEC, with fallback servers. How do we validate that this is working?  

## Validation.
To validate DNSoTLS and your configuration, you can use `resolvectl`:

    $ resolvectl
    Global
           Protocols: LLMNR=resolve -mDNS +DNSOverTLS DNSSEC=yes/supported
           resolv.conf mode: stub
           Current DNS Server: 1.1.1.1#cloudflare-dns.com
           DNS Servers: 1.1.1.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com
           Fallback DNS Servers: 8.8.8.8#dns.google 2001:4860:4860::8888#dns.google
           DNS Domain: ~.
    
    Link 2 (wlp2s0)
        Current Scopes: DNS LLMNR/IPv4 LLMNR/IPv6
             Protocols: +DefaultRoute +LLMNR -mDNS +DNSOverTLS DNSSEC=yes/supported
    Current DNS Server: 192.168.1.1
           DNS Servers: 192.168.1.1
            DNS Domain: lan

    Link 3 (virbr0)
        Current Scopes: none
             Protocols: -DefaultRoute +LLMNR -mDNS +DNSOverTLS DNSSEC=yes/supported

The global settings confirm what we put in our drop-in is being used. The `Link 2` settings tell us that for `lan` domains (I believe this means example.lan), it will resolve them with 192.168.1.1; this is useful for local.  

## Conclusion.
So we're done then? Not quite. We have valid DNSoverTLS and DNSSEC, sure; so our DNS requests should be relatively secure. However, our global configuration means that, should a certain network have internal and external IPs, if the DHCP for that network doesn't specify more specific domains that `~.`, we'll get some funky issues.  
This is the case with eduroam at Hull, and I was hoping to cover it in this article; but I've spent a little too long on this topic, and am currently off-campus. So I will return to this and work it out later. See you then!