class FakeFtp::Command::Retr < Base

  def run(filename = '')
    respond_with('501 No filename given') if filename.empty?

    file = file(::File.basename(filename.to_s))
    return respond_with('550 File not found') if file.nil?

    respond_with('425 Ain\'t no data port!') && return if active? && @active_connection.nil?

    respond_with('150 File status ok, about to open data connection')
    data_client = active? ? @active_connection : @data_server.accept

    data_client.write(file.data)

    data_client.close
    @active_connection = nil
    '226 File transferred'
  end

end
