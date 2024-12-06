# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      def index
        begin
          claims = claims_service.get_claims(params)
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        render json: claims, status: :ok
      end

      def show
        unless Flipper.enabled?(:travel_pay_view_claim_details, @current_user)
          message = 'Travel Pay Claim Details unavailable per feature toggle'
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          claim = claims_service.get_claim_by_id(params[:id])
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, message: e.message
        end

        if claim.nil?
          raise Common::Exceptions::ResourceNotFound, message: "Claim not found. ID provided: #{params[:id]}"
        end

        render json: claim, status: :ok
      end

      def create
        unless Flipper.enabled?(:travel_pay_submit_mileage_expense, @current_user)
          message = 'Travel Pay mileage expense submission unavailable per feature toggle'
          raise Common::Exceptions::ServiceUnavailable, message:
        end
        
        # tp api requests
        #  get appt
        #  make new claim
        #  attach expense
        #  submit claim
        render json: {}, status: :ok
      end

      private

      def claims_service
        auth_manager = TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager)
      end
    end
  end
end
