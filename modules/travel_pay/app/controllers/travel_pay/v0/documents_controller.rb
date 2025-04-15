# frozen_string_literal: true

module TravelPay
  module V0
    class DocumentsController < ApplicationController
      def show
        document = service.download_document(params[:claim_id], params[:id])

        send_data(document.body['data'], disposition: 'attachment', filename: params[:filename])
      rescue Faraday::Error => e
        Rails.logger.error("Error downloading document: #{e.message}. Tried mime_type: #{params[:mime_type]}")
        TravelPay::ServiceError.raise_mapped_error(e)
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def service
        @service ||= TravelPay::DocumentsService.new(auth_manager)
      end
    end
  end
end
