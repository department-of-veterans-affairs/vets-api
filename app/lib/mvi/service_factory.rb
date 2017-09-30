# frozen_string_literal: true
require_relative 'service'
require_relative 'mock_service'

module MVI
  class ServiceFactory
    def self.get_service(mock_service: false)
      mock_service == true || mock_service == 'true' ? MVI::MockService.new : MVI::Service.new
    end
  end
end
