# frozen_string_literal: true

require 'debt_management_center/debts_service'

module Mobile
  module V0
    class DebtsController < ApplicationController
      before_action { authorize :debt, :access? }

      def index
        response = service.get_debts

        render json: Mobile::V0::DebtsSerializer.new(response[:debts], @current_user.uuid)
      end

      def show
        response = service.get_debt_by_id(params[:id])

        render json: Mobile::V0::DebtsSerializer.new(response)
      end

      private

      def service
        @service ||= DebtManagementCenter::DebtsService.new(@current_user)
      end
    end
  end
end
