# frozen_string_literal: true

require 'debt_management_center/debts_service'

module V0
  class DebtsController < ApplicationController
    before_action { authorize :debt, :access? }

    def index
      render json: service.get_debts
    end

    private

    def service
      DebtManagementCenter::DebtsService.new(@current_user)
    end
  end
end
