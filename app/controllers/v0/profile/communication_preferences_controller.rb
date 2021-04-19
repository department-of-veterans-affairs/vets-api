# frozen_string_literal: true

require 'va_profile/communication/service'

module V0
  module Profile
    class CommunicationPreferencesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def index
        render(
          json: { communication_groups: service.get_items_and_permissions },
          serializer: CommunicationGroupsSerializer
        )
      end

      def update_all
        communication_items = params.require(:communication_items).map do |communication_item_params|
          communication_item = build_communication_item(communication_item_params)
          raise Common::Exceptions::ValidationErrors, communication_item unless communication_item.valid?

          communication_item
        end

        render(json: service.update_all_communication_permissions(communication_items))
      end

      private

      def service
        VAProfile::Communication::Service.new(current_user)
      end

      def build_communication_item(communication_item_params)
        VAProfile::Models::CommunicationItem.new(
          communication_item_params.permit(
            :id,
            communication_channels: [
              :id,
              { communication_permission: [:allowed, :id] }
            ]
          )
        )
      end
    end
  end
end
