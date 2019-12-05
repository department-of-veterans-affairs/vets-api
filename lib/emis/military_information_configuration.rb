# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  # Configuration for {EMIS::MilitaryInformationService}
  # includes API URL and breakers service name.
  #
  class MilitaryInformationConfiguration < Configuration
    # Military Information Service URL
    # @return [String] Military Information Service URL
    def base_path
      URI.join(Settings.emis.host, Settings.emis.military_information_url.v1).to_s
    end

    # :nocov:

    # Military Information Service breakers name
    # @return [String] Military Information Service breakers name
    def service_name
      'EmisMilitaryInformation'
    end
    # :nocov:
  end
end
