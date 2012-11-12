smtpprox-loopprevent Installation
=================================

`smtpprox-loopprevent` runs as a before-queue postfix content filter.
(See [SMTPD_PROXY_README](http://www.postfix.org/SMTPD_PROXY_README.html "SMTPD_PROXY_README").)

As the name indicates, `smtpprox-loopprevent` is a modified
[smtpprox](http://bent.latency.net/smtpprox/ "smtpprox").
A copy of `smtpprox` is included, you might read the documentation
and comments at the top.

* You need the **MSDW/SMTP/{Client,Server}.pm** files from `smtpprox`
in your perl library path.  You may already have them, eg. dkimproxy
provides them, but if not just copy to /usr/local/lib/site\_perl/ or
similar.

* You also need the **[MailTools](http://search.cpan.org/dist/MailTools/)** library.

* Select 2 TCP ports to use, one for `smtpprox-loopprevent` to listen on
(postfix delivers here for filtering), and one for postfix `smtpd`
to listen on (smtpprox-loopprevent forwards mail here).
Let's use **10025** and **10026**, just like the postfix example.

* Start `smtpprox-loopprevent` using those ports:

    smtpprox-loopprevent  127.0.0.1:10025  127.0.0.1:10026

* Configure `/etc/postfix/master.cf` - see the full page for details,
but you can probably cut/paste config right from
[the postfix config example](http://www.postfix.org/SMTPD_PROXY_README.html#config "postfix config example").

* Reload postfix, and now you're up and running.

* You'll need to create an init script or otherwise arrange for
`smtpprox-loopprevent` to start after a reboot.


Help
----

See https://github.com/jnorell/smtpprox-loopprevent for further info
related to `smtpprox-loopprevent`.

