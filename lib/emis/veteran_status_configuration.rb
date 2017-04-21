# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class VeteranStatusConfiguration < Configuration
    URL = Settings.emis.veteran_status_url

    def base_path
      Settings.emis.veteran_status_url
    end

    # :nocov:
    def service_name
      'EmisVeteranStatus'
    end
    # :nocov:
  end
end
