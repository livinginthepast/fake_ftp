module FakeFtp
  module Command
    class Pasv < Base

      def run(*args)
        if passive_port
          server.mode = :passive
          p1 = (passive_port / 256).to_i
          p2 = passive_port % 256
          "227 Entering Passive Mode (127,0,0,1,#{p1},#{p2})"
        else
          '502 Aww hell no, use Active'
        end
      end

    end
  end
end
