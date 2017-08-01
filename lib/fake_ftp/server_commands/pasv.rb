# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Pasv
      def run(ctx, *)
        return '502 Aww hell no, use Active' if ctx.passive_port.nil?
        ctx.mode = :passive
        p1 = (ctx.passive_port / 256).to_i
        p2 = ctx.passive_port % 256
        "227 Entering Passive Mode (127,0,0,1,#{p1},#{p2})"
      end
    end
  end
end
