require 'common/client/configuration/soap'

module EMIS
  class MockVeteranStatusConfig < VeteranStatusConfiguration
    def base_path
      URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.veteran_status_url).to_s
    end
  end
end