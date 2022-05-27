Title: sudo and the world of Linux Authentication, Part 1.
Date: 2021-04-02 06:27
Category: linux
keywords: linux, sudo, permissions
summary: How does sudo authenticate you, check you are allowed sudo, and escalate to root?

Let's take a look at what happens when you use `sudo`.

    #!bash
    $ sudo mysql
    [sudo] password for <this user>:
    Welcome to the MySQL monitor.  Commands end with ; or \g.
    ...
    mysql>

The result of `sudo mysql` is a mysql prompt, connected as MySQL user `'root'@'localhost'` (using `auth_socket`).  
This raises the following questions:

1. How does `sudo` authenticate you?
2. How does `sudo` validate that you are allowed to escalate to root?
3. Once validated, how does `sudo` invoke commands as root?

First, we'll take a look at how this works in the context of a single system.  
Then, we can take a look at it can work in the context of a business or network of systems.  

## What is sudo?
According to the manpage:
> sudo allows a permitted user to execute a command as the superuser or another user, as specified by the security
> policy.

In effect, `sudo` is how we run commands as root, or as any user by using `sudo -u <username>`.  
`sudo` is a method of privilege separation. Certain commands and files may only be used by root, but escalating to a root prompt is non-ideal; if you forget to exit this prompt, you may inadvertently run a command that causes damage to your system. 
Another advantage of `sudo` is auditing; `sudo` produces logs that may be used to audit who did what. If the details of an account are breached, the logs can still be used to trace a breach to a given account.  

There are many implementations, sources, and versions of `sudo`; On my system running Ubuntu 20.04.2, `sudo` is located at `/usr/bin/sudo`. It's provided by the package [sudo](https://packages.ubuntu.com/focal/sudo), maintained by the Ubuntu Maintainers; however the upstream source is likely to come from the team at [sudo.ws](https://www.sudo.ws/).

## 1. How does sudo authenticate you?
When we invoked `sudo` above, we are prompted for the password of *our* user.  
This is done to validate that the person at the console is, in fact, the owner of the account; checking if that user is allowed to escalate to root is done later.  
But *how* does it know how to authenticate; whether to ask for just a password, or also to ask for a 2fa token?  

