# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Port
      def run(ctx, remote = '', *)
        remote = remote.split(',')
        remote_port = remote[4].to_i * 256 + remote[5].to_i
        unless ctx.command_state[:active_connection].nil?
          ctx.command_state[:active_connection].close
          ctx.command_state[:active_connection] = nil
        end
        ctx.mode = :active
        ctx.debug('_port active connection ->')
        ctx.command_state[:active_connection] = ::TCPSocket.new(
          '127.0.0.1', remote_port
        )
        ctx.debug('_port active connection <-')
        '200 Okay'
      end
    end
  end
end
