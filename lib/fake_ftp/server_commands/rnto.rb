# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Rnto
      def run(ctx, rename_to = '', *)
        return '501 Send path name.' if rename_to.nil? || rename_to.empty?
        return '503 Send RNFR first.' if ctx.command_state[:rename_from].nil?

        f = ctx.file(ctx.command_state[:rename_from])
        if f.nil?
          ctx.command_state[:rename_from] = nil
          return '550 File not found.'
        end

        f.name = rename_to
        ctx.command_state[:rename_from] = nil
        '250 Path renamed.'
      end
    end
  end
end
