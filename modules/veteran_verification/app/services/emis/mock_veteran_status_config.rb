# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  # Configuration for {EMIS::VeteranStatusService}
  # includes API URL and breakers service name.
  #
  class MockVeteranStatusConfig < VeteranStatusConfiguration
    # Veteran Status Service URL
    # @return [String] Veteran Status Service URL
    def base_path
      URI.join(Settings.vet_verification.mock_emis_host, Settings.emis.veteran_status_url).to_s
    end

    # :nocov:

    # Veteran Status Service breakers name
    # @return [String] Veteran Status Service breakers name
    def service_name
      'EmisVeteranStatus'
    end
    # :nocov:
  end
end
