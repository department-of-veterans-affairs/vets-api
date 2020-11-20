# frozen_string_literal: true

require_dependency 'emis/military_information_configuration_v2'
module EMIS
  # Configuration for {EMIS::MockMilitaryInformationService}
  class MockMilitaryInformationConfigurationV2 < MilitaryInformationConfigurationV2
    def base_path
      URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.military_information_url.v2).to_s
    end
  end
end
