# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class List
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

        wildcards = ctx.build_wildcards(args)
        statlines = ctx.matching_files(wildcards).map do |f|
          %W[
            -rw-r--r--
            1
            owner
            group
            #{f.bytes}
            #{f.created.strftime('%b %d %H:%M')}
            #{f.name}
          ].join("\t")
        end
        data_client.write(statlines.join("\n"))
        data_client.close
        ctx.command_state[:active_connection] = nil

        '226 List information transferred'
      end
    end
  end
end
