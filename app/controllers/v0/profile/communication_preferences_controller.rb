# frozen_string_literal: true

require 'va_profile/communication/service'

module V0
  module Profile
    class CommunicationPreferencesController < ApplicationController
      service_tag 'profile'
      before_action { authorize :vet360, :access? }
      before_action { authorize :communication_preferences, :access? }

      def index
        items_and_permissions = service.get_items_and_permissions
        render json: CommunicationGroupsSerializer.new({ communication_groups: items_and_permissions })
      end

      def create
        if communication_item.valid?
          log_request_complete('create')

          response = service.update_communication_permission(communication_item)

          render json: response
        else
          raise Common::Exceptions::ValidationErrors, communication_item
        end
      end

      def update
        if communication_item.valid?
          log_request_complete('update')

          communication_item.communication_channel.communication_permission.id = params[:id]
          response = service.update_communication_permission(communication_item)

          render json: response
        else
          raise Common::Exceptions::ValidationErrors, communication_item
        end
      end

      private

      def service
        VAProfile::Communication::Service.new(current_user)
      end

      def communication_item_params
        communication_channel = [:id, { communication_permission: %i[allowed sensitive] }]
        params.require(:communication_item).permit(:id, communication_channel:)
      end

      def communication_item
        @communication_item ||= VAProfile::Models::CommunicationItem.new(communication_item_params)
      end

      def log_request_complete(action)
        message = "CommunicationPreferencesController##{action} request completed"
        Rails.logger.info(message, sso_logging_info)
      end
    end
  end
end
