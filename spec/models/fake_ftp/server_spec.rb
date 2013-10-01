require "spec_helper.rb"

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

