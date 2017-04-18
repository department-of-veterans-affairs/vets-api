# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class MilitaryInformationConfiguration < Configuration
    URL = Settings.emis.military_information_url

    def base_path
      Settings.emis.military_information_url
    end

    def service_name
      'EmisMilitaryInformation'
    end
  end
end
