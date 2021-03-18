# frozen_string_literal: true

require_relative 'configuration'
require 'va_profile/models/communication_item_group'

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
