require "spec_helper.rb"
require 'net/ftp'

describe FakeFtp::Server do

  before :each do
    @text_filename = File.expand_path("../../fixtures/text_file.txt", File.dirname(__FILE__))
    @bin_filename = File.expand_path("../../fixtures/invisible_bike.jpg", File.dirname(__FILE__))
  end

  context 'setup' do
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

  context 'socket' do
    before :each do
      @server = FakeFtp::Server.new(21212, 21213)
      @server.start
    end

    after :each do
      @server.stop
      @server = nil
    end

    context 'FTP commands' do
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
          @client = TCPSocket.open('127.0.0.1', 21212)
          @client.gets
          @client.puts "PASV"
          @client.gets.should == "227 Entering Passive Mode (127,0,0,1,82,221)\r\n"
        end

        it "responds with correct PASV port" do
          @server.stop
          @server.passive_port = 21111
          @server.start
          @client = TCPSocket.open('127.0.0.1', 21212)
          @client.gets
          @client.puts "PASV"
          @client.gets.should == "227 Entering Passive Mode (127,0,0,1,82,119)\r\n"
        end

        it "does not accept PASV if no port set" do
          @server.stop
          @server.passive_port = nil
          @server.start
          @client = TCPSocket.open('127.0.0.1', 21212)
          @client.gets
          @client.puts "PASV"
          @client.gets.should == "502 Aww hell no, use Active\r\n"
        end

        it "does not accept PORT (yet)" do
          ## TODO this test can go away once the following pending test succeeds
          @client = TCPSocket.open('127.0.0.1', 21212)
          @client.gets
          @client.puts "PORT 127,0,0,1,82,224"
          @client.gets.should == "500 Not implemented yet\r\n"
        end

        xit "accepts PORT and connects to port" do
          # @testing = true
          # @data_server = ::TCPServer.new('127.0.0.1', 21216)
          # @data_connection = Thread.new do
          #   while @testing
          #     @server_client = @data_connection.accept
          #     @server_connection = Thread.new(@server_client) do |socket|
          #       @connected = true
          #     end
          #   end
          # end
          # @client.gets
          # @client.puts "PORT 127,0,0,1,82,224"
          # @client.gets.should == "200 Okay\r\n"
          # @connected.should be_true
          # @testing = false
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

        it "accepts STOR with filename" do
          @client.puts "STOR some_file"
          @client.gets.should == "125 Do it!\r\n"
          @data_client = TCPSocket.open('127.0.0.1', 21213)
          @data_client.puts "1234567890"
          @data_client.close
          @client.gets.should == "226 Did it!\r\n"
          @server.files.should include('some_file')
        end
      end
    end

    context 'ftp client' do
      before :each do
        @ftp = Net::FTP.new
      end
      it 'should accept ftp connections' do
        proc { @ftp.connect('127.0.0.1', 21212) }.should_not raise_error
        proc { @ftp.close }.should_not raise_error
      end

      it "should allow anonymous authentication" do
        @ftp.connect('127.0.0.1', 21212)
        proc { @ftp.login }.should_not raise_error
        @ftp.close
      end

      it "should allow named authentication" do
        @ftp.connect('127.0.0.1', 21212)
        proc { @ftp.login('someone', 'password') }.should_not raise_error
        @ftp.close
      end

      it "should allow client to quit" do
        @ftp.connect('127.0.0.1', 21212)
        proc { @ftp.login('someone', 'password') }.should_not raise_error
        proc { @ftp.quit }.should_not raise_error
        @ftp.close
      end

      it "should put files using PASV" do
        @ftp.connect('127.0.0.1', 21212)
        @ftp.passive = true
        proc { @ftp.put(@text_filename) }.should_not raise_error
        @server.files.should include('text_file.txt')
      end

      xit "should disconnect clients on close" do
        # TODO: when this succeeds, we can care less about manually closing clients
        #       otherwise we get a CLOSE_WAIT process hanging around that blocks our port
        @ftp.connect('127.0.0.1', 21212)
        @server.stop
        @ftp.closed?.should be_true
      end
    end
  end
end