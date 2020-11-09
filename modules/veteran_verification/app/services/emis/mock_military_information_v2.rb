require 'emis/mock_military_information_service_v2'
require 'emis_redis/military_information_v2'
module EMISRedis
  class MockMilitaryInformationV2 < MilitaryInformationV2
    def service
      @service ||= EMIS::MockMilitaryInfoServiceV2.new
    end
  end
end