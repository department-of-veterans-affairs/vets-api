# frozen_string_literal: true

require 'va_profile/communication/configuration'
require 'va_profile/models/communication_item_group'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      OID = '2.16.840.1.113883.4.349'
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'

      configuration VAProfile::Communication::Configuration

      def update_communication_permission(communication_item)
        perform(:post, "#{get_path_ids}communication-permissions", communication_item.in_json)
      end

      def communication_items
        VAProfile::Models::CommunicationItemGroup.create_groups(perform(:get, 'communication-items').body)
      end

      private

      def get_path_ids
        id_with_aaid = ERB::Util.url_encode("#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}")

        "#{OID}/#{id_with_aaid}/"
      end
    end
  end
end
