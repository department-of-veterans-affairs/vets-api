# frozen_string_literal: true

require 'emis/military_information_service_v2'
require 'emis/mock_military_information_configuration_v2'
module EMIS
  class MockMilitaryInfoServiceV2 < MilitaryInformationServiceV2
    configuration EMIS::MockMilitaryInfoConfig
  end
end
