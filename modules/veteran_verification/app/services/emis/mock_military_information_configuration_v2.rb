# frozen_string_literal: true

require 'emis/military_information_configuration_v2'
module EMIS
  # Configuration for {EMIS::MockMilitaryInformationService}
  class MockMilitaryInformationConfigurationV2 < MilitaryInformationConfigurationV2
    def base_path
      emis_url = URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.military_information_url.v2).to_s
      Rails.logger.info("Mock-emis URL: #{emis_url}")
      emis_url
    end
  end
end
