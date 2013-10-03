class FakeFtp::Command::Stor < Base

  def run(filename = '')
    return '425 Ain\'t no data port!' if server.active? && @active_connection.nil?

    server.respond_with('125 Do it!')
    data_client = server.active? ? @active_connection : @data_server.accept

    data = data_client.read(nil).chomp
    server.add_file(::File.basename(filename.to_s), data)

    data_client.close
    @active_connection = nil
    '226 Did it!'
  end

end
