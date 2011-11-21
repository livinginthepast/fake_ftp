require "spec_helper.rb"
require 'net/ftp'

describe FakeFtp::Server, 'setup' do
  it "starts a server on port n" do
    server = FakeFtp::Server.new(21212)
    server.port.should == 21212
  end

  it "should defaults to port 21" do
    server = FakeFtp::Server.new
    server.port.should == 21
  end

  it "starts a passive server on port p" do
    server = FakeFtp::Server.new(21212, 21213)
    server.passive_port.should == 21213
  end

  it "should start and stop" do
    server = FakeFtp::Server.new(21212)
    server.is_running?.should be_false
    server.start
    server.is_running?.should be_true
    server.stop
    server.is_running?.should be_false
  end

  it "should default :mode to :active" do
    server = FakeFtp::Server.new(21212, 21213)
    server.mode.should == :active
  end

  it "should start and stop passive port" do
    server = FakeFtp::Server.new(21212, 21213)
    server.is_running?(21213).should be_false
    server.start
    server.is_running?(21213).should be_true
    server.stop
    server.is_running?(21213).should be_false
  end

  it "should raise if attempting to use a bound port" do
    server = FakeFtp::Server.new(21212)
    server.start
    proc { FakeFtp::Server.new(21212) }.should raise_error(Errno::EADDRINUSE, "Address already in use - 21212")
    server.stop
  end

  it "should raise if attempting to use a bound passive_port" do
    server = FakeFtp::Server.new(21212, 21213)
    server.start
    proc { FakeFtp::Server.new(21214, 21213) }.should raise_error(Errno::EADDRINUSE, "Address already in use - 21213")
    server.stop
  end
end

describe FakeFtp::Server, 'files' do
  let(:file) { FakeFtp::File.new('filename', 34) }
  let(:server) { FakeFtp::Server.new(21212) }

  before { server.instance_variable_set(:@files, [file]) }

  it "returns filenames from :files" do
    server.files.should include('filename')
  end

  it "can be accessed with :file" do
    server.file('filename').should == file
  end

  it "can reset files" do
    server.reset
    server.files.should == []
  end
end

