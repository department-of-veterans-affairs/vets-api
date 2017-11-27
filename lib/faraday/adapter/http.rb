require_relative 'requests'

module Faraday
  class Adapter
    class HTTP < Net::HTTP
      def get(path, initheader = nil, dest = nil, &block)
        res = nil
        request(Faraday::Adapter::Get.new(path, initheader)) {|r|
          r.read_body dest, &block
          res = r
        }
        res
      end

      def request_get(path, initheader = nil, &block)
        request(Faraday::Adapter::Get.new(path, initheader), &block)
      end
    end
  end
end
