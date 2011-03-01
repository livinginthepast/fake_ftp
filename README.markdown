FakeFtp
=======

This is a gem that allows you to test FTP implementations in ruby. It is a minimal single-client FTP server
that can be bound to any arbitrary port on localhost.

Why?
----

We want to ensure that our code works, in a way that is agnostic to the implementation used (unlike with stubs or mocks).

How
---

FakeFtp is a simple FTP server that fakes out enough of the protocol to get us by, allowing us to test that files get to
their intended destination rather than testing how our code does so.

Note: Only passive FTP is currently implemented

Usage
-----

    require 'fake_ftp'
    require 'net/ftp'

    server = FakeFtp::Server.new(21212, 21213)
    ## 21212 is the control port, which is used by FTP for the primary connection
    ## 21213 is the data port, used in FTP passive mode to send file contents
    server.start

    ftp = Net::FTP.new
    ftp.connect('127.0.0.1', 21212)
    ftp.login('user', 'password')
    ftp.passive = true
    ftp.put('some_file.txt')
    ftp.close

    server.stop

TODO
----

* Active file upload
* Matchers