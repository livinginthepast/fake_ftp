FakeFtp
=======

[![Build status](https://secure.travis-ci.org/livinginthepast/fake_ftp.png)](http://travis-ci.org/livinginthepast/fake_ftp)

This is a gem that allows you to test FTP implementations in ruby. It is 
a minimal single-client FTP server that can be bound to any arbitrary 
port on localhost.


## Why?

We want to ensure that our code works, in a way that is agnostic to the 
implementation used (unlike with stubs or mocks).


## How

FakeFtp is a simple FTP server that fakes out enough of the protocol to 
get us by, allowing us to test that files get to their intended destination 
rather than testing how our code does so.


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

server.files.should include('some_file.txt')
server.file('some_file.txt').bytes.should == 25
server.file('some_file.txt').should be_passive
server.file('some_file.txt').should_not be_active

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

server.files.should include('some_file.txt')
server.file('some_file.txt').bytes.should == 25
server.file('some_file.txt').should be_active
server.file('some_file.txt').should_not be_passive

server.stop
```

Note that many FTP clients default to active, unless specified otherwise.


## Caveats

This is *not* a real FTP server and should not be treated as one. The goal 
of this gem is not to create a thread-safe multi-client implementation.
It is best used to unit test models that generate files and transfer
them to an FTP server.

As such, there are some things that won't be accepted upstream from pull
requests:
* simultaneous multi-client code
* support for long term file persistence
* binding to arbitrary IPs
* global state beyond that required to pass the minimum required to
  generate passing tests


## Recommendations for testing patterns

*Separate configuration from code.* Do not hard code the IP address,
FQDN or port of an FTP server in your classes. It introduces fragility
into your tests. Also, the default FTP port of 21 is a privileged port,
and should be avoided.

*Separate the code that generates files from the code that uploads
files.* You tests will run much more quickly if you only try to upload
small files. If you have tests showing that you generate correct files
from your data, then you can trust that. Why do you need to upload a 20M
file in your tests if you can stub out your file generation method and
test file upload against 10 bytes? Fast fast fast.


## References

* http://rubyforge.org/projects/ftpd/ - a simple ftp daemon written by Chris Wanstrath
* http://ruby-doc.org/stdlib/libdoc/gserver/rdoc/index.html - a generic server in the Ruby standard library, by John W Small

## License

The MIT License

Copyright (c) 2011 Eric Saxby

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
