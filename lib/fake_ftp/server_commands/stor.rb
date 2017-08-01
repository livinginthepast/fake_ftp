# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Stor
      def run(ctx, filename = '', *)
        if ctx.active? && ctx.command_state[:active_connection].nil?
          ctx.respond_with('425 Ain\'t no data port!')
          return
        end

        ctx.respond_with('125 Do it!')
        data_client = if ctx.active?
                        ctx.command_state[:active_connection]
                      else
                        ctx.data_server.accept
                      end

        data = data_client.read(nil)
        ctx.store[ctx.abspath(filename)] = FakeFtp::File.new(
          filename.to_s, data, ctx.mode
        )

        data_client.close
        ctx.command_state[:active_connection] = nil
        '226 Did it!'
      end
    end
  end
end
