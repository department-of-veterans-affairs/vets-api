# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class MockMilitaryInfoConfig < MilitaryInformationConfigurationV2
    def base_path
      URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.military_information_url.v2).to_s
    end
  end
end
