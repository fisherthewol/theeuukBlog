Title: Santander has broken Nameservers.
Date: 2022-08-18 14:00
Category: sysadmin
keywords: dns, banking, sysadmin
lang: en
summary: And somehow, I will get them fixed.

I switched to Santander UK's student account last year, as it provided the best value for me. However I noticed I couldn't access their Online Banking from my laptop (who's DNS I secured [previously]({filename}/SecureDNS.md)); at the time I thought nothing of it, as my Windows desktop was fine, and I have the mobile app.  
However, I have recently moved my desktop over to Fedora[^1], and set about securing my DNS in the same fashion; and again, lost access to Online Banking on the device. Hmm, something smells *interesting* here. I am not the first to notice this; it would seem that it's a [known problem](https://community.cloudflare.com/t/problem-with-secure-cahoot-com-and-lbi-santander-uk/94235) when trying to resolve Banco Santander's[^2] addresses used in online banking through Cloudflare's [1.1.1.1](https://1.1.1.1/). However it is not a fault with Cloudflare, but instead with some configuration on Santander's end.  
My aim here is to make some form of root-cause analysis as to what is wrong (as best I can from the outside of their systems), document it, and attempt to get them to change it.

## Symptoms
With the default DNS configuration, using 1.1.1.1 and 8.8.8.8, I can log into to online banking easily; to demonstrate, here I load the log-in page for it.  
![Santander UK Online Banking login page.]({static}/images/santander/loginpage.png)
As we can see, the domain here is `retail.santander.co.uk`; the main site is just `www.santander.co.uk`.  
Then I make the changes to secure my DNS: enable DNSoTLS, enable DNSSEC, and ensure SNI names for the nameservers are configured. Testing this setup at Cloudflare's [Browsing Experience Security Check](https://www.cloudflare.com/en-gb/ssl/encrypted-sni/) gets us the following results:
![A results page from Clouflare's Browsing Experience Security Check. Secure DNS, DNSSEC, and TLS1.3 are ticked; Secure SNI is not.]({static}/images/santander/cloudflare.png)
We can see the changes took effect[^3]. Then, we can restart resolved with `systemctl restart systemd-resolved`, and flush the caches with `resolvectl flush-caches`. Now, lets try and connect to the login page again.
![A firefox error page when trying to access the previous login page.]({static}/images/santander/badlogin.png)
Hmm.. Interesting. I can confirm the positive behaviour is when `DNSSEC=false` is set in my config, regardless of any other settings; negative behaviour occurs when DNSSEC is set to either `allow-downgrade` *or* `true`. Let's see what `dig` says:

    #!console
    # With DNSSEC disabled.
    λ dig santander.co.uk
    ...
    ;; ANSWER SECTION:
    santander.co.uk.	600	IN	A	193.127.210.145
    ...
    ;; Query time: 38 msec

    λ dig retail.santander.co.uk
    ...
    ;; ANSWER SECTION:
    retail.santander.co.uk.	  334	IN	CNAME	retail.lbi.santander.uk.
    retail.lbi.santander.uk.  185	IN	A	    193.127.210.129
    ...
    ;; Query time: 28 msec

Ok, so the login page CNAME's to something... and `lbi`, it looks like a load balancer. Let's try enabling DNSSEC and see what we get:

    #!console
    # With DNSSEC=true
    λ dig santander.co.uk
    ...
    ;; ANSWER SECTION:
    santander.co.uk.	600	IN	A	193.127.210.145
    ...
    ;; Query time: 120 msec

    λ dig retail.santander.co.uk
    ...
    ;; ANSWER SECTION:
    retail.santander.co.uk.	  334	IN	CNAME	retail.lbi.santander.uk.
    retail.lbi.santander.uk.  185	IN	A	    193.127.210.129
    ...
    ;; Query time: 4040 msec

Ok, so same results.... but in the second case, it takes 4040 msec to respond? Lets try `resolvectl`.

    #!console
    # DNSSEC disabled.
    λ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: 193.127.210.129        -- link: enp0s25
                            (retail.lbi.santander.uk)
    
    -- Information acquired via protocol DNS in 70.1ms.
    -- Data is authenticated: no; Data was acquired via local or encrypted transport: yes
    -- Data from: cache network

And with DNSSEC enabled?

    #!console
    # DNSSEC enabled.
    λ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: resolve call failed: DNSSEC validation failed: failed-auxiliary

Watching the logs (with `journalctl -u systemd-resolved -f`) also tells us that `DNSSEC validation failed for question retail.lbi.santander.uk IN A: failed-auxiliary`; so the CNAME from `retail.santander.co.uk` is fine, but when we get to `retail.lbi.santander.uk`, DNSSEC validation fails. *Ok, sure, but* we'd expect `DNSSEC=allow-downgrade` to mean we can at least bypass DNSSEC if it isn't enabled, and yet...

    #!console
    # With DNSSEC=allow-downgrade
    λ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: resolve call failed: DNSSEC validation failed: failed-auxiliary 

Same deal. So despite DNSSEC being theoretically disabled, we get a failure. To me, this suggests that *retail.lbi.santander.uk* indicates to 1.1.1.1 that it `supports` DNSSEC, but either has it misconfigured, or just plain isn't configured at all.

## What's Wrong?
Ok, we know it's something to do with DNSSEC, "lbi" (which I guess is a load balancer), and Cloudflare's resolver. I'm giving cloudflare the benefit of the doubt here, at least for the moment.  
There's a lovely tool called [DNSVIS](https://dnsviz.net), that allows us to visualise what's going on. Let's see what it says for my website, where I know I haven't configured DNSSEC at all[^4]:
![A visualisation of the DNS chain for theeu.uk]({static}/images/santander/noDNSSEC.svg)
As we can see, DNS root `.` has a secure setup; as does `.uk`. However my website does not; I have my various records, but no `DNSKEY` record; as well, `.uk` has a `NSEC3` record that records there is *no* `DS` record for my domain. For comparison, let's look at the setup for `www.internetsociety.org`:
![A visualisation of the DNS chain for www.internetsociety.org]({static}/images/santander/yesDNSSEC.svg)
This is a known-correct setup. Now lets compare with `retail.santander.co.uk`:
![A visualisation of the DNS chain for retail.santander.co.uk]({static}/images/santander/retailSantander.png)
In this, we can see errors marked on the diagram: Some server for `santander.uk` didn't respond to a request at `/DNSKEY`, some server for `lbi.santander.uk` behaved the same, and the servers 193.127.25*2-3*.1 "did not respond authoritatively for the namespace".
To understand all of this, we will have to go into detail about how DNSSEC works; but we can preface it by saying "Banco Santander should fix these errors, either so DNSSEC works, or at least so it doesn't prevent people from accessing their systems.

## DNSSEC: Cryptographic Verification.
I am basing my understanding on [this cloudflare blog](https://www.cloudflare.com/en-gb/dns/dnssec/how-dnssec-works/), but in summary: When a DNSSEC-enabled resolver resolves, say, blog.cloudflare.com, the root nameservers cryptographically verify records returned for `com` are from the authoritative nameservers, `com`'s nameservers verify cloudflare, and cloudflare's verify the blog subdomain. When resolving a domain, various cryptographic entities - multiple public keys, signatures, etc - are requested from relevant servers, and checked against each other to verify that there is a chain of trust, from the root servers to the eventual (sub)domain.  
So, in this case:

* the root nameservers should verify nameservers for `uk`
* if Santander (UK) *doesn't* want DNSSEC, then:
    * They should not have a `DS` record for `santander`.
    * And hence there should be an (I believe) automatic `NSEC3` record in `uk` to state such.
* If they do, however:
    * Nameservers for `santander` will be verified by `uk`;
    * Nameservers for `lbi` verified by `santander`, and
    * Finally, `retail` verified by `lbi`.

In the diagram, we can see NSEC3 records for santander in uk, and the same for retail.santander in .co.uk; so why is `resolvectl/resolved` apparently attempting to verify DNSSEC and failing, even on allow-downgrade? If we `dig @1.1.1.1` we can see what dig is getting back, and we can assume resolved is doing a similar thing.  
First, let's find out what the name servers are. for santander.uk, from 1.1.1.1:

    #!console
    λ dig @1.1.1.1 NS santander.uk
    ...
    ;; ANSWER SECTION:
    santander.uk.		14400	IN	NS	dns1.cscdns.net.
    santander.uk.		14400	IN	NS	dns2.cscdns.net.

Then, let's become our own recursive resolver and ask these nameservers where to find the Nameservers for lbi.santander.uk:

    #!console
    # First, find the IP of the nameserver
    λ dig @1.1.1.1 A dns1.cscdns.net.
    ...
    ;; ANSWER SECTION:
    dns1.cscdns.net.	6045	IN	A	156.154.130.100
    # Then ask the name server the NS for the subdomain:
    λ dig @156.154.130.100 NS lbi.santander.uk
    ...
    ;; AUTHORITY SECTION:
    lbi.santander.uk.	600	IN	NS	ns1.santander.uk.
    lbi.santander.uk.	600	IN	NS	ns2.santander.uk.

    ;; ADDITIONAL SECTION:
    ns1.santander.uk.	600	IN	A	193.127.252.1
    ns2.santander.uk.	600	IN	A	193.127.253.1
    # Ok, so we know the name server. Let's query it for the nameserver retail.lbi.santander.uk.
    λ dig @193.127.252.1 NS retail.lbi.santander.uk
    ;; connection timed out; no servers could be reached

Right.... So the nameservers for lbi.santander.uk time out when asking what the nameservers are for retail.lbi...; Let's try for an A record?

    #!console
    λ dig @193.127.252.1 A retail.lbi.santander.uk
    ...
    ;; ANSWER SECTION:
    retail.lbi.santander.uk. 600	IN	A	193.127.211.1
    
    ;; Query time: 23 msec
    ...

Ah, so the Nameserver for `lbi.santander.uk` will resolve records for retail.lbi.santander.uk. Let's try seeing what santander.uk says is the NS servers for this url:

    #!console
    λ dig @156.154.130.100 NS retail.lbi.santander.uk
    ;; AUTHORITY SECTION:
    lbi.santander.uk.	600	IN	NS	ns1.santander.uk.
    ...
    ;; ADDITIONAL SECTION:
    ns1.santander.uk.	600	IN	A	193.127.252.1

Ok, so it says it's all ns1.santander.uk. Let's try querying 193.127.252.1 for various DNSSEC records. Theoretically all we should get is an NSEC3:

    #!console
    λ dig @193.127.252.1 NSEC3 retail.lbi.santander.uk
    ...
    ;; connection timed out; no servers could be reached

Right, so the only nameserver that we can get for retail.lbi.santander.uk, which is actually the NS for lbi.santander.uk, will resolve A records correctly, but will not respond when asked for NSEC3.  
We can prove that uk. has an NSEC3 for santander.uk., with `dig @156.154.100.3 +dnssec NSEC santander.uk`; this spits out some NSEC3 records. So essentially, the NS for santander.uk itself is almost configured correctly; if asked for something it doesn't understand, it returns the SOA record. when it should return an empty answer section or otherwise indicate the error [^5]. However, the resolvers `ns1/ns2.santander.uk` are incorrectly configured and will just drop the connection.  

I believe this may well be Santander attempting security by obscurity; by dropping all but a few queries, they believe they are hiding everything but what they want you to see, or that they prevent DNS amplification attacks. It's an easy choice to make, but it really hides nothing, and in return breaks people's access to their online banking; it has some effect on stopping DNS amplification attacks, but they could [implement one or many of these suggestions](https://www.cloudflare.com/en-gb/learning/ddos/dns-amplification-ddos-attack/), and not break access. I'm not quite sure what exactly is breaking, but as stated in [one of the threads](https://community.cloudflare.com/t/online-banking-timeout/14985/5) about it on cloudflare's forums, it may well be something to do with "QNAME minimisation" that cloudflare does. I am also unsure as to how exactly it would be fixed - but my gut instinct is *stop dropping the request, unless you believe it's trully malicious, and just return an empty answer section like you're supposed to.* I appreciate this isn't the full conclusion I may have promised, but it's as far as I believe can get from outside Santander's systems, and I have no intention of trying to break in.

I plan on getting in contact with Santander, through their chat or by messaging an employee on linkedin, and asking them to fix this. I can at least point them towards where to look and some vague description of what is wrong, if I can't actually tell them the extreme specifics. If that doesn't help, a trip to the AGM in Madrid sounds like a fun holiday at some point.


[^1]: The sticking point was Hull's use of Palo Alto's GlobalProtect VPN; a script [Starbeamrainbowlabs](https://starbeamrainbowlabs.com/) wrote used to work on Linux with the openconnect client, but then stopped working. Once I didn't need access to the VPN, I could switch away from Windows completely.
[^2]: Santander UK's parent company.
[^3]: Except for SNI; this might be because it's a different form of SNI? Not sure. I need to look into this.
[^4]: I know I know, naughty me. It's on my todo list after this ordeal.
[^5]: See RFC 1034 §3.7, specifically the paragraph on page 14-15.