describe FakeFtp::Server, 'commands' do
  let(:server) { FakeFtp::Server.new(21212, 21213) }

  before { server.start }
  after { server.stop }

  context 'general' do
    before :each do
      @client = TCPSocket.open('127.0.0.1', 21212)
    end

    after :each do
      @client.close
    end

    it "should accept connections" do
      @client.gets.should == "200 Can has FTP?\r\n"
    end

    it "should get unknown command response when nothing is sent" do
      @client.gets
      @client.puts
      @client.gets.should == "500 Unknown command\r\n"
    end

    it "accepts QUIT" do
      @client.gets
      @client.puts "QUIT"
      @client.gets.should == "221 OMG bye!\r\n"
    end

    it "should accept multiple commands in one session" do
      @client.gets
      @client.puts "USER thing"
      @client.gets
      @client.puts "PASS thing"
      @client.gets
      @client.puts "ACCT thing"
      @client.gets
      @client.puts "USER thing"
    end
  end

  context 'passive' do
    after :each do
      @client.close
    end

    it "accepts PASV" do
      server.mode.should == :active
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets
      @client.puts "PASV"
      @client.gets.should == "227 Entering Passive Mode (127,0,0,1,82,221)\r\n"
      server.mode.should == :passive
    end

    it "responds with correct PASV port" do
      server.stop
      server.passive_port = 21111
      server.start
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets
      @client.puts "PASV"
      @client.gets.should == "227 Entering Passive Mode (127,0,0,1,82,119)\r\n"
    end

    it "does not accept PASV if no port set" do
      server.stop
      server.passive_port = nil
      server.start
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets
      @client.puts "PASV"
      @client.gets.should == "502 Aww hell no, use Active\r\n"
    end
  end

  context 'active' do
    before :each do
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets

      @data_server = ::TCPServer.new('127.0.0.1', 21216)
      @data_connection = Thread.new do
        @server_client = @data_server.accept
        @server_client.should_not be_nil
      end
    end

    after :each do
      @data_server.close
      @data_server = nil
      @data_connection = nil
      @client.close
    end

    it "accepts PORT and connects to port" do
      @client.puts "PORT 127,0,0,1,82,224"
      @client.gets.should == "200 Okay\r\n"

      @data_connection.join
    end

    it "should switch to :active on port command" do
      server.mode.should == :active
      @client.puts 'PASV'
      @client.gets
      server.mode.should == :passive

      @client.puts "PORT 127,0,0,1,82,224"
      @client.gets.should == "200 Okay\r\n"

      @data_connection.join

      server.mode.should == :active
    end
  end

  context 'authentication commands' do
    before :each do
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets ## connection successful response
    end

    after :each do
      @client.close
    end

    it "accepts USER" do
      @client.puts "USER some_dude"
      @client.gets.should == "331 send your password\r\n"
    end

    it "accepts anonymous USER" do
      @client.puts "USER anonymous"
      @client.gets.should == "230 logged in\r\n"
    end

    it "accepts PASS" do
      @client.puts "PASS password"
      @client.gets.should == "230 logged in\r\n"
    end

    it "accepts ACCT" do
      @client.puts "ACCT"
      @client.gets.should == "230 WHATEVER!\r\n"
    end
  end

  context 'directory commands' do
    before :each do
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets ## connection successful response
    end

    after :each do
      @client.close
    end

    it "returns directory on PWD" do
      @client.puts "PWD"
      @client.gets.should == "257 \"/pub\" is current directory\r\n"
    end

    it "says OK to any CWD, CDUP, without doing anything" do
      @client.puts "CWD somewhere/else"
      @client.gets.should == "250 OK!\r\n"
      @client.puts "CDUP"
      @client.gets.should == "250 OK!\r\n"
    end

    it "does not respond to MKD" do
      @client.puts "MKD some_dir"
      @client.gets.should == "500 Unknown command\r\n"
    end
  end

  context 'file commands' do
    before :each do
      @client = TCPSocket.open('127.0.0.1', 21212)
      @client.gets ## connection successful response
    end

    after :each do
      @client.close
    end

    it "accepts TYPE ascii" do
      @client.puts "TYPE A"
      @client.gets.should == "200 Type set to A.\r\n"
    end

    it "accepts TYPE image" do
      @client.puts "TYPE I"
      @client.gets.should == "200 Type set to I.\r\n"
    end

    it "does not accept TYPEs other than ascii or image" do
      @client.puts "TYPE E"
      @client.gets.should == "504 We don't allow those\r\n"
      @client.puts "TYPE N"
      @client.gets.should == "504 We don't allow those\r\n"
      @client.puts "TYPE T"
      @client.gets.should == "504 We don't allow those\r\n"
      @client.puts "TYPE C"
      @client.gets.should == "504 We don't allow those\r\n"
      @client.puts "TYPE L"
      @client.gets.should == "504 We don't allow those\r\n"
    end

    context 'passive' do
      before :each do
        @client.puts 'PASV'
        @client.gets.should == "227 Entering Passive Mode (127,0,0,1,82,221)\r\n"
      end

      it "accepts STOR with filename" do
        @client.puts "STOR some_file"
        @client.gets.should == "125 Do it!\r\n"
        @data_client = TCPSocket.open('127.0.0.1', 21213)
        @data_client.puts "1234567890"
        @data_client.close
        @client.gets.should == "226 Did it!\r\n"
        server.files.should include('some_file')
        server.file('some_file').bytes.should == 10
      end

      it "does not accept RETR without a filename" do
        @client.puts "RETR"
        @client.gets.should == "501 No filename given\r\n"
      end

      it "does not serve files that do not exist" do
        @client.puts "RETR some_file"
        @client.gets.should == "550 File not found\r\n"
      end

      it "accepts RETR with a filename" do
        server.add_file('some_file', '1234567890')
        @client.puts "RETR some_file"
        @client.gets.should == "150 File status ok, about to open data connection\r\n"
        @data_client = TCPSocket.open('127.0.0.1', 21213)
        data = @data_client.read(1024)
        @data_client.close
        data.should == '1234567890'
        @client.gets.should == "226 File transferred\r\n"
      end

      it "accepts a LIST command" do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        @client.puts "LIST"
        @client.gets.should == "150 Listing status ok, about to open data connection\r\n"
        @data_client = TCPSocket.open('127.0.0.1', 21213)
        data = @data_client.read(2048)
        @data_client.close
        data.should == [
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('some_file').created.strftime('%b %d %H:%M')}\tsome_file",
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('another_file').created.strftime('%b %d %H:%M')}\tanother_file",
        ].join("\n")
        @client.gets.should == "226 List information transferred\r\n"
      end

      it "accepts an NLST command" do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        @client.puts "NLST"
        @client.gets.should == "150 Listing status ok, about to open data connection\r\n"
        @data_client = TCPSocket.open('127.0.0.1', 21213)
        data = @data_client.read(1024)
        @data_client.close
        data.should == "some_file\nanother_file"
        @client.gets.should == "226 List information transferred\r\n"
      end

    end

    context 'active' do
      before :each do
        @data_server = ::TCPServer.new('127.0.0.1', 21216)
        @data_connection = Thread.new do
          @server_client = @data_server.accept
        end
      end

      after :each do
        @data_server.close
        @data_connection = nil
        @data_server = nil
      end

      it "sends error message if no PORT received" do
        @client.puts "STOR some_file"
        @client.gets.should == "425 Ain't no data port!\r\n"
      end

      it "accepts STOR with filename" do
        @client.puts "PORT 127,0,0,1,82,224"
        @client.gets.should == "200 Okay\r\n"

        @client.puts "STOR some_other_file"
        @client.gets.should == "125 Do it!\r\n"

        @data_connection.join
        @server_client.print "12345"
        @server_client.close

        @client.gets.should == "226 Did it!\r\n"
        server.files.should include('some_other_file')
        server.file('some_other_file').bytes.should == 5
      end

      it "accepts RETR with a filename" do
        @client.puts "PORT 127,0,0,1,82,224"
        @client.gets.should == "200 Okay\r\n"

        server.add_file('some_file', '1234567890')
        @client.puts "RETR some_file"
        @client.gets.should == "150 File status ok, about to open data connection\r\n"

        @data_connection.join
        data = @server_client.read(1024)
        @server_client.close

        data.should == '1234567890'
        @client.gets.should == "226 File transferred\r\n"
      end

      it "accepts an NLST command" do
        @client.puts "PORT 127,0,0,1,82,224"
        @client.gets.should == "200 Okay\r\n"

        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        @client.puts "NLST"
        @client.gets.should == "150 Listing status ok, about to open data connection\r\n"

        @data_connection.join
        data = @server_client.read(1024)
        @server_client.close

        data.should == "some_file\nanother_file"
        @client.gets.should == "226 List information transferred\r\n"
      end
    end
  end
