require "spec_helper.rb"
require 'net/ftp'

describe FakeFtp::Server, 'setup' do
  it "starts a server on port n" do
    server = FakeFtp::Server.new(21212)
    expect(server.port).to eql(21212)
  end

  it "should defaults to port 21" do
    server = FakeFtp::Server.new
    expect(server.port).to eql(21)
  end

  it "starts a passive server on port p" do
    server = FakeFtp::Server.new(21212, 21213)
    expect(server.passive_port).to eql(21213)
  end

  it "should start and stop" do
    server = FakeFtp::Server.new(21212)
    expect(server.is_running?).to be_false
    server.start
    expect(server.is_running?).to be_true
    server.stop
    expect(server.is_running?).to be_false
  end

  it "should default :mode to :active" do
    server = FakeFtp::Server.new(21212, 21213)
    expect(server.mode).to eql(:active)
  end

  it "should start and stop passive port" do
    server = FakeFtp::Server.new(21212, 21213)
    expect(server.is_running?(21213)).to be_false
    server.start
    expect(server.is_running?(21213)).to be_true
    server.stop
    expect(server.is_running?(21213)).to be_false
  end

  it "should raise if attempting to use a bound port" do
    server = FakeFtp::Server.new(21212)
    server.start
    expect { FakeFtp::Server.new(21212) }.to raise_error(Errno::EADDRINUSE, "Address already in use - 21212")
    server.stop
  end

  it "should raise if attempting to use a bound passive_port" do
    server = FakeFtp::Server.new(21212, 21213)
    server.start
    expect { FakeFtp::Server.new(21214, 21213) }.to raise_error(Errno::EADDRINUSE, "Address already in use - 21213")
    server.stop
  end
end

describe FakeFtp::Server, 'files' do
  let(:file) { FakeFtp::File.new('filename', 34) }
  let(:server) { FakeFtp::Server.new(21212) }

  before { server.instance_variable_set(:@files, [file]) }

  it "returns filenames from :files" do
    expect(server.files).to include('filename')
  end

  it "can be accessed with :file" do
    expect(server.file('filename')).to eql(file)
  end

  it "can reset files" do
    server.reset
    expect(server.files).to eql([])
  end
end

