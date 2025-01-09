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
        appt_not_found_msg = "No appointment found for #{params['appointmentDatetime']}"

        unless Flipper.enabled?(:travel_pay_submit_mileage_expense, @current_user)
          message = 'Travel Pay mileage expense submission unavailable per feature toggle'
          Rails.logger.error(message:)
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          Rails.logger.info(message: 'SMOC transaction START')

          Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{params['appointmentDatetime']}")
          appt = appts_service.get_appointment_by_date_time({ 'appt_datetime' => params['appointmentDatetime'] })

          if appt[:data].nil?
            Rails.logger.error(message: appt_not_found_msg)
            raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
          end

          Rails.logger.info(message: 'SMOC transaction: Create claim')
          claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt[:data]['id'] })

          claim_id = claim['claimId']

          Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => params['appointmentDatetime'] })

          Rails.logger.info(message: "SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
          submitted_claim = claims_service.submit_claim(claim_id)

          Rails.logger.info(message: 'SMOC transaction END')
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise Common::Exceptions::InternalServerError, exception: e
        end

        render json: submitted_claim, status: :created
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager)
      end

      def appts_service
        @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
      end

      def expense_service
        @expense_service ||= TravelPay::ExpensesService.new(auth_manager)
      end
    end
  end
end
