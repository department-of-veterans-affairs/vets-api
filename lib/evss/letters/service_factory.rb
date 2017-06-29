# frozen_string_literal: true
require 'evss/auth_headers'
require 'evss/letters/service'
require 'evss/letters/mock_service'

module EVSS
  module Letters
    class ServiceFactory
      def self.get_service(user: nil, mock_service: false)
        headers = EVSS::AuthHeaders.new(user).to_h
        return EVSS::Letters::MockService.new(headers) if mock_service == true || mock_service == 'true'
        EVSS::Letters::Service.new(headers)
      end
    end
  end
end
