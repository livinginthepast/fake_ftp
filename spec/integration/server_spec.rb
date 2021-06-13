# frozen_string_literal: true

require 'net/ftp'

describe FakeFtp::Server, 'with ftp client', integration: true do
  let(:server) { FakeFtp::Server.new(21_212, 21_213, absolute: true) }
  let(:client) { Net::FTP.new(nil, debug_mode: ENV['DEBUG'] == '1') }
  let(:text_filename) do
    File.expand_path('../../fixtures/text_file.txt', __FILE__)
  end

  before { server.start }

  after :each do
    client.close
    server.stop
  end

  it 'should accept connections' do
    expect { client.connect('127.0.0.1', 21_212) }.to_not raise_error
  end

  context 'with client' do
    before { client.connect('127.0.0.1', 21_212) }

    it 'should allow anonymous authentication' do
      expect { client.login }.to_not raise_error
    end

    it 'should allow named authentication' do
      expect { client.login('someone', 'password') }.to_not raise_error
    end

    it 'should allow client to quit' do
      expect { client.login('someone', 'password') }.to_not raise_error
      expect { client.quit }.to_not raise_error
    end

    it 'should allow mtime' do
      filename = '/pub/someone'
      time = Time.now
      server.add_file(filename, 'some data', time)

      client.passive = false
      mtime = client.mtime(filename)
      expect(mtime.to_s).to eql(time.to_s)

      client.passive = true
      mtime = client.mtime(filename)
      expect(mtime.to_s).to eql(time.to_s)
    end

    it 'should put files using PASV' do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = true
      expect { client.put(text_filename) }.to_not raise_error

      expect(server.files).to include('/pub/text_file.txt')
      expect(server.file('/pub/text_file.txt').bytes).to eql(20)
      expect(server.file('/pub/text_file.txt')).to be_passive
      expect(server.file('/pub/text_file.txt')).to_not be_active
    end

    it 'should put different files in different directories' do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = true
      client.put(text_filename)

      client.chdir('/tmp')
      client.put(text_filename, 'other_file.txt')

      expect(server.files).to include('/pub/text_file.txt')
      expect(server.files).to include('/tmp/other_file.txt')
    end

    it 'should put files using active' do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = false
      expect { client.put(text_filename) }.to_not raise_error

      expect(server.files).to include('/pub/text_file.txt')
      expect(server.file('/pub/text_file.txt').bytes).to eql(20)
      expect(server.file('/pub/text_file.txt')).to_not be_passive
      expect(server.file('/pub/text_file.txt')).to be_active
    end

    it 'should allow client to execute SITE command' do
      expect { client.site('umask') }.to_not raise_error
    end

    it 'should be able to delete files added using put' do
      expect(File.stat(text_filename).size).to eql(20)

      client.passive = false
      expect { client.put(text_filename) }.to_not raise_error
      expect(server.files).to include('/pub/text_file.txt')
      expect { client.delete(text_filename) }.to_not raise_error
      expect(server.files).to_not include('/pub/text_file.txt')
    end
  end
end
