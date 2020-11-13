# frozen_string_literal: true

require 'dmc/base_configuration'

module DMC
  class FSRConfiguration < DMC::BaseConfiguration
    def service_name
      'FSR'
    end
  end
end
