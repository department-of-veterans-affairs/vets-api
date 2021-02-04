# frozen_string_literal: true

module EMISRedis
  class MockMilitaryInformationV2 < MilitaryInformationV2
    def service
      military_information_service_v2 = EMIS::MockMilitaryInformationServiceV2.new
      @service ||= military_information_service_v2
    end
  end
end
