# frozen_string_literal: true

require 'logging/monitor'

module DigitalFormsApi
  # Monitor for Digital Forms API
  class Monitor < Logging::Monitor
    # metric prefix
    STATSD_KEY_PREFIX = 'api.digital_forms_api'

    def initialize
      super('digital_forms_api')
    end
  end
end
