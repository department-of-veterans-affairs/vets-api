# frozen_string_literal: true

module V0
  class VeteranStatusCardsController < ApplicationController
    service_tag 'veteran-status-card'

    def show
      render json: service.status_card
    rescue ArgumentError => e
      Rails.logger.error("VeteranStatusCardsController argument error: #{e.message}", backtrace: e.backtrace)
      render json: { error: 'An argument error occurred' }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("VeteranStatusCardsController unexpected error: #{e.message}", backtrace: e.backtrace)
      render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
    end

    private

    def service
      @service ||= ::VeteranStatusCard::Service.new(@current_user)
    end
  end
end
