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

      def create
        communication_item = build_communication_item
        raise Common::Exceptions::ValidationErrors, communication_item unless communication_item.valid?

        render(json: service.update_communication_permission(communication_item))
      end

      def update
        communication_item = build_communication_item
        raise Common::Exceptions::ValidationErrors, communication_item unless communication_item.valid?

        communication_item.first_communication_channel.communication_permission.id = params[:id]

        render(json: service.update_communication_permission(communication_item))
      end

      private

      def service
        VAProfile::Communication::Service.new(current_user)
      end

      def build_communication_item
        VAProfile::Models::CommunicationItem.new(
          params.require(:communication_item).permit(
            :id,
            communication_channels: [
              :id,
              { communication_permission: :allowed }
            ]
          )
        )
      end
    end
  end
end
