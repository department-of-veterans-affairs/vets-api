# frozen_string_literal: true

require 'va_profile/communication/configuration'
require 'va_profile/models/communication_item_group'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      OID = '2.16.840.1.113883.4.349'
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'

      configuration VAProfile::Communication::Configuration

      # TODO add monitoring
      def update_communication_permission(communication_item)
        communication_item.va_profile_id = @user.vet360_id

        perform(
          communication_item.http_verb,
          "#{get_path_ids}communication-permissions", communication_item.in_json
        ).body
      end

      def get_items_and_permissions
        VAProfile::Models::CommunicationItemGroup.create_groups(
          communication_items,
          get_communication_permissions
        )
      end

      def get_communication_permissions
        perform(:get, "#{get_path_ids}communication-permissions").body
      end

      def communication_items
        perform(:get, 'communication-items').body
      end

      private

      def get_path_ids
        id_with_aaid = ERB::Util.url_encode("#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}")

        "#{OID}/#{id_with_aaid}/"
      end
    end
  end
end
