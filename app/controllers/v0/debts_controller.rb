# frozen_string_literal: true

module V0
  class DebtsController < ApplicationController
    def index
      render json: service.get_letters(fileNumber: @current_user.ssn)
    end

    private

    def service
      Debts::Service.new
    end
  end
end
