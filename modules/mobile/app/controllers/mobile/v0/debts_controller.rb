# frozen_string_literal: true

require 'debt_management_center/debts_service'

module Mobile
  module V0
    class DebtsController < ApplicationController
      before_action { authorize :debt, :access? }
      before_action :validate_feature_flag

      def index
        count_only = ActiveModel::Type::Boolean.new.cast(params[:countOnly])
        response = service.get_debts(count_only:)

        if count_only
          render json: response
        else
          render json: Mobile::V0::DebtsSerializer.new(response[:debts], @current_user.uuid)
        end
      end

      def show
        response = service.get_debt_by_id(params[:id])

        render json: Mobile::V0::DebtsSerializer.new(response)
      end

      private

      def validate_feature_flag
        return if Flipper.enabled?(:mobile_debts_enabled, @current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
      end

      def service
        @service ||= DebtManagementCenter::DebtsService.new(@current_user)
      end
    end
  end
end
