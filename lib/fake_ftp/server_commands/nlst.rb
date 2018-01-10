# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Nlst
      def run(ctx, *args)
        if ctx.active? && ctx.command_state[:active_connection].nil?
          ctx.respond_with('425 Ain\'t no data port!')
          return
        end

        ctx.respond_with('150 Listing status ok, about to open data connection')
        data_client = if ctx.active?
                        ctx.command_state[:active_connection]
                      else
                        ctx.data_server.accept
                      end

        paths_or_wildcards = ctx.build_wildcards(args)
        matching = ctx.matching_files(paths_or_wildcards).map do |f|
          "#{f.name}\n"
        end

        data_client.write(matching.join)
        data_client.close
        ctx.command_state[:active_connection] = nil

        '226 List information transferred'
      end
    end
  end
end
