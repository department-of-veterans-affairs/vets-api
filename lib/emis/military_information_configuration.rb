# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class MilitaryInformationConfiguration < Configuration
    def base_path
      URI.join(Settings.emis.host, Settings.emis.military_information_url).to_s
    end

    # :nocov:
    def service_name
      'EmisMilitaryInformation'
    end
    # :nocov:
  end
end
