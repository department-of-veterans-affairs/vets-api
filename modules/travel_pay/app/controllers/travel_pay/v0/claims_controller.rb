# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      ### HEY
      #### KEVIN
      ##### REMOVE THIS!!!
      skip_before_action :verify_authenticity_token, only: [:create]
      ##### REMOVE THIS!!!
      #### KEVIN
      ### HEY


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
        
        begin
          appt = appts_service.get_appointment_by_date_time({'appt_datetime' => params['appointmentDatetime']})

          claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt[:data]['id'] })

          claim_id = claim['claimId']

          expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => params['appointmentDatetime'] })

          submitted_claim = claims_service.submit_claim(claim_id)
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          byebug
          raise Common::Exceptions::InternalServerError.new(e)
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
