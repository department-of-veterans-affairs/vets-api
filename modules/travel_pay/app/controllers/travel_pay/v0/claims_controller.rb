# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      include AppointmentHelper
      include ClaimHelper

      def version_map
        should_upgrade = Flipper.enabled?(:travel_pay_claims_api_v3_upgrade)
        {
          get_claims: should_upgrade ? 'v3' : 'v2',
          get_claim_by_id: should_upgrade ? 'v3' : 'v2',
          get_claims_by_date: should_upgrade ? 'v3' : 'v2',
          create_claim: should_upgrade ? 'v3' : 'v2',
          submit_claim: should_upgrade ? 'v3' : 'v2',
          get_document_ids: should_upgrade ? 'v3' : 'v2'
        }
      end

      after_action :scrub_logs, only: [:show]

      def index
        claims = claims_service.get_claims_by_date_range(params)
        render json: claims, status: claims[:metadata]['status']
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

          appt_id = find_or_create_appt_id!('SMOC', params)
          claim_id = create_claim(appt_id, 'SMOC')
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
