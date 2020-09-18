# frozen_string_literal: true

require 'debts/service'

module V0
  class DebtsController < ApplicationController
    def index
      render json: service.get_debts
    end

    private

    def service
      Debts::Service.new(@current_user)
    end
  end
end
