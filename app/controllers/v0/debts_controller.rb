# frozen_string_literal: true

module V0
  class DebtsController < ApplicationController
    def index
      render json: {
        data: service.get_letters(fileNumber: @current_user.ssn).to_json
      }
    end

    private

    def service
      Debts::Service.new
    end
  end
end
