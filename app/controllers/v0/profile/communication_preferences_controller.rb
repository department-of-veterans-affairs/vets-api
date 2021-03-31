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
        communication_item = VAProfile::Models::CommunicationItem.new(
          allowed_params
        )

        render(json: service.update_communication_permission(communication_item))
      end

      def service
        VAProfile::Communication::Service.new(current_user)
      end

      private

      def allowed_params
        params.require(:communication_item).permit(
          :id,
          communication_channels: [
            :id,
            communication_permission: [
              :allowed,
              :id
            ]
          ]
        )
      end
    end
  end
end