This all comes down to PAM, pluggable authentication modules.  
#### PAM
PAM, or more specifically [Linux-PAM](http://www.linux-pam.org/), is a standard for writing programmes independent of authentication.  
The underlying flow is that, to authenticate a user, the programme invoke PAM's API. PAM then inspects its configuration for which modules to ask about this user, calls these modules and asks them; these modules then respond with values, which are placed on a stack. The result of this stack is determined at the end of PAM's execution, which then informs the invoking programme.  
This result may purely be a boolean `true/false`, or it may be more detailed. PAM's modules can also create sessions, talk to LDAP/Active Directory/Kerberos, and much more.

Let's dissect the PAM configuration file for `sudo` on my machine. The guide for system administrators can be found at [linux-pam.org](http://www.linux-pam.org/Linux-PAM-html/Linux-PAM_SAG.html); in particular, the file syntax is found [here](http://www.linux-pam.org/Linux-PAM-html/sag-configuration-file.html).

    #!bash
    $ sudo less /etc/pam.d/sudo
    #%PAM-1.0
    
    session    required   pam_env.so readenv=1 user_readenv=0
    session    required   pam_env.so readenv=1 envfile=/etc/default/locale user_readenv=0
    @include common-auth
    @include common-account
    @include common-session-noninteractive

`session` means the module invoked is "doing things that need to be done for the user before/after they can be given service". In this case, pam_env "sets/unsets environment variables". This makes sense; a user may have bad environment settings we don't want under root, and the root environment will need setting up.
`required` tells us that, if this module fails/returns a failure (for example, the password is wrong), the stack will likely be a failure; however it does not cause a failure yet.  
So, all the specific configuration for `sudo` does is make sure the environment is set for root, then call the regular authentication configurations.  
  
The next step is common-auth. The main contents of common-auth are below.
    
    #!bash
    # here are the per-package modules (the "Primary" block)
    auth    [success=1 default=ignore]      pam_unix.so nullok_secure
    # here's the fallback if no module succeeds
    auth    requisite                       pam_deny.so
    # prime the stack with a positive return value if there isn't one already;
    # this avoids us returning an error just because nothing sets a success code
    # since the modules above will each just jump around
    auth    required                        pam_permit.so
    # and here are more per-package modules (the "Additional" block)
    auth    optional        pam_ecryptfs.so unwrap
    # end of pam-auth-update config

`auth` tells us this module can verify a user is who they claim to be. It can also grant privileges.  
`[success=1 default=ignore]` is an interesting one. It says that, if the module returns success, then we should jump 1 module down the "stack" of modules; and otherwise this module's return should be ignore when deciding the overall PAM state.  
pam_unix is a module for authenticating with the normal unix system; it uses system library calls. In our case, this uses `/etc/passwd` and `/etc/shadow`.  

This is the crux of `sudo`'s authentication! This is the module that asks you for your password, verifies you got the right password, checks your password hasn't expired and that your account isn't locked, etc. If we want to swap password authentication for something else, this would be the line to alter!  
`nullok_secure` seems to be implementation specific. `nullok` just tells pam_unix to not throw a paddy if the user has a null password; I imagine the `_secure` is some way of preventing escapes, specific to the fork of PAM you are using.  

`requisite pam_deny.so` is called if pam_unix returns a failure case.  
`requisite` is very similar to required; but immediately returns to the caller/upper stack. `pam_deny` is a module that only replies with a negative value.  
In the overall scheme of things, this means if pam_unix doesn't verify you, the PAM system immediately goes back to it's caller and, because of pam_deny, says "nope, not a good user, not who they say they are". For us, this means if you get your password wrong, `sudo` doesn't have to wait around for many other PAM modules to process before it denies you access.  

The next step in `/etc/pam.d/sudo` is to include `/etc/pam.d/common-account`. In reality, this is very similar to `common-auth`, but it specifically deals with the case that the user's account/password is expired or locked.  

The final step is `/etc/pam.d/common-session-noninteractive`, which, as you likely guessed, contains configuration with regards to non-interactive sessions.  
The key part of this configuration file is  
    
    session optional                        pam_umask.so

The comment above this in the file is quite explicit:
>  The pam_umask module will set the umask according to the system default in
>  /etc/login.defs and user settings, solving the problem of different
>  umask settings with different shells, display managers, remote sessions etc.
>  See "man pam_umask".

Similar to `sudo`'s specific configuration, this is around the environment of our session in which we run the command.  

Ok, so now we understand how `sudo` verifies that you are who you say you are: PAM!. But next...

## 2. How does sudo validate that you are allowed to escalate to root?  
This one is a little bit easier. `sudo`'s configuration file is `/etc/sudoers`; there is also `/etc/sudoers.d` that allows you to write custom configuration without overwriting the default file.  
In sudoers, there is the following line:
    
    %sudo   ALL=(ALL:ALL) ALL

This says that anyone under the group *sudo* can execute any command as any user and any group.  
This is the essence of how validation works. From the result of `pam_unix`, or other sources, `sudo` can tell what group(s) your user is in; if you're in a group it knows about, it can validate what you can do, otherwise it denies you. You can restrict certain groups and users to escalating certain commands as certain groups and users.  
If you want to learn about these access controls, run `man sudoers`, and see [DigitalOcean's Guide](https://www.digitalocean.com/community/tutorials/how-to-edit-the-sudoers-file).

## 3. Once validated, how does sudo invoke commands as root?
Ok, we know the user is who they are claiming to be, and we know they are part of the *sudo* group; therefore, we are allowed to escalate them to root.  
How do we do this?  
Well, first we need to look at the binary.
    
    $ ls -l /usr/bin/sudo
    -rwsr-xr-x 1 root root 166056 Jan 19 15:21 /usr/bin/sudo

If you look at the permission bits, you'll see the user execute bit is set as "Set UID". This means that whenever this binary runs, it runs with the effective user id as the *owner* of the file. Therefore whenever `sudo` is invoked, it will run as root.  

Once it's running, verifies your permissions, and authenticates you with PAM, **sudo can spawn a child process as whatever user it likes**, changing the effective UID for the child process. While authenticating with PAM, the environment for this process is set up by various PAM modules. (According to [https://unix.stackexchange.com/a/126919](https://unix.stackexchange.com/a/126919), the verification of permissions happens before authentication; I am unsure what mechanism is used to do so.)  

## Summary.
When we run `sudo mysql`, the following happens:  

1. `sudo` runs, with the process' Effective UserID set as *root*.  
2. `sudo` validates the command you want to run against `/etc/sudoers` and `/etc/sudoers.d`.  
3. If you are allowed to run that command, `sudo` invokes PAM to authenticate you; `pam_unix` checks your password against the system database.  
4. If PAM authenticates you, `sudo` spawns a child process from itself, setting the effective UID as appropriate.  
5. Within this process, `mysql` uses `auth_socket` to determine the user, finds that it's *root@localhost*, and connects to the database.  

In the next installment, we will take a look at some PAM modules and how they can be used in the context of `sudo`.