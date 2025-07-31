# frozen_string_literal: true

require 'debt_management_center/debts_service'

module V0
  class DebtsController < ApplicationController
    service_tag 'debt-resolution'
    before_action { authorize :debt, :access? }

    rescue_from ::DebtManagementCenter::DebtsService::DebtNotFound, with: :render_not_found

    def index
      count_only = ActiveModel::Type::Boolean.new.cast(params[:count_only])
      render json: service.get_debts(count_only:)
    end

    def show
      render json: service.get_debt_by_id(params[:id])
    end

    private

    def service
      DebtManagementCenter::DebtsService.new(@current_user)
    end

    def render_not_found
      render json: nil, status: :not_found
    end
  end
end
