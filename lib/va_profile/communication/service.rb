# frozen_string_literal: true

require 'va_profile/communication/configuration'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      configuration VAProfile::Communication::Configuration

      def communication_items
        perform(:get, 'communication-items')
      end
    end
  end
end
