# frozen_string_literal: true

require 'emis/mock_military_information_service_v2'
require 'emis_redis/military_information_v2'
module EMISRedis
  class MockMilitaryInformationV2 < MilitaryInformationV2
    def service
      military_info_service_v2 = EMIS::MockMilitaryInfoServiceV2.new
      @service ||= military_info_service_v2
    end
  end
end
