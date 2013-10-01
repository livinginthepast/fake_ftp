require 'spec_helper'
require 'net/ftp'

describe FakeFtp::Server, 'with ftp client' do
  let(:server) { FakeFtp::Server.new(21212, 21213) }
  let(:client) { Net::FTP.new }
  let(:text_filename) { File.expand_path("../fixtures/text_file.txt", File.dirname(__FILE__)) }

  before { server.start }

  after :each do
    client.close
    server.stop
  end

  it 'should accept connections' do
    expect { client.connect('127.0.0.1', 21212) }.to_not raise_error
  end

  context "with client" do
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
