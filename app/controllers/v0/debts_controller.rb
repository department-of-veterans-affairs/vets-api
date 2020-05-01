# frozen_string_literal: true

module V0
  class DebtsController < ApplicationController
    def index
      render json: {
        data: service.get_debt_letter_details
      }
    end

    private

    def service
      DMC::Service.new(@current_user)
    end
  end
end
