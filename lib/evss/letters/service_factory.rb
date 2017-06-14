# frozen_string_literal: true
require 'evss/auth_headers'
require 'evss/letters/service'
require 'evss/letters/mock_service'

module EVSS
  module Letters
    class ServiceFactory
      def self.get_service(user: nil, mock_service: false)
        return EVSS::Letters::MockService.new if mock_service == true || mock_service == 'true'
        headers = EVSS::AuthHeaders.new(user).to_h
        EVSS::Letters::Service.new(headers)
      end
    end
  end
end
