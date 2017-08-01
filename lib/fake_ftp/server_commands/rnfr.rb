# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Rnfr
      def run(ctx, rename_from = '', *)
        return '501 Send path name.' if rename_from.nil? || rename_from.empty?

        ctx.command_state[:rename_from] = if ctx.absolute?
                                            ctx.abspath(rename_from)
                                          else
                                            rename_from
                                          end
        '350 Send RNTO to complete rename.'
      end
    end
  end
end
