# frozen_string_literal: true

module V0
  class DebtsController < ApplicationController
    def index
      render json: service.get_debt_details(fileNumber: @current_user.ssn)
    end

    def show
      render json: service.get_letter_history()
    end

    private

    def service
      Debts::Service.new
    end
  end
end
