class FakeFtp::Command::Mdtm < Base

  def run(filename = '', local = false)
    server.respond_with('501 No filename given') && return if filename.empty?
    server_file = server.file(filename)
    server.respond_with('550 File not found') && return if server_file.nil?

    "213 #{server_file.last_modified_time.strftime("%Y%m%d%H%M%S")}"
  end

end
