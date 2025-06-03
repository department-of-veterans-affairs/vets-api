# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      after_action :scrub_logs, only: [:show]

      def index
        claims = claims_service.get_claims(params)
        render json: claims, status: :ok
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e.message, e.response[:request][:headers]['X-Correlation-ID'])
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      end

      def show
        unless Flipper.enabled?(:travel_pay_view_claim_details, @current_user)
          message = 'Travel Pay Claim Details unavailable per feature toggle'
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          claim = claims_service.get_claim_details(params[:id])
        rescue Faraday::ResourceNotFound => e
          handle_resource_not_found_error(e.message, e.response[:request][:headers]['X-Correlation-ID'])
          return
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, message: e.message
        end

        if claim.nil?
          handle_resource_not_found_error("Claim not found. ID provided: #{params[:id]}",
                                          e.response[:request][:headers]['X-Correlation-ID'])
          return
        end

        render json: claim, status: :ok
      end

      def create
        unless Flipper.enabled?(:travel_pay_submit_mileage_expense, @current_user)
          message = 'Travel Pay mileage expense submission unavailable per feature toggle'
          Rails.logger.error(message:)
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          Rails.logger.info(message: 'SMOC transaction START')

          appt_id = get_appt_or_raise(params)
          claim_id = get_claim_id(appt_id)

          Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => params['appointment_date_time'] })

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
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager, @current_user)
      end

      def appts_service
        @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
      end

      def expense_service
        @expense_service ||= TravelPay::ExpensesService.new(auth_manager)
      end

      def scrub_logs
        logger.filter = lambda do |log|
          if log.name =~ /TravelPay/
            # Safely scrub :params
            log.payload[:params]['id'] = 'SCRUBBED_CLAIM_ID' if log.payload[:params].is_a?(Hash)

            # Safely scrub :path
            if log.payload[:path].is_a?(String)
              log.payload[:path] = log.payload[:path].gsub(%r{(.+claims/)(.+)}, '\1SCRUBBED_CLAIM_ID')
            end

            # Safely scrub :referer if present
            if log.named_tags&.key?(:referer) && log.named_tags[:referer].is_a?(String)
              log.named_tags[:referer] = log.named_tags[:referer].gsub(%r{(.+claims/)(.+)(.+)}, '\1SCRUBBED_CLAIM_ID')
            end
          end

          true
        end
      end

      def get_appt_or_raise(params = {})
        appt_not_found_msg = "No appointment found for #{params['appointment_date_time']}"
        Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{params['appointment_date_time']}")
        appt = appts_service.find_or_create_appointment(params)

        if appt[:data].nil?
          Rails.logger.error(message: appt_not_found_msg)
          raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
        end

        appt[:data]['id']
      end

      def get_claim_id(appt_id)
        Rails.logger.info(message: 'SMOC transaction: Create claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end

      def handle_resource_not_found_error(message, cid)
        Rails.logger.error("Resource not found: #{message}")
        render(
          json: {
            error: 'Not found',
            correlation_id: cid
          },
          status: :not_found
        )
      end
    end
  end
end
