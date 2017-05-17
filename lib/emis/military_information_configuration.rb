# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class MilitaryInformationConfiguration < Configuration
    def base_path
      Settings.emis.military_information_url
    end

    # :nocov:
    def service_name
      'EmisMilitaryInformation'
    end
    # :nocov:
  end
end
