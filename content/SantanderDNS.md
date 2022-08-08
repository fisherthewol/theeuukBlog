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
With the default dns configuration, using 1.1.1.1 and 8.8.8.8, I can log into to online banking easily; to demonstrate, here I load the log-in page for it.



[^1]: The sticking point was Hull's use of Palo Alto's GlobalProtect VPN; a script Lydia wrote used to work on Linux with the openconnect client, but then stopped working. Once I didn't need access to that, I could switch away from Windows completely.
[^2]: Santander UK's parent company.