# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class MockVeteranStatusConfig < VeteranStatusConfiguration
    def base_path
      emis_url = URI.parse(Settings.vet_verification.mock_emis_host + Settings.emis.veteran_status_url).to_s
      Rails.logger.info("Mock-emis URL: #{emis_url}")
      emis_url
    end
  end
end
