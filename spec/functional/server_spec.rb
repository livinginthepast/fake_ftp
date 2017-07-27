describe FakeFtp::Server, 'commands', functional: true do
  let(:data_port) { rand(16_000..19_000) }
  let(:data_addr_bits) { SpecHelper.local_addr_bits(data_port) }
  let(:client_port) { rand(19_000..22_000) }
  let(:client_addr_bits) { SpecHelper.local_addr_bits(client_port) }
  let(:data_server_port) { rand(22_000..24_000) }
  let(:data_server_addr_bits) { SpecHelper.local_addr_bits(data_server_port) }
  let(:client) { TCPSocket.open('127.0.0.1', client_port) }
  let(:server) do
    FakeFtp::Server.new(client_port, data_port, debug: ENV['DEBUG'] == '1')
  end
  let(:data_server) { TCPServer.new('127.0.0.1', data_server_port) }

  before { server.start }

  after do
    client.close
    server.stop
  end

  context 'general' do
    it 'should accept connections' do
      expect(SpecHelper.gets_with_timeout(client)).to eql("220 Can has FTP?\r\n")
    end

    it 'should get unknown command response when nothing is sent' do
      SpecHelper.gets_with_timeout(client)
      client.puts
      expect(SpecHelper.gets_with_timeout(client)).to eql("500 Unknown command\r\n")
    end

    it 'accepts QUIT' do
      SpecHelper.gets_with_timeout(client)
      client.puts 'QUIT'
      expect(SpecHelper.gets_with_timeout(client)).to eql("221 OMG bye!\r\n")
    end

    it 'should accept multiple commands in one session' do
      SpecHelper.gets_with_timeout(client)
      client.puts 'USER thing'
      SpecHelper.gets_with_timeout(client)
      client.puts 'PASS thing'
      SpecHelper.gets_with_timeout(client)
      client.puts 'ACCT thing'
      SpecHelper.gets_with_timeout(client)
      client.puts 'USER thing'
    end

    it 'should accept SITE command' do
      SpecHelper.gets_with_timeout(client)
      client.puts 'SITE umask'
      expect(SpecHelper.gets_with_timeout(client)).to eql "200 umask\r\n"
    end
  end

  context 'passive' do
    it 'accepts PASV' do
      expect(server.mode).to eql(:active)
      SpecHelper.gets_with_timeout(client)
      client.puts 'PASV'
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("227 Entering Passive Mode (#{data_addr_bits})\r\n")
      expect(server.mode).to eql(:passive)
    end

    it 'responds with correct PASV port' do
      server.stop
      server.passive_port = 21_111
      server.start
      SpecHelper.gets_with_timeout(client)
      client.puts 'PASV'
      addr_bits = SpecHelper.local_addr_bits(21_111)
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("227 Entering Passive Mode (#{addr_bits})\r\n")
    end

    it 'does not accept PASV if no port set' do
      server.stop
      server.passive_port = nil
      server.start
      SpecHelper.gets_with_timeout(client)
      client.puts 'PASV'
      expect(SpecHelper.gets_with_timeout(client)).to eql("502 Aww hell no, use Active\r\n")
    end
  end

  context 'active' do
    before :each do
      SpecHelper.gets_with_timeout(client)

      @data_connection = Thread.new do
        @server_client = data_server.accept
        expect(@server_client).to_not be_nil
      end
    end

    after :each do
      data_server.close
    end

    it 'accepts PORT and connects to port' do
      client.puts "PORT #{data_server_addr_bits}"
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")
      @data_connection.join
    end

    it 'should switch to :active on port command' do
      expect(server.mode).to eql(:active)
      client.puts 'PASV'
      SpecHelper.gets_with_timeout(client)
      expect(server.mode).to eql(:passive)

      client.puts "PORT #{data_server_addr_bits}"
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

      @data_connection.join

      expect(server.mode).to eql(:active)
    end
  end

  context 'authentication commands' do
    before :each do
      SpecHelper.gets_with_timeout(client)
    end

    it 'accepts USER' do
      client.puts 'USER some_dude'
      expect(SpecHelper.gets_with_timeout(client)).to eql("331 send your password\r\n")
    end

    it 'accepts anonymous USER' do
      client.puts 'USER anonymous'
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 logged in\r\n")
    end

    it 'accepts PASS' do
      client.puts 'PASS password'
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 logged in\r\n")
    end

    it 'accepts ACCT' do
      client.puts 'ACCT'
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 WHATEVER!\r\n")
    end
  end

  context 'directory commands' do
    before :each do
      SpecHelper.gets_with_timeout(client)
    end

    it 'returns directory on PWD' do
      client.puts 'PWD'
      expect(SpecHelper.gets_with_timeout(client)).to eql("257 \"/pub\" is current directory\r\n")
    end

    it 'says OK to any CWD, CDUP, without doing anything' do
      client.puts 'CWD somewhere/else'
      expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
      client.puts 'CDUP'
      expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
    end
  end

  context 'file commands' do
    before :each do
      SpecHelper.gets_with_timeout(client)
    end

    it 'accepts TYPE ascii' do
      client.puts 'TYPE A'
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Type set to A.\r\n")
    end

    it 'accepts TYPE image' do
      client.puts 'TYPE I'
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Type set to I.\r\n")
    end

    it 'does not accept TYPEs other than ascii or image' do
      client.puts 'TYPE E'
      expect(SpecHelper.gets_with_timeout(client)).to eql("504 We don't allow those\r\n")
      client.puts 'TYPE N'
      expect(SpecHelper.gets_with_timeout(client)).to eql("504 We don't allow those\r\n")
      client.puts 'TYPE T'
      expect(SpecHelper.gets_with_timeout(client)).to eql("504 We don't allow those\r\n")
      client.puts 'TYPE C'
      expect(SpecHelper.gets_with_timeout(client)).to eql("504 We don't allow those\r\n")
      client.puts 'TYPE L'
      expect(SpecHelper.gets_with_timeout(client)).to eql("504 We don't allow those\r\n")
    end

    context 'passive' do
      let(:data_client) { TCPSocket.open('127.0.0.1', data_port) }

      before :each do
        client.puts 'PASV'
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("227 Entering Passive Mode (#{data_addr_bits})\r\n")
      end

      it 'accepts STOR with filename' do
        client.puts 'STOR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")
        data_client.puts '1234567890'
        data_client.close
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
        expect(server.file('some_file').bytes).to eql(10)
        expect(server.file('some_file').data).to eql('1234567890')
      end

      it 'accepts STOR with filename and trailing newline' do
        client.puts 'STOR some_file'
        SpecHelper.gets_with_timeout(client)
        # puts tries to be smart and only write a single \n
        data_client.puts "1234567890\n\n"
        data_client.close
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
        expect(server.file('some_file').bytes).to eql(11)
        expect(server.file('some_file').data).to eql("1234567890\n")
      end

      it 'accepts STOR with filename and long file' do
        client.puts 'STOR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")
        data_client.puts('1234567890' * 10_000)
        data_client.close
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_file')
      end

      it 'accepts STOR with streams' do
        client.puts 'STOR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")
        data_client.write '1234567890'
        data_client.flush
        data_client.write '1234567890'
        data_client.flush
        data_client.close
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
        expect(server.file('some_file').data).to eql('12345678901234567890')
      end

      it 'does not accept RETR without a filename' do
        client.puts 'RETR'
        expect(SpecHelper.gets_with_timeout(client)).to eql("501 No filename given\r\n")
      end

      it 'does not serve files that do not exist' do
        client.puts 'RETR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("550 File not found\r\n")
      end

      it 'accepts RETR with a filename' do
        server.add_file('some_file', '1234567890')
        client.puts 'RETR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 File status ok, about to open data connection\r\n")
        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close
        expect(data).to eql('1234567890')
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 File transferred\r\n")
      end

      it 'accepts DELE with a filename' do
        server.add_file('some_file', '1234567890')
        client.puts 'DELE some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 Delete operation successful.\r\n")
        expect(server.files).to_not include('some_file')
      end

      it 'gives error message when trying to delete a file that does not exist' do
        client.puts 'DELE non_existing_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("550 Delete operation failed.\r\n")
      end

      it 'accepts a LIST command' do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts 'LIST'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")
        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close
        expect(data).to eql([
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('some_file').created.strftime('%b %d %H:%M')}\tsome_file\n",
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file('another_file').created.strftime('%b %d %H:%M')}\tanother_file\n"
        ].join)
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end

      it 'accepts a LIST command with a wildcard argument' do
        files = ['test.jpg', 'test-2.jpg', 'test.txt']
        files.each do |file|
          server.add_file(file, '1234567890')
        end

        client.puts 'LIST *.jpg'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")

        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close
        expect(data).to eql(files[0, 2].map do |file|
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file(file).created.strftime('%b %d %H:%M')}\t#{file}\n"
        end.join)
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end

      it 'accepts a LIST command with multiple wildcard arguments' do
        files = ['test.jpg', 'test.gif', 'test.txt']
        files.each do |file|
          server.add_file(file, '1234567890')
        end

        client.puts 'LIST *.jpg *.gif'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")

        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close
        expect(data).to eql(files[0, 2].map do |file|
          "-rw-r--r--\t1\towner\tgroup\t10\t#{server.file(file).created.strftime('%b %d %H:%M')}\t#{file}\n"
        end.join)
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end

      it 'accepts an NLST command' do
        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts 'NLST'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")
        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close
        expect(data).to eql("some_file\nanother_file\n")
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end

      it 'accepts an NLST command with wildcard arguments' do
        files = ['test.jpg', 'test.txt', 'test2.jpg']
        files.each do |file|
          server.add_file(file, '1234567890')
        end

        client.puts 'NLST *.jpg'

        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")
        data = SpecHelper.gets_with_timeout(data_client, endwith: "\0", chunk: 1024)
        data_client.close

        expect(data).to eql("test.jpg\ntest2.jpg\n")
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end

      it 'should allow mdtm' do
        filename = 'file.txt'
        now = Time.now
        server.add_file(filename, 'some dummy content', now)
        client.puts "MDTM #{filename}"
        expect(SpecHelper.gets_with_timeout(client)).to eql("213 #{now.strftime('%Y%m%d%H%M%S')}\r\n")
      end
    end

    context 'active' do
      before :each do
        @data_connection = Thread.new do
          @server_client = data_server.accept
        end
      end

      after :each do
        data_server.close
        @data_connection = nil
      end

      it 'creates a directory on MKD' do
        client.puts 'MKD some_dir'
        expect(SpecHelper.gets_with_timeout(client)).to eql("257 OK!\r\n")
      end

      it 'should save the directory after you CWD' do
        client.puts 'CWD /somewhere/else'
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
        client.puts 'PWD'
        expect(SpecHelper.gets_with_timeout(client)).to eql("257 \"/somewhere/else\" is current directory\r\n")
      end

      it 'CWD should add a / to the beginning of the directory' do
        client.puts 'CWD somewhere/else'
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
        client.puts 'PWD'
        expect(SpecHelper.gets_with_timeout(client)).to eql("257 \"/somewhere/else\" is current directory\r\n")
      end

      it 'should not change the directory on CDUP' do
        client.puts 'CDUP'
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
        client.puts 'PWD'
        expect(SpecHelper.gets_with_timeout(client)).to eql("257 \"/pub\" is current directory\r\n")
      end

      it 'sends error message if no PORT received' do
        client.puts 'STOR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("425 Ain't no data port!\r\n")
      end

      it 'accepts STOR with filename' do
        client.puts "PORT #{data_server_addr_bits}"
        expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

        client.puts 'STOR some_other_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")

        @data_connection.join
        @server_client.print '12345'
        @server_client.close

        expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
        expect(server.files).to include('some_other_file')
        expect(server.file('some_other_file').bytes).to eql(5)
      end

      it 'accepts RETR with a filename' do
        client.puts "PORT #{data_server_addr_bits}"
        expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

        server.add_file('some_file', '1234567890')
        client.puts 'RETR some_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 File status ok, about to open data connection\r\n")

        @data_connection.join
        data = SpecHelper.gets_with_timeout(@server_client, endwith: "\0", chunk: 1024)
        @server_client.close

        expect(data).to eql('1234567890')
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 File transferred\r\n")
      end

      it 'accepts RNFR without filename' do
        client.puts 'RNFR'
        expect(SpecHelper.gets_with_timeout(client)).to eql("501 Send path name.\r\n")
      end

      it 'accepts RNTO without RNFR' do
        client.puts 'RNTO some_other_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("503 Send RNFR first.\r\n")
      end

      it 'accepts RNTO and RNFR without filename' do
        client.puts 'RNFR from_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts 'RNTO'
        expect(SpecHelper.gets_with_timeout(client)).to eql("501 Send path name.\r\n")
      end

      it 'accepts RNTO and RNFR for not existing file' do
        client.puts 'RNFR from_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts 'RNTO to_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("550 File not found.\r\n")
      end

      it 'accepts RNTO and RNFR' do
        server.add_file('from_file', '1234567890')

        client.puts 'RNFR from_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("350 Send RNTO to complete rename.\r\n")

        client.puts 'RNTO to_file'
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 Path renamed.\r\n")

        expect(server.files).to include('to_file')
        expect(server.files).to_not include('from_file')
      end

      it 'accepts an NLST command' do
        client.puts "PORT #{data_server_addr_bits}"
        expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

        server.add_file('some_file', '1234567890')
        server.add_file('another_file', '1234567890')
        client.puts 'NLST'
        expect(SpecHelper.gets_with_timeout(client)).to eql("150 Listing status ok, about to open data connection\r\n")

        @data_connection.join
        data = SpecHelper.gets_with_timeout(@server_client, endwith: "\0", chunk: 1024)
        @server_client.close

        expect(data).to eql("some_file\nanother_file\n")
        expect(SpecHelper.gets_with_timeout(client)).to eql("226 List information transferred\r\n")
      end
    end
  end
end
