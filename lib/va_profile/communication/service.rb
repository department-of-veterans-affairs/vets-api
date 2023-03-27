# frozen_string_literal: true

require_relative 'configuration'
require 'va_profile/models/communication_item_group'

module VAProfile
  module Communication
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.communication".freeze
      OID = '2.16.840.1.113883.4.349'
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'

      configuration VAProfile::Communication::Configuration

      def update_communication_permission(communication_item)
        with_monitoring do
          perform(
            communication_item.http_verb,
            "#{get_path_ids}communication-permissions", communication_item.in_json(@user.vet360_id)
          ).body
        end
      rescue => e
        handle_error(e)
      end

      def get_items_and_permissions
        VAProfile::Models::CommunicationItemGroup.create_groups(
          get_communication_items,
          get_communication_permissions
        )
      end

      def get_communication_permissions
        with_monitoring do
          perform(:get, "#{get_path_ids}communication-permissions").body
        end
      rescue => e
        handle_error(e)
      end

      def get_communication_items
        with_monitoring do
          perform(:get, 'communication-items').body
        end
      rescue => e
        handle_error(e)
      end

      private

      def get_path_ids
        id_with_aaid = ERB::Util.url_encode("#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}")

        "#{OID}/#{id_with_aaid}/"
      end
    end
  end
end
