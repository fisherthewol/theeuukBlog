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
    $ dig santander.co.uk
    ...
    ;; ANSWER SECTION:
    santander.co.uk.	600	IN	A	193.127.210.145
    ...
    ;; Query time: 38 msec

    $ dig retail.santander.co.uk
    ...
    ;; ANSWER SECTION:
    retail.santander.co.uk.	  334	IN	CNAME	retail.lbi.santander.uk.
    retail.lbi.santander.uk.  185	IN	A	    193.127.210.129
    ...
    ;; Query time: 28 msec

Ok, so the login page CNAME's to something... and `lbi`, it looks like a load balancer. Let's try enabling DNSSEC and see what we get:

    #!console
    # With DNSSEC=true
    $ dig santander.co.uk
    ...
    ;; ANSWER SECTION:
    santander.co.uk.	600	IN	A	193.127.210.145
    ...
    ;; Query time: 120 msec

    $ dig retail.santander.co.uk
    ...
    ;; ANSWER SECTION:
    retail.santander.co.uk.	  334	IN	CNAME	retail.lbi.santander.uk.
    retail.lbi.santander.uk.  185	IN	A	    193.127.210.129
    ...
    ;; Query time: 4040 msec

Ok, so same results.... but in the second case, it takes 4040 msec to respond? Lets try `resolvectl`.

    #!console
    # DNSSEC disabled.
    $ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: 193.127.210.129        -- link: enp0s25
                            (retail.lbi.santander.uk)
    
    -- Information acquired via protocol DNS in 70.1ms.
    -- Data is authenticated: no; Data was acquired via local or encrypted transport: yes
    -- Data from: cache network

And with DNSSEC enabled?

    #!console
    # DNSSEC enabled.
    $ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: resolve call failed: DNSSEC validation failed: failed-auxiliary

Watching the logs (with `journalctl -u systemd-resolved -f`) also tells us that `DNSSEC validation failed for question retail.lbi.santander.uk IN A: failed-auxiliary`; so the CNAME from `retail.santander.co.uk` is fine, but when we get to `retail.lbi.santander.uk`, DNSSEC validation fails. *Ok, sure, but* we'd expect `DNSSEC=allow-downgrade` to mean we can at least bypass DNSSEC if it isn't enabled, and yet...

    #!console
    # With DNSSEC=allow-downgrade
    $ resolvectl query --legend=true retail.santander.co.uk
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
I am basing my understanding on [this cloudflare blog](https://www.cloudflare.com/en-gb/dns/dnssec/how-dnssec-works/), but in summary: When a non-DNSSEC resolver resolves, say, blog.cloudflare.com, the root nameservers cryptographically verify records returned for `com` are from the authoritative nameservers, `com`'s nameservers verify cloudflare, and cloudflare's verify the blog subdomain. When resolving a domain, various cryptographic entities - multiple public keys, signatures, etc - are requested from relevant servers, and checked against each other to verify that there is a chain of trust, from the root servers to the eventual (sub)domain.  
So, in this case:

* the root nameservers should verify nameservers for `uk`
* if Santander (UK) *doesn't* want DNSSEC, then:
    * They should not have a `DS` record for `santander`.
    * And hence there should be an (I believe) automatic `NSEC3` record in `uk` to state such.
* If they do, however:
    * Nameservers for `santander` will be verified by `uk`;
    * Nameservers for `lbi` verified by `santander`, and
    * Finally, `retail` verified by `lbi`.

In the diagram, we can see NSEC3 records for santander in uk, and the same for retail.santander in .co.uk; so why is `resolved` apparently attempting to verify DNSSEC and failing, even on allow-downgrade?



[^1]: The sticking point was Hull's use of Palo Alto's GlobalProtect VPN; a script Lydia wrote used to work on Linux with the openconnect client, but then stopped working. Once I didn't need access to the VPN, I could switch away from Windows completely.
[^2]: Santander UK's parent company.
[^3]: Except for SNI; this might be because it's a different form of SNI? Not sure. I need to look into this.
[^4]: I know I know, naughty me. It's on my todo list after this ordeal.