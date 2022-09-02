# frozen_string_literal: true

module VAOS
  class PPMSConfiguration < VAOS::Configuration
    def base_path
      Settings.va_mobile.ppms_base_url
    end
  end
end
