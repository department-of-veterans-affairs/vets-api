# frozen_string_literal: false
module Faraday
  class Adapter
    class HTTPRequest < ::Net::HTTPRequest
      def capitalize(name)
        name
      end
    end

    class Get < Faraday::Adapter::HTTPRequest
      METHOD = 'GET'
      REQUEST_HAS_BODY  = false
      RESPONSE_HAS_BODY = true
    end
  end
end
