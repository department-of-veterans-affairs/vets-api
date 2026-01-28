# frozen_string_literal: true

module Mobile
  module V0
    class VeteranStatusCardsController < ApplicationController
      def show
        render json: service.status_card
      rescue ArgumentError => e
        Rails.logger.error("Mobile::VeteranStatusCardsController argument error: #{e.message}",
                           backtrace: e.backtrace)
        render json: { error: 'An argument error occurred' }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error("Mobile::VeteranStatusCardsController unexpected error: #{e.message}",
                           backtrace: e.backtrace)
        render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
      end

      private

      def service
        @service ||= ::Mobile::V0::VeteranStatusCard::Service.new(@current_user)
      end
    end
  end
end
