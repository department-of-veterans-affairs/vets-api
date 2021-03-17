# frozen_string_literal: true

require 'va_profile/communication/configuration'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      configuration VAProfile::Communication::Configuration

      def communication_items
        VAProfile::Models::CommunicationItemGroup.create_groups(perform(:get, 'communication-items').body)
      end
    end
  end
end
