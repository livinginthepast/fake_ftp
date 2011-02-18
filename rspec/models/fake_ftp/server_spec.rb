require "../../spec_helper.rb"
require 'net/ftp'

describe FakeFtp::Server do
  subject { FakeFtp::Server }

  before :all do
    @directory = File.expand_path(__FILE__, "../../fixtures/destination")
    @text_filename = File.expand_path(__FILE__, "../../fixtures/text_file.txt")
  end
  before :each do
    FileUtils.rm_rf(@directory+"/*")
  end

  it "starts a server on port n" do
    server = FakeFtp::Server.new(21212)
    server.port.should == 21212
    ftp = Net::FTP.new
    proc { ftp.connect('127.0.0.1', 21212) }.should_not raise_error
    proc { ftp.connect('127.0.0.1', 21212) }.should_not raise_error(Net::FTPReplyError)

    server.stop
  end

  it "should default to port 21" do
    server = FakeFtp::Server.new
    server.port.should == 21
  end

  it "should authenticate" do
    server = FakeFtp::Server.new(21212)
    ftp = Net::FTP.new

    proc { ftp.connect('127.0.0.1', 21212) }.should_not raise_error
    proc { ftp.login('user', 'password') }.should_not raise_error(Net::FTPReplyError)

    server.stop
  end
  
  it "can be configured with a directory store" do
    server = FakeFtp::Server.new(21212)
    server.directory = @directory
    server.directory.should == @directory
  end

  context 'file puts' do
    before :each do
      @server = FakeFtp::Server.new(21216)
    end

    after :each do
      @server.stop
    end

    it "should accept a file" do
      ftp = Net::FTP.new
      ftp.connect('127.0.0.1', 21216)
      proc { ftp.login('user', 'password') }.should_not raise_error
      proc { ftp.put(@text_filename)}.should_not raise_error
      Dir.glob(@directory).should include(@text_filename)
    end
  end
end