# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Cwd
      def run(ctx, wd, *)
        wd = "/#{wd}" unless wd.start_with?('/')
        ctx.workdir = wd
        '250 OK!'
      end
    end
  end
end
