smtpprox-loopprevent
====================

Transparent SMTP proxy to prevent mail forwarding loops

Description
-----------

*smtpprox-loopprevent* is a transparent SMTP proxy which compares
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

