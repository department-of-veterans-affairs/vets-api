# frozen_string_literal: true

require 'emis_redis/military_information_v2'
require_relative '../../services/emis/mock_military_information_service_v2'
module EMISRedis
  class MockMilitaryInformationV2 < MilitaryInformationV2
    def service
      military_information_service_v2 = EMIS::MockMilitaryInformationServiceV2.new
      @service ||= military_information_service_v2
    end
  end
end
