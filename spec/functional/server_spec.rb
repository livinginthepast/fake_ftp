describe FakeFtp::Server, 'commands', functional: true do
  let(:absolute?) { true }
  let(:data_port) { rand(16_000..19_000) }
  let(:data_addr_bits) { SpecHelper.local_addr_bits(data_port) }
  let(:client_port) { rand(19_000..22_000) }
  let(:client_addr_bits) { SpecHelper.local_addr_bits(client_port) }
  let(:data_server_port) { rand(22_000..24_000) }

  let(:client) do
    TCPSocket.open('127.0.0.1', client_port).tap { |s| s.sync = true }
  end

  let(:server) do
    FakeFtp::Server.new(
      client_port, data_port,
      debug: ENV['DEBUG'] == '1',
      absolute: absolute?
    )
  end

  let(:data_server) do
    SpecHelper::FakeDataServer.new(data_server_port)
  end

  before { server.start }

  after do
    client.close
    server.stop
  end

  context 'general' do
    it 'should accept connections' do
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("220 Can has FTP?\r\n")
    end

    it 'should get unknown command response when nothing is sent' do
      SpecHelper.gets_with_timeout(client)
      client.write("\r\n")
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("500 Unknown command\r\n")
    end

    it 'accepts QUIT' do
      SpecHelper.gets_with_timeout(client)
      client.write("QUIT\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("221 OMG bye!\r\n")
    end

    it 'should accept multiple commands in one session' do
      SpecHelper.gets_with_timeout(client)
      client.write("USER thing\r\n")
      SpecHelper.gets_with_timeout(client)
      client.write("PASS thing\r\n")
      SpecHelper.gets_with_timeout(client)
      client.write("ACCT thing\r\n")
      SpecHelper.gets_with_timeout(client)
      client.write("USER thing\r\n")
    end

    it 'should accept SITE command' do
      SpecHelper.gets_with_timeout(client)
      client.write("SITE umask\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql "200 umask\r\n"
    end
  end

  context 'passive' do
    it 'accepts PASV' do
      expect(server.mode).to eql(:active)
      SpecHelper.gets_with_timeout(client)
      client.write("PASV\r\n")
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("227 Entering Passive Mode (#{data_addr_bits})\r\n")
      expect(server.mode).to eql(:passive)
    end

    it 'responds with correct PASV port' do
      server.stop
      server.passive_port = 21_111
      server.start
      SpecHelper.gets_with_timeout(client)
      client.write("PASV\r\n")
      addr_bits = SpecHelper.local_addr_bits(21_111)
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("227 Entering Passive Mode (#{addr_bits})\r\n")
    end

    it 'does not accept PASV if no port set' do
      server.stop
      server.passive_port = nil
      server.start
      SpecHelper.gets_with_timeout(client)
      client.write("PASV\r\n")
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("502 Aww hell no, use Active\r\n")
    end
  end

  context 'active' do
    before :each do
      SpecHelper.gets_with_timeout(client)
      data_server.start
    end

    after :each do
      data_server.stop
    end

    it 'accepts PORT and connects to port' do
      client.write("PORT #{data_server.addr_bits}\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")
    end

    it 'should switch to :active on port command' do
      expect(server.mode).to eql(:active)
      client.write("PASV\r\n")
      SpecHelper.gets_with_timeout(client)
      expect(server.mode).to eql(:passive)

      client.write("PORT #{data_server.addr_bits}\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

      expect(server.mode).to eql(:active)
    end
  end

  context 'authentication commands' do
    before :each do
      SpecHelper.gets_with_timeout(client)
    end

    it 'accepts USER' do
      client.write("USER some_dude\r\n")
      expect(SpecHelper.gets_with_timeout(client))
        .to eql("331 send your password\r\n")
    end

    it 'accepts anonymous USER' do
      client.write("USER anonymous\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 logged in\r\n")
    end

    it 'accepts PASS' do
      client.write("PASS password\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 logged in\r\n")
    end

    it 'accepts ACCT' do
      client.write("ACCT\r\n")
      expect(SpecHelper.gets_with_timeout(client)).to eql("230 WHATEVER!\r\n")
    end
  end

  [true, false].each do |absolute|
    let(:absolute?) { absolute }

    context "directory commands with absolute=#{absolute}" do
      before :each do
        SpecHelper.gets_with_timeout(client)
      end

      it 'returns directory on PWD' do
        client.write("PWD\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("257 \"/pub\" is current directory\r\n")
      end

      it 'says OK to any CWD, CDUP, without doing anything' do
        client.write("CWD somewhere/else\r\n")
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
        client.write("CDUP\r\n")
        expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
      end
    end
  end

  [true, false].each do |absolute|
    context "file commands with absolute=#{absolute}" do
      let(:absolute?) { absolute }
      let(:file_prefix) { absolute ? '/pub/' : '' }

      before :each do
        SpecHelper.gets_with_timeout(client)
      end

      it 'accepts TYPE ascii' do
        client.write("TYPE A\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("200 Type set to A.\r\n")
      end

      it 'accepts TYPE image' do
        client.write("TYPE I\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("200 Type set to I.\r\n")
      end

      it 'does not accept TYPEs other than ascii or image' do
        client.write("TYPE E\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("504 We don't allow those\r\n")
        client.write("TYPE N\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("504 We don't allow those\r\n")
        client.write("TYPE T\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("504 We don't allow those\r\n")
        client.write("TYPE C\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("504 We don't allow those\r\n")
        client.write("TYPE L\r\n")
        expect(SpecHelper.gets_with_timeout(client))
          .to eql("504 We don't allow those\r\n")
      end

      context 'passive' do
        let(:data_client) do
          TCPSocket.open('127.0.0.1', data_port).tap { |c| c.sync = true }
        end

        before :each do
          client.write("PASV\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("227 Entering Passive Mode (#{data_addr_bits})\r\n")
        end

        it 'accepts STOR with filename' do
          client.write("STOR some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")
          data_client.write('1234567890')
          data_client.close
          expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
          expect(server.files).to include(file_prefix + 'some_file')
          expect(server.file(file_prefix + 'some_file').bytes).to eql(10)
          expect(server.file(file_prefix + 'some_file').data)
            .to eql('1234567890')
        end

        it 'accepts STOR with filename and trailing newline' do
          client.write("STOR some_file\r\n")
          SpecHelper.gets_with_timeout(client)
          data_client.write("1234567890\n")
          data_client.close
          expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
          expect(server.files).to include(file_prefix + 'some_file')
          expect(server.file(file_prefix + 'some_file').bytes).to eql(11)
          expect(server.file(file_prefix + 'some_file').data)
            .to eql("1234567890\n")
        end

        it 'accepts STOR with filename and long file' do
          client.write("STOR some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")
          data_client.write('1234567890' * 10_000)
          data_client.close
          expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
          expect(server.files).to include(file_prefix + 'some_file')
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
          expect(server.file(file_prefix + 'some_file').data)
            .to eql('12345678901234567890')
        end

        it 'does not accept RETR without a filename' do
          client.write("RETR\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("501 No filename given\r\n")
        end

        it 'does not serve files that do not exist' do
          client.write("RETR some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("550 File not found\r\n")
        end

        it 'accepts RETR with a filename' do
          server.add_file(file_prefix + 'some_file', '1234567890')
          client.write("RETR #{file_prefix}some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 File status ok, about to open data connection\r\n")
          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close
          expect(data).to eql('1234567890')
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 File transferred\r\n")
        end

        it 'accepts DELE with a filename' do
          server.add_file('some_file', '1234567890')
          client.write("DELE some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("250 Delete operation successful.\r\n")
          expect(server.files).to_not include('some_file')
        end

        it 'gives error message when trying to delete a file ' \
          'that does not exist' do
          client.write("DELE non_existing_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("550 Delete operation failed.\r\n")
        end

        it 'accepts a LIST command' do
          server.add_file(file_prefix + 'some_file', '1234567890')
          server.add_file(file_prefix + 'another_file', '1234567890')
          client.puts("LIST\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")
          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close
          expect(data).to eql([
            SpecHelper.statline(server.file(file_prefix + 'some_file')),
            SpecHelper.statline(server.file(file_prefix + 'another_file'))
          ].join("\n"))
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end

        it 'accepts a LIST command with a wildcard argument' do
          infiles = %w[test.jpg test-2.jpg test.txt].map do |f|
            "#{file_prefix}#{f}"
          end
          infiles.each do |f|
            server.add_file(f, '1234567890')
          end

          client.write("LIST *.jpg\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")

          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close
          expect(data).to eql(
            infiles[0, 2].map do |f|
              SpecHelper.statline(server.file(f))
            end.join("\n")
          )
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end

        it 'accepts a LIST command with multiple wildcard arguments' do
          infiles = %w[test.jpg test.gif test.txt].map do |f|
            "#{file_prefix}#{f}"
          end
          infiles.each do |file|
            server.add_file(file, '1234567890')
          end

          client.write("LIST *.jpg *.gif\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")

          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close
          expect(data).to eql(
            infiles[0, 2].map do |f|
              SpecHelper.statline(server.file(f))
            end.join("\n")
          )
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end

        it 'accepts an NLST command' do
          server.add_file('some_file', '1234567890')
          server.add_file('another_file', '1234567890')
          client.write("NLST\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")
          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close
          expect(data).to eql("some_file\nanother_file\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end

        it 'accepts an NLST command with wildcard arguments' do
          files = ['test.jpg', 'test.txt', 'test2.jpg']
          files.each do |file|
            server.add_file(file, '1234567890')
          end

          client.write("NLST *.jpg\r\n")

          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")
          data = SpecHelper.gets_with_timeout(data_client, endwith: "\0")
          data_client.close

          expect(data).to eql("test.jpg\ntest2.jpg\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end

        it 'should allow mdtm' do
          filename = file_prefix + 'file.txt'
          now = Time.now
          server.add_file(filename, 'some dummy content', now)
          client.write("MDTM #{filename}\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("213 #{now.strftime('%Y%m%d%H%M%S')}\r\n")
        end
      end

      context 'active' do
        before :each do
          data_server.start
        end

        after :each do
          data_server.stop
        end

        it 'creates a directory on MKD' do
          client.write("MKD some_dir\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("257 OK!\r\n")
        end

        it 'should save the directory after you CWD' do
          client.write("CWD /somewhere/else\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
          client.write("PWD\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("257 \"/somewhere/else\" is current directory\r\n")
        end

        it 'CWD should add a / to the beginning of the directory' do
          client.write("CWD somewhere/else\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
          client.write("PWD\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("257 \"/somewhere/else\" is current directory\r\n")
        end

        it 'should not change the directory on CDUP' do
          client.write("CDUP\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("250 OK!\r\n")
          client.write("PWD\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("257 \"/pub\" is current directory\r\n")
        end

        it 'sends error message if no PORT received' do
          client.write("STOR some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("425 Ain't no data port!\r\n")
        end

        it 'accepts STOR with filename' do
          client.write("PORT #{data_server.addr_bits}\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

          client.write("STOR some_other_file\r\n")
          expect(SpecHelper.gets_with_timeout(client)).to eql("125 Do it!\r\n")

          data_server.handler_sock.print('12345')
          data_server.handler_sock.close

          expect(SpecHelper.gets_with_timeout(client)).to eql("226 Did it!\r\n")
          expect(server.files).to include(file_prefix + 'some_other_file')
          expect(server.file(file_prefix + 'some_other_file').bytes).to eql(5)
        end

        it 'accepts RETR with a filename' do
          client.write("PORT #{data_server.addr_bits}\r\n")
          data_server.handler_sock
          expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

          server.add_file(file_prefix + 'some_file', '1234567890')
          client.write("RETR #{file_prefix}some_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 File status ok, about to open data connection\r\n")

          data = SpecHelper.gets_with_timeout(
            data_server.handler_sock, endwith: "\0"
          )
          data_server.handler_sock.close

          expect(data).to eql('1234567890')
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 File transferred\r\n")
        end

        it 'accepts RNFR without filename' do
          client.write("RNFR\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("501 Send path name.\r\n")
        end

        it 'accepts RNTO without RNFR' do
          client.write("RNTO some_other_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("503 Send RNFR first.\r\n")
        end

        it 'accepts RNTO and RNFR without filename' do
          client.write("RNFR from_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("350 Send RNTO to complete rename.\r\n")

          client.write("RNTO\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("501 Send path name.\r\n")
        end

        it 'accepts RNTO and RNFR for not existing file' do
          client.write("RNFR from_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("350 Send RNTO to complete rename.\r\n")

          client.write("RNTO to_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("550 File not found.\r\n")
        end

        it 'accepts RNTO and RNFR' do
          server.add_file(file_prefix + 'from_file', '1234567890')

          client.write("RNFR from_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("350 Send RNTO to complete rename.\r\n")

          client.write("RNTO to_file\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("250 Path renamed.\r\n")

          expect(server.files).to include(file_prefix + 'to_file')
          expect(server.files).to_not include(file_prefix + 'from_file')
        end

        it 'accepts an NLST command' do
          client.write("PORT #{data_server.addr_bits}\r\n")
          data_server.handler_sock
          expect(SpecHelper.gets_with_timeout(client)).to eql("200 Okay\r\n")

          server.add_file('some_file', '1234567890')
          server.add_file('another_file', '1234567890')
          client.write("NLST\r\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("150 Listing status ok, about to open data connection\r\n")

          data = SpecHelper.gets_with_timeout(
            data_server.handler_sock, endwith: "\0"
          )
          data_server.handler_sock.close

          expect(data).to eql("some_file\nanother_file\n")
          expect(SpecHelper.gets_with_timeout(client))
            .to eql("226 List information transferred\r\n")
        end
      end
    end
  end
end
