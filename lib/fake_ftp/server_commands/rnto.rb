# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Rnto
      def run(ctx, rename_to = '', *)
        return '501 Send path name.' if rename_to.nil? || rename_to.empty?
        return '503 Send RNFR first.' if ctx.command_state[:rename_from].nil?

        begin
          ctx.rename_file(ctx.command_state[:rename_from], rename_to)
        rescue ArgumentError
          ctx.command_state[:rename_from] = nil
          return '550 File not found.'
        end

        ctx.command_state[:rename_from] = nil
        '250 Path renamed.'
      end
    end
  end
end
