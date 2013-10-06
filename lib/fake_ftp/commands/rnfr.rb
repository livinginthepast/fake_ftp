module FakeFtp
  module Command
    class Rnfr < Base

      def run(rename_from='')
        return '501 Send path name.' if rename_from.nil? || rename_from.size < 1

        @rename_from = rename_from
        '350 Send RNTO to complete rename.'
      end

    end
  end
end
