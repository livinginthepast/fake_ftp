require "spec_helper.rb"
require 'net/ftp'

describe FakeFtp::Server do

  before :each do
    @directory = File.expand_path("../fixtures/destination", File.dirname(__FILE__))
    @text_filename = File.expand_path("../../fixtures/text_file.txt", File.dirname(__FILE__))
    @bin_filename = File.expand_path("../../fixtures/invisible_bike.jpg", File.dirname(__FILE__))
  end

  after :each do
    FileUtils.rm_rf(@directory+"/*")
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

    it "should start and stop" do
      server = FakeFtp::Server.new(21212)
      server.is_running?.should be_false
      server.start
      server.is_running?.should be_true
      server.stop
      server.is_running?.should be_false
    end

    it "should raise if attempting to use a bound port" do
      server = FakeFtp::Server.new(21212)
      server.start
      proc { FakeFtp::Server.new(21212) }.should raise_error(Errno::EADDRINUSE, "Address already in use - 21212")
      server.stop
    end

    it "can be configured with a directory store" do
      server = FakeFtp::Server.new
      server.directory = @directory
      server.directory.should == @directory
    end

    it "should default directory to /tmp if Rails.root does not exist" do
      server = FakeFtp::Server.new
      server.directory.should == '/tmp'
    end

    it "should default directory to Rails.root/tmp/ftp if exists" do
      module Rails; end
      Rails.stub!(:root).and_return('/somewhere')
      server = FakeFtp::Server.new
      server.directory.should == '/somewhere/tmp/ftp'
    end

    it "should clean up directory after itself"

    it "should raise if attempting to delete a directory with contents other than its own"
  end

  context 'socket' do
    before :each do
      @server = FakeFtp::Server.new(21212)
      @server.start
    end

    after :each do
      @server.stop
      @server = nil
    end

    context 'FTP commands' do
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

      it "accepts PASV" do
        @client.gets
        @client.puts "PASV"
        @client.gets.should == "227 Entering Passive Mode (128,205,32,24,82,127)\r\n"
      end

      context 'authentication commands' do
        before :each do
          @client.gets ## connection successful response
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
          @client.gets ## connection successful response
        end
        it "returns directory on PWD" do
          @server.directory = @directory
          @client.puts "PWD"
          @client.gets.should == "257 \"#{@directory}\" is current directory\r\n"
        end

        it "returns default directory on PWD" do
          @server.directory = '/tmp'
          @client.puts "PWD"
          @client.gets.should == "257 \"/tmp\" is current directory\r\n"
        end

        it "says OK to any CWD, without doing anything" do
          directory = @server.directory
          @client.puts "CWD somewhere/else"
          @client.gets.should == "250 OK!\r\n"
          @server.directory.should == directory
        end

        it "does not respond to MKD" do
          @client.puts "MKD some_dir"
          @client.gets.should == "500 Unknown command\r\n"
        end
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

      it "should put files to directory store"

      xit "should disconnect clients on close" do
        # TODO: when this succeeds, we can care less about manually closing clients
        @ftp.connect('127.0.0.1', 21212)
        @server.stop
        @ftp.closed?.should be_true
      end
    end
  end
end