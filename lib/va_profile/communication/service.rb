# frozen_string_literal: true

require 'va_profile/communication/configuration'
require 'va_profile/models/communication_item_group'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      OID = '2.16.840.1.113883.4.349'
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'

      configuration VAProfile::Communication::Configuration

      def update_communication_permission(communication_item)
        perform_with_monitoring(
          communication_item.http_verb,
          "#{get_path_ids}communication-permissions", communication_item.in_json(@user.vet360_id)
        )
      end

      def get_items_and_permissions
        VAProfile::Models::CommunicationItemGroup.create_groups(
          get_communication_items,
          get_communication_permissions
        )
      end

      def get_communication_permissions
        perform_with_monitoring(:get, "#{get_path_ids}communication-permissions")
      end

      def get_communication_items
        perform_with_monitoring(:get, 'communication-items')
      end

      private

      def perform_with_monitoring(*args)
        with_monitoring do
          perform(*args).body
        end
      rescue => e
        handle_error(e)
      end

      def get_path_ids
        id_with_aaid = ERB::Util.url_encode("#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}")

        "#{OID}/#{id_with_aaid}/"
      end
    end
  end
end
