module FakeFtp
  module Command
    class List < Base

      def run(*args)
        wildcards = []
        args.each do |arg|
          next unless arg.include? '*'
          wildcards << arg.gsub('*', '.*')
        end

        respond_with('425 Ain\'t no data port!') && return if server.active? && @active_connection.nil?

        respond_with('150 Listing status ok, about to open data connection')
        data_client = server.active? ? @active_connection : @data_server.accept

        files = server.files
        if not wildcards.empty?
          files = server.files.select do |f|
            wildcards.any? { |wildcard| f.name =~ /#{wildcard}/ }
          end
        end
        files = server.files.map do |f|
          "-rw-r--r--\t1\towner\tgroup\t#{f.bytes}\t#{f.created.strftime('%b %d %H:%M')}\t#{f.name}"
        end

        data_client.write(files.join("\n"))
        data_client.close
        @active_connection = nil

        '226 List information transferred'
      end

    end
  end
end
