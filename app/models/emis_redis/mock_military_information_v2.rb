require 'emis/mock_military_information_service_v2'
module EMISRedis
  class MockMilitaryInformationV2 < MilitaryInformationV2
    def service
      @service ||= EMIS::MMilitaryInformationServiceV2.new
    end
  end
end