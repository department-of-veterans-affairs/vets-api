# frozen_string_literal: true

require 'dmc/base_configuration'

module DMC
  class FSRConfiguration < DMC::BaseConfiguration
    def service_name
      'FSR'
    end

    def mock_enabled?
      Settings.dmc.mock_fsr
    end
  end
end
