# frozen_string_literal: true

module V0
  class VeteranStatusCardsController < ApplicationController
    def show
      render json: service.status_card
    end

    private

    def service
      @service ||= VeteranStatusCard::Service.new(@current_user)
    end
  end
end
