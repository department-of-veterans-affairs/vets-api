# frozen_string_literal: true

require 'debt_management_center/debts_service'

module Mobile
  module V0
    class DebtsController < ApplicationController
      before_action { authorize :debt, :access? }

      def index
        response = service.get_debts

        render json: Mobile::V0::DebtSerializer.new(@current_user.uuid, response)
      end

      private

      def service
        @service ||= DebtManagementCenter::DebtsService.new(@current_user)
      end
    end
  end
end
