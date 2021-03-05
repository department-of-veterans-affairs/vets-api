# frozen_string_literal: true

require 'va_profile/communication/configuration'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      configuration VAProfile::Communication::Configuration
    end
  end
end
