# frozen_string_literal: true
require_relative 'service'
require_relative 'mock_service'

module EVSS
  module Letters
    class ServiceFactory
      def self.get_service(mock_service: false)
        mock_service == true || mock_service == 'true' ? EVSS::Letters::MockService.new : EVSS::Letters::Service.new
      end
    end
  end
end
