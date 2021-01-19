# frozen_string_literal: true

require 'emis/veteran_status_configuration'

module EMIS
  class MockVeteranStatusConfig < VeteranStatusConfiguration
    def base_path
      URI.parse(Settings.vet_verification.mock_emis_host + Settings.emis.veteran_status_url).to_s
    end
  end
end
