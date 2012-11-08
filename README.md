smtpprox-loopprevent
====================

Transparent SMTP proxy to prevent mail forwarding loops


Description
-----------

`smtpprox-loopprevent` is a transparent SMTP proxy which compares
message recipient addresses against Delivered-To headers
and rejects the message if there is a match.  It was written
to be used as a Postfix before-queue filter.


Reason and Background
---------------------

Postfix already catches these same mail loops, so why bother?
In short because some recent spam has been filling our mail
queues with undeliverable bounce messages.

We use amavisd-new as an after-queue content\_filter.  So a one
smtpd takes the message at SMTP time and sticks it in queue.
It is then passed to amavisd-new, which scans and delivers the
message to a second (post-queue) smtpd for delivery.

If you're going to reject mail, you want that first smtpd to
reject it at SMTP time whenever possible.  If it makes it to
the second smtpd, it has to generate a bounce message, as SMTP
has completed.  And if you can't deliver the bounce message
it sits in your queue.  Build up thousands of those and you
start to have issues.  And the backscatter isn't nice.

So that's exactly what we've seen the last week or so,
thousands of undeliverable bounce messages filling our queues.
The diagnostic-code says "mail forwarding loop for user@domain".
Upon examination, this spam has a forged Delivered-To: header
added before we even receive it.

Mail destined to *user@domain*, with a "*Delivered-To: user@domain*"
header?  That's exactly what a mail loop looks like, and why
postfix rejects it.  All well and good - we just need to move
that rejection into SMTP, rather than generating bounces.

Postfix header\_checks don't seem to have the envelope information
available, so they won't work.  Postfix policy daemons have
envelope info, but not access to the message headers.  So a
before-queue content filter is the only place I see to get at both
and have SMTP rejection available.


What Harm Can It Do?
--------------------

*smtpprox-loopprevent* employs a simple policy that should work
for many sites, but do understand the implications of using it on
yours.  Again, it rejects a message if *any* of the recipient
addresses match a *Delivered-To* header.


Installation
------------

As the name indicates, `smtpprox-loopprevent` is a modified
[smtpprox](http://bent.latency.net/smtpprox/ "smtpprox").
A copy of `smtpprox` is included, you might read the documentation
and comments at the top.

You need the **MSDW/SMTP/{Client,Server}.pm** files from `smtpprox`
in your perl library path.  You may already have them, eg. dkimproxy
provides them, but if not just copy to /usr/local/lib/site\_perl/ or
similar.

You also need the **[MailTools](http://search.cpan.org/dist/MailTools/)** library.

Select 2 TCP ports to use, one for `smtpprox-loopprevent` to listen on
(postfix delivers here for filtering), and one for postfix `smtpd`
to listen on (smtpprox-loopprevent forwards mail here).
Let's use **10025** and **10026**, just like the example in 
[SMTPD_PROXY_README](http://www.postfix.org/SMTPD_PROXY_README.html "SMTPD_PROXY_README")

Start `smtpprox-loopprevent` using those ports:

  smtpprox-loopprevent  127.0.0.1:10025  127.0.0.1:10026

Configure `/etc/postfix/master.cf` - see the full page for details,
but you can probably cut/paste config right from
[the postfix config example](http://www.postfix.org/SMTPD_PROXY_README.html#config "postfix config example").

Reload postfix, and now you're up and running.  You'll need to
create an init script or otherwise arrange for `smtpprox-loopprevent`
to start up after reboot.

