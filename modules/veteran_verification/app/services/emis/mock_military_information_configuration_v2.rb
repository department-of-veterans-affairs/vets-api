# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  # Configuration for {EMIS::MilitaryInformationService}
  # includes API URL and breakers service name.
  #
  class MMilitaryInfoConfig < MilitaryInformationConfigurationV2
    # Military Information Service URL
    # @return [String] Military Information Service URL
    def base_path
      URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.military_information_url.v2).to_s
    end
  end
end
