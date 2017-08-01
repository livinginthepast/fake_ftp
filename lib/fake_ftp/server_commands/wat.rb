# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Wat
      def run(ctx, *)
        if ctx.active? && ctx.command_state[:active_connection].nil?
          ctx.respond_with('425 Ain\'t no data port!')
          return
        end

        data_client = if ctx.active?
                        ctx.command_state[:active_connection]
                      else
                        ctx.data_server.accept
                      end
        data_client.write(invisible_bike)
        data_client.close
        ctx.command_state[:active_connection] = nil
        '418 Pizza Party'
      end

      private def invisible_bike
        ::File.read(
          ::File.expand_path(
            '../../../../spec/fixtures/invisible_bike.jpg',
            __FILE__
          )
        )
      end
    end
  end
end