end

describe FakeFtp::Server, 'with ftp client' do
  let(:server) { FakeFtp::Server.new(21212, 21213) }
  let(:client) { Net::FTP.new }
  let(:text_filename) { File.expand_path("../../fixtures/text_file.txt", File.dirname(__FILE__)) }

  before { server.start }

  after :each do
    client.close
    server.stop
  end

  it 'should accept connections' do
    proc { client.connect('127.0.0.1', 21212) }.should_not raise_error
  end

  context "" do
    before { client.connect("127.0.0.1", 21212) }

    it "should allow anonymous authentication" do
      proc { client.login }.should_not raise_error
    end

    it "should allow named authentication" do
      proc { client.login('someone', 'password') }.should_not raise_error
    end

    it "should allow client to quit" do
      proc { client.login('someone', 'password') }.should_not raise_error
      proc { client.quit }.should_not raise_error
    end

    it "should put files using PASV" do
      File.stat(text_filename).size.should == 20

      client.passive = true
      proc { client.put(text_filename) }.should_not raise_error

      server.files.should include('text_file.txt')
      server.file('text_file.txt').bytes.should == 20
      server.file('text_file.txt').should be_passive
      server.file('text_file.txt').should_not be_active
    end

    it "should put files using active" do
      File.stat(text_filename).size.should == 20

      client.passive = false
      proc { client.put(text_filename) }.should_not raise_error

      server.files.should include('text_file.txt')
      server.file('text_file.txt').bytes.should == 20
      server.file('text_file.txt').should_not be_passive
      server.file('text_file.txt').should be_active
    end

    xit "should disconnect clients on close" do
      # TODO: when this succeeds, we can care less about manually closing clients
      #       otherwise we get a CLOSE_WAIT process hanging around that blocks our port
      server.stop
      client.closed?.should be_true
    end
  end
end
