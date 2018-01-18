# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class VeteranStatusConfiguration < Configuration
    def base_path
      URI.join(Settings.emis.host, Settings.emis.veteran_status_url).to_s
    end

    # :nocov:
    def service_name
      'EmisVeteranStatus'
    end
    # :nocov:
  end
end