describe FakeFtp::Server, 'commands' do
  let(:server) { FakeFtp::Server.new(21212, 21213) }
  let(:client) { TCPSocket.open('127.0.0.1', 21212) }

  before { server.start }
  after {
    client.close
    server.stop
  }

  context 'general' do

    it "should accept connections" do
      expect(client.gets).to eql("220 Can has FTP?\r\n")
    end

    it "should get unknown command response when nothing is sent" do
      client.gets
      client.puts
      expect(client.gets).to eql("500 Unknown command\r\n")
    end

    it "accepts QUIT" do
      client.gets
      client.puts "QUIT"
      expect(client.gets).to eql("221 OMG bye!\r\n")
    end

    it "should accept multiple commands in one session" do
      client.gets
      client.puts "USER thing"
      client.gets
      client.puts "PASS thing"
      client.gets
      client.puts "ACCT thing"
      client.gets
      client.puts "USER thing"
    end
  end

  context 'passive' do

    it "accepts PASV" do
      expect(server.mode).to eql(:active)
      client.gets
      client.puts "PASV"
      expect(client.gets).to eql("227 Entering Passive Mode (127,0,0,1,82,221)\r\n")
      expect(server.mode).to eql(:passive)
    end

    it "responds with correct PASV port" do
      server.stop
      server.passive_port = 21111
      server.start
      client.gets
      client.puts "PASV"
      expect(client.gets).to eql("227 Entering Passive Mode (127,0,0,1,82,119)\r\n")
    end

    it "does not accept PASV if no port set" do
      server.stop
      server.passive_port = nil
      server.start
      client.gets
      client.puts "PASV"
      expect(client.gets).to eql("502 Aww hell no, use Active\r\n")
    end
  end

  context 'active' do
    before :each do
      client.gets

      @data_server = ::TCPServer.new('127.0.0.1', 21216)
      @data_connection = Thread.new do
        @server_client = @data_server.accept
        expect(@server_client).to_not be_nil
      end
    end

    after :each do
      @data_server.close
      @data_server = nil
      @data_connection = nil
    end

    it "accepts PORT and connects to port" do
      client.puts "PORT 127,0,0,1,82,224"
      expect(client.gets).to eql("200 Okay\r\n")

      @data_connection.join
    end

    it "should switch to :active on port command" do
      expect(server.mode).to eql(:active)
      client.puts 'PASV'
      client.gets
      expect(server.mode).to eql(:passive)

      client.puts "PORT 127,0,0,1,82,224"
      expect(client.gets).to eql("200 Okay\r\n")

      @data_connection.join

      expect(server.mode).to eql(:active)
    end
  end

  context 'authentication commands' do
    before :each do
      client.gets ## connection successful response
    end

    it "accepts USER" do
      client.puts "USER some_dude"
      expect(client.gets).to eql("331 send your password\r\n")
    end

    it "accepts anonymous USER" do
      client.puts "USER anonymous"
      expect(client.gets).to eql("230 logged in\r\n")
    end

    it "accepts PASS" do
      client.puts "PASS password"
      expect(client.gets).to eql("230 logged in\r\n")
    end

    it "accepts ACCT" do
      client.puts "ACCT"
      expect(client.gets).to eql("230 WHATEVER!\r\n")
    end
  end

  context 'directory commands' do
    before :each do
      client.gets ## connection successful response
    end

    it "returns directory on PWD" do
      client.puts "PWD"
      expect(client.gets).to eql("257 \"/pub\" is current directory\r\n")
    end

    it "says OK to any CWD, CDUP, without doing anything" do
      client.puts "CWD somewhere/else"
      expect(client.gets).to eql("250 OK!\r\n")
      client.puts "CDUP"
      expect(client.gets).to eql("250 OK!\r\n")
    end
  end

  context 'file commands' do
    before :each do
      client.gets ## connection successful response
    end

    it "accepts TYPE ascii" do
      client.puts "TYPE A"
      expect(client.gets).to eql("200 Type set to A.\r\n")
    end

    it "accepts TYPE image" do
      client.puts "TYPE I"
      expect(client.gets).to eql("200 Type set to I.\r\n")
    end

    it "does not accept TYPEs other than ascii or image" do
      client.puts "TYPE E"
      expect(client.gets).to eql("504 We don't allow those\r\n")
      client.puts "TYPE N"
      expect(client.gets).to eql("504 We don't allow those\r\n")
      client.puts "TYPE T"
      expect(client.gets).to eql("504 We don't allow those\r\n")
      client.puts "TYPE C"
      expect(client.gets).to eql("504 We don't allow those\r\n")
      client.puts "TYPE L"
      expect(client.gets).to eql("504 We don't allow those\r\n")
    end

    context 'passive' do
      let(:data_client) { TCPSocket.open('127.0.0.1', 21213) }

      before :each do
        client.puts 'PASV'
        expect(client.gets).to eql("227 Entering Passive Mode (127,0,0,1,82,221)\r\n")
      end

      it "accepts STOR with filename" do
        client.puts "STOR some_file"
        expect(client.gets).to eql("125 Do it!\r\n")
        data_client.puts "1234567890"
        data_client.close
        expect(client.gets).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
        expect(server.file('some_file').bytes).to eql(10)
        expect(server.file('some_file').data).to eql("1234567890")
      end

      it "accepts STOR with filename and trailing newline" do
        client.puts "STOR some_file"
        client.gets
        # puts tries to be smart and only write a single \n
        data_client.puts "1234567890\n\n"
        data_client.close
        expect(client.gets).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
        expect(server.file('some_file').bytes).to eql(11)
        expect(server.file('some_file').data).to eql("1234567890\n")
      end

      it "accepts STOR with filename and long file" do
        client.puts "STOR some_file"
        expect(client.gets).to eql("125 Do it!\r\n")
        data_client.puts("1234567890" * 10_000)
        data_client.close
        expect(client.gets).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
      end

      it "accepts STOR with streams" do
        client.puts "STOR some_file"
        expect(client.gets).to eql("125 Do it!\r\n")
        data_client.write "1234567890"
        data_client.flush
        data_client.write "1234567890"
        data_client.flush
        data_client.close
        expect(client.gets).to eql("226 Did it!\r\n")
        expect(server.file('some_file').data).to eql("12345678901234567890")
      end

      it "does not accept RETR without a filename" do
        client.puts "RETR"
        expect(client.gets).to eql("501 No filename given\r\n")
      end

      it "does not serve files that do not exist" do
        client.puts "RETR some_file"
        expect(client.gets).to eql("550 File not found\r\n")
      end

      it "accepts RETR with a filename" do
        server.add_file('some_file', '1234567890')
        client.puts "RETR some_file"
        expect(client.gets).to eql("150 File status ok, about to open data connection\r\n")
        data = data_client.read(1024)
        data_client.close
        expect(data).to eql('1234567890')
        expect(client.gets).to eql("226 File transferred\r\n")
      end

      it "accepts DELE with a filename" do
        server.add_file('some_file', '1234567890')
        client.puts "DELE some_file"
        expect(client.gets).to eql("250 Delete operation successful.\r\n")
        expect(server.files).to_not include('some_file')
      end

      it "gives error message when trying to delete a file that does not exist" do
        client.puts "DELE non_existing_file"
        expect(client.gets).to eql("550 Delete operation failed.\r\n")
      end

      it "accepts a LIST command" do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts "LIST"
        expect(client.gets).to eql("150 Listing status ok, about to open data connection\r\n")
        data = data_client.read(2048)
        data_client.close
        expect(data).to eql([
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('some_file').created.strftime('%b %d %H:%M')}\tsome_file",
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('another_file').created.strftime('%b %d %H:%M')}\tanother_file",
        ].join("\n"))
        expect(client.gets).to eql("226 List information transferred\r\n")
      end

      it "accepts a LIST command with a wildcard argument" do
        files = ['test.jpg', 'test-2.jpg', 'test.txt']
        files.each do |file|
          server.add_file(file, '1234567890')
        end

        client.puts "LIST *.jpg"
        expect(client.gets).to eql("150 Listing status ok, about to open data connection\r\n")

        data = data_client.read(2048)
        data_client.close
        expect(data).to eql(files[0,2].map do |file|
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file(file).created.strftime('%b %d %H:%M')}\t#{file}"
        end.join("\n"))
        expect(client.gets).to eql("226 List information transferred\r\n")
      end

      it "accepts a LIST command with multiple wildcard arguments" do
        files = ['test.jpg', 'test.gif', 'test.txt']
        files.each do |file|
          server.add_file(file, '1234567890')
        end

        client.puts "LIST *.jpg *.gif"
        expect(client.gets).to eql("150 Listing status ok, about to open data connection\r\n")

        data = data_client.read(2048)
        data_client.close
        expect(data).to eql(files[0,2].map do |file|
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file(file).created.strftime('%b %d %H:%M')}\t#{file}"
        end.join("\n"))
        expect(client.gets).to eql("226 List information transferred\r\n")
      end

      it "accepts an NLST command" do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts "NLST"
        expect(client.gets).to eql("150 Listing status ok, about to open data connection\r\n")
        data = data_client.read(1024)
        data_client.close
        expect(data).to eql("some_file\nanother_file")
        expect(client.gets).to eql("226 List information transferred\r\n")
      end

      it "should allow mdtm" do
        filename = "file.txt"
        now = Time.now
        server.add_file(filename, "some dummy content", now)
        client.puts "MDTM #{filename}"
        expect(client.gets).to eql("213 #{now.strftime("%Y%m%d%H%M%S")}\r\n")
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

      it 'creates a directory on MKD' do
        client.puts "MKD some_dir"
        expect(client.gets).to eql("257 OK!\r\n")
      end

      it 'should save the directory after you CWD' do
        client.puts "CWD /somewhere/else"
        expect(client.gets).to eql("250 OK!\r\n")
        client.puts "PWD"
        expect(client.gets).to eql("257 \"/somewhere/else\" is current directory\r\n")
      end

      it 'CWD should add a / to the beginning of the directory' do
        client.puts "CWD somewhere/else"
        expect(client.gets).to eql("250 OK!\r\n")
        client.puts "PWD"
        expect(client.gets).to eql("257 \"/somewhere/else\" is current directory\r\n")
      end

      it 'should not change the directory on CDUP' do
        client.puts "CDUP"
        expect(client.gets).to eql("250 OK!\r\n")
        client.puts "PWD"
        expect(client.gets).to eql("257 \"/pub\" is current directory\r\n")
      end

      it "sends error message if no PORT received" do
        client.puts "STOR some_file"
        expect(client.gets).to eql("425 Ain't no data port!\r\n")
      end

      it "accepts STOR with filename" do
        client.puts "PORT 127,0,0,1,82,224"
        expect(client.gets).to eql("200 Okay\r\n")

        client.puts "STOR some_other_file"
        expect(client.gets).to eql("125 Do it!\r\n")

        @data_connection.join
        @server_client.print "12345"
        @server_client.close

        expect(client.gets).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_other_file')
        expect(server.file('some_other_file').bytes).to eql(5)
      end

      it "accepts RETR with a filename" do
        client.puts "PORT 127,0,0,1,82,224"
        expect(client.gets).to eql("200 Okay\r\n")

        server.add_file('some_file', '1234567890')
        client.puts "RETR some_file"
        expect(client.gets).to eql("150 File status ok, about to open data connection\r\n")

        @data_connection.join
        data = @server_client.read(1024)
        @server_client.close

        expect(data).to eql('1234567890')
        expect(client.gets).to eql("226 File transferred\r\n")
      end

      it "accepts RNFR without filename" do
        client.puts "RNFR"
        expect(client.gets).to eql("501 Send path name.\r\n")
      end

      it "accepts RNTO without RNFR" do
        client.puts "RNTO some_other_file"
        expect(client.gets).to eql("503 Send RNFR first.\r\n")
      end

      it "accepts RNTO and RNFR without filename" do
        client.puts "RNFR from_file"
        expect(client.gets).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts "RNTO"
        expect(client.gets).to eql("501 Send path name.\r\n")
      end

      it "accepts RNTO and RNFR for not existing file" do
        client.puts "RNFR from_file"
        expect(client.gets).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts "RNTO to_file"
        expect(client.gets).to eql("550 File not found.\r\n")
      end

      it "accepts RNTO and RNFR" do
        server.add_file('from_file', '1234567890')

        client.puts "RNFR from_file"
        expect(client.gets).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts "RNTO to_file"
        expect(client.gets).to eql("250 Path renamed.\r\n")

        expect(server.files).to include('to_file')
        expect(server.files).to_not include('from_file')
      end

      it "accepts an NLST command" do
        client.puts "PORT 127,0,0,1,82,224"
        expect(client.gets).to eql("200 Okay\r\n")

        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts "NLST"
        expect(client.gets).to eql("150 Listing status ok, about to open data connection\r\n")

        @data_connection.join
        data = @server_client.read(1024)
        @server_client.close

        expect(data).to eql("some_file\nanother_file")
        expect(client.gets).to eql("226 List information transferred\r\n")
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
    expect { client.connect('127.0.0.1', 21212) }.to_not raise_error
  end

  context "" do
    before { client.connect("127.0.0.1", 21212) }

    it "should allow anonymous authentication" do
      expect { client.login }.to_not raise_error
    end

    it "should allow named authentication" do
      expect { client.login('someone', 'password') }.to_not raise_error
    end

    it "should allow client to quit" do
      expect { client.login('someone', 'password') }.to_not raise_error
      expect { client.quit }.to_not raise_error
    end

    it "should allow mtime" do
      filename = 'someone'
      time = Time.now
      server.add_file(filename, "some data", time)

      client.passive = false
      mtime = client.mtime(filename)
      expect(mtime.to_s).to eql(time.to_s)

      client.passive = true
      mtime = client.mtime(filename)
      expect(mtime.to_s).to eql(time.to_s)
    end

    it "should put files using PASV" do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = true
      expect { client.put(text_filename) }.to_not raise_error

      expect(server.files).to include('text_file.txt')
      expect(server.file('text_file.txt').bytes).to eql(20)
      expect(server.file('text_file.txt')).to be_passive
      expect(server.file('text_file.txt')).to_not be_active
    end

    it "should put files using active" do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = false
      expect { client.put(text_filename) }.to_not raise_error

      expect(server.files).to include('text_file.txt')
      expect(server.file('text_file.txt').bytes).to eql(20)
      expect(server.file('text_file.txt')).to_not be_passive
      expect(server.file('text_file.txt')).to be_active
    end

    xit "should disconnect clients on close" do
      # TODO: when this succeeds, we can care less about manually closing clients
      #       otherwise we get a CLOSE_WAIT process hanging around that blocks our port
      server.stop
      expect(client.closed?).to be_true
    end
  end
end
