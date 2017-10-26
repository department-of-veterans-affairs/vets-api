# frozen_string_literal: true
require 'evss/auth_headers'
require 'evss/letters/service'
require 'evss/letters/mock_service'

module EVSS
  module GiBillStatus
    class ServiceFactory
      def self.get_service(user: nil, mock_service: false)
        return EVSS::GiBillStatus::MockService.new if mock_service == true || mock_service == 'true'
        EVSS::GiBillStatus::Service.new(user)
      end
    end
  end
end
