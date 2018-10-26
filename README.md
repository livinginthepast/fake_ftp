# FakeFtp

[![Build status](https://api.travis-ci.org/livinginthepast/fake_ftp.svg?branch=master)](http://travis-ci.org/livinginthepast/fake_ftp)
[![Code Climate](https://codeclimate.com/github/livinginthepast/fake_ftp/badges/gpa.svg)](https://codeclimate.com/github/livinginthepast/fake_ftp)
[![Test Coverage](https://codeclimate.com/github/livinginthepast/fake_ftp/badges/coverage.svg)](https://codeclimate.com/github/livinginthepast/fake_ftp/coverage)
[![Gem Version](https://badge.fury.io/rb/fake_ftp.svg)](https://badge.fury.io/rb/fake_ftp)

This is a gem that allows you to test FTP implementations in ruby. It is a
minimal single-client FTP server that can be bound to any arbitrary port on
localhost.

## Why?

We want to ensure that our code works, in a way that is agnostic to the
implementation used (unlike with stubs or mocks).

## How

FakeFtp is a simple FTP server that fakes out enough of the protocol to get us
by, allowing us to test that files get to their intended destination rather than
testing how our code does so.

## Usage

To test passive upload:
``` ruby
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

expect(server.files).to include('some_file.txt')
expect(server.file('some_file.txt').bytes).to eq 25
expect(server.file('some_file.txt')).to be_passive
expect(server.file('some_file.txt')).to_not be_active

server.stop
```

To test active upload:
``` ruby
server = FakeFtp::Server.new(21212)
## 21212 is the control port, which is used by FTP for the primary connection
## 21213 is the data port, used in FTP passive mode to send file contents
server.start

ftp = Net::FTP.new
ftp.connect('127.0.0.1', 21212)
ftp.login('user', 'password')
ftp.passive = false
ftp.put('some_file.txt')
ftp.close

expect(server.files).to include('some_file.txt')
expect(server.file('some_file.txt').bytes).to eq 25
expect(server.file('some_file.txt')).to be_active
expect(server.file('some_file.txt')).to_not be_passive

server.stop
```

Note that many FTP clients default to active, unless specified otherwise.

## Caveats

This is *not* a real FTP server and should not be treated as one. The goal of
this gem is not to create a thread-safe multi-client implementation.  It is best
used to unit test code that generates files and transfers them to an FTP server.

As such, there are some things that won't be accepted upstream from pull
requests:
* simultaneous multi-client code
* persistence support
* binding to arbitrary IPs
* global state beyond that required to pass the minimum required to
  generate passing tests

## Recommendations for testing patterns

*Separate configuration from code.* Do not hard code the IP address, FQDN or
port of an FTP server in your code. It introduces fragility into your tests.
Also, the default FTP port of 21 is a privileged port, and should be avoided.

*Separate the code that generates files from the code that uploads files.* You
tests will run much more quickly if you only try to upload small files. If you
have tests showing that you generate correct files from your data, then you can
trust that. Why do you need to upload a 20M file in your tests if you can stub
out your file generation method and test file upload against 10 bytes? Fast fast
fast.

## References

* http://rubyforge.org/projects/ftpd/ - a simple ftp daemon written by Chris Wanstrath
* http://ruby-doc.org/stdlib/libdoc/gserver/rdoc/index.html - a generic server in the Ruby standard library, by John W Small
