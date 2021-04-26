# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Retr
      def run(ctx, *filename_parts)
        filename = filename_parts.join(' ')
        ctx.respond_with('501 No filename given') if filename.empty?

        f = ctx.file(filename.to_s)
        return ctx.respond_with('550 File not found') if f.nil?

        if ctx.active? && ctx.command_state[:active_connection].nil?
          ctx.respond_with('425 Ain\'t no data port!')
          return
        end

        ctx.respond_with('150 File status ok, about to open data connection')
        data_client = if ctx.active?
                        ctx.command_state[:active_connection]
                      else
                        ctx.data_server.accept
                      end

        data_client.write(f.data)

        data_client.close
        ctx.command_state[:active_connection] = nil
        '226 File transferred'
      end
    end
  end
end
