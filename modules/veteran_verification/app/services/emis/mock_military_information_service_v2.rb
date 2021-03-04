# frozen_string_literal: true

require 'emis/military_information_service_v2'

module EMIS
  class MockMilitaryInformationServiceV2 < MilitaryInformationServiceV2
    configuration EMIS::MockMilitaryInformationConfigurationV2
  end
end
