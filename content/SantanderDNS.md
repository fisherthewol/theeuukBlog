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
![Santander UK Online Banking login page.]({static}/images/loginpage.png)
As we can see, the domain here is `retail.santander.co.uk`; the main site is just `www.santander.co.uk`.  
Then I make the changes to secure my DNS: enable DNSoTLS, enable DNSSEC, and ensure SNI names for the nameservers are configured. Testing this setup at Cloudflare's [Browsing Experience Security Check](https://www.cloudflare.com/en-gb/ssl/encrypted-sni/) gets us the following results:
![A results page from Clouflare's Browsing Experience Security Check. Secure DNS, DNSSEC, and TLS1.3 are ticked; Secure SNI is not.]({static}/images/cloudflare.png)
We can see the changes took effect[^3]. Then, we can restart resolved with `systemctl restart systemd-resolved`, and flush the caches with `resolvectl flush-caches`. Now, lets try and connect to the login page again.
![A firefox error page when trying to access the previous login page.]({static}/images/badlogin.png)
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

And with DNS enabled?

    #!console
    # DNSSEC disabled.
    $ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: resolve call failed: DNSSEC validation failed: failed-auxiliary

Watching the logs (with `journalctl -u systemd-resolved -f`) also tells us that `DNSSEC validation failed for question retail.lbi.santander.uk IN A: failed-auxiliary`; so the CNAME from `retail.santander...` is fine, but when we get to `retail.lbi.santander.uk`, DNSSEC validation fails. *Ok, sure, but* we'd expect `DNSSEC=allow-downgrade` to mean we can at least bypass DNSSEC if it isn't enabled, and yet...

    #!console
    # With DNSSEC=allow-downgrade
    $ resolvectl query --legend=true retail.santander.co.uk
    retail.santander.co.uk: resolve call failed: DNSSEC validation failed: failed-auxiliary 

Same deal. So despite DNSSEC being theoretically disabled, we get a failure. To me, this suggests that *retail.lbi.santander.uk* indicates to 1.1.1.1 that it `supports` DNSSEC, but either has it misconfigured, or just plain isn't configured at all.

[^1]: The sticking point was Hull's use of Palo Alto's GlobalProtect VPN; a script Lydia wrote used to work on Linux with the openconnect client, but then stopped working. Once I didn't need access to that, I could switch away from Windows completely.
[^2]: Santander UK's parent company.
[^3]: Except for SNI; this might be because it's a different form of SNI? Not sure. I need to look into this.