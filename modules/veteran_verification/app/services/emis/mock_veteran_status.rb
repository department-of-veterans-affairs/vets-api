# frozen_string_literal: true

require 'emis/veteran_status_service'

module EMISRedis
  class MockVeteranStatus < VeteranStatus
    def service
      @service ||= EMIS::MockVeteranStatusService.new
    end
  end
end
