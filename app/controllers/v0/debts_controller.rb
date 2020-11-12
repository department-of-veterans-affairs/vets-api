# frozen_string_literal: true

require 'dmc/debts_service'

module V0
  class DebtsController < ApplicationController
    def index
      render json: service.get_debts
    end

    private

    def service
      DMC::DebtsService.new(@current_user)
    end
  end
end
