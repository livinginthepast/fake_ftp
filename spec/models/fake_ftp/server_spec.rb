describe FakeFtp::Server, 'setup' do
  it 'starts a server on port n' do
    server = FakeFtp::Server.new(21_212)
    expect(server.port).to eql(21_212)
  end

  it 'should defaults to port 21' do
    server = FakeFtp::Server.new
    expect(server.port).to eql(21)
  end

  it 'starts a passive server on port p' do
    server = FakeFtp::Server.new(21_212, 21_213)
    expect(server.passive_port).to eql(21_213)
  end

  it 'should start and stop' do
    server = FakeFtp::Server.new(21_212)
    expect(server.is_running?).to be false
    server.start
    expect(server.is_running?).to be true
    server.stop
    expect(server.is_running?).to be false
  end

  it 'should default :mode to :active' do
    server = FakeFtp::Server.new(21_212, 21_213)
    expect(server.mode).to eql(:active)
  end

  it 'should start and stop passive port' do
    server = FakeFtp::Server.new(21_212, 21_213)
    expect(server.is_running?(21_213)).to be false
    server.start
    expect(server.is_running?(21_213)).to be true
    server.stop
    expect(server.is_running?(21_213)).to be false
  end

  it 'should raise if attempting to use a bound port' do
    server = FakeFtp::Server.new(21_212)
    server.start
    expect { FakeFtp::Server.new(21_212) }.to raise_error(Errno::EADDRINUSE, 'Address already in use - 21212')
    server.stop
  end

  it 'should raise if attempting to use a bound passive_port' do
    server = FakeFtp::Server.new(21_212, 21_213)
    server.start
    expect { FakeFtp::Server.new(21_214, 21_213) }.to raise_error(Errno::EADDRINUSE, 'Address already in use - 21213')
    server.stop
  end
end

describe FakeFtp::Server, 'files' do
  let(:file) { FakeFtp::File.new('filename', 34) }
  let(:server) { FakeFtp::Server.new(21_212) }

  before { server.instance_variable_set(:@files, [file]) }

  it 'returns filenames from :files' do
    expect(server.files).to include('filename')
  end

  it 'can be accessed with :file' do
    expect(server.file('filename')).to eql(file)
  end

  it 'can reset files' do
    server.reset
    expect(server.files).to eql([])
  end
end
