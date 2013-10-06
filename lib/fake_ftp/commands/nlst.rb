module FakeFtp
  module Command
    class Nlst < Base

      def run(*args)
        return '425 Ain\'t no data port!' if server.active? && @active_connection.nil?

        server.respond_with('150 Listing status ok, about to open data connection')
        data_client = server.active? ? @active_connection : @data_server.accept

        data_client.write(files.join("\n"))
        data_client.close
        @active_connection = nil

        '226 List information transferred'
      end

    end
  end
end
