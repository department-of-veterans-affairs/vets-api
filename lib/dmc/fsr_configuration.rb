# frozen_string_literal: true

module DMC
  class FSRConfiguration < DMC::Configuration
    def service_name
      'FSR'
    end

    def base_path
      "#{Settings.dmc.url}/financial-status-report/formtopdf"
    end
  end
end
