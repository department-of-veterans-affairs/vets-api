# frozen_string_literal: true

module TravelPay
  module V1
    # Controller for handling Travel Pay claims in V1 of the API.
    # This version requires client identification via X-Client-GUID header.
    #
    # The controller provides endpoints for:
    # - Listing claims
    # - Viewing claim details
    # - Creating new claims with mileage expenses
    #
    # All requests must include the X-Client-GUID header to identify the client application.
    # The client GUID is used to look up the appropriate client number from the
    # Settings.travel_pay.clients hash.
    class ClaimsController < ApplicationController
      before_action :validate_client_guid
      after_action :scrub_logs, only: [:show]

      # Lists all claims for the current user
      #
      # @return [JSON] List of claims with status 200
      # @raise [Common::Exceptions::ServiceUnavailable] If the service is unavailable
      def index
        begin
          claims = claims_service.get_claims(params)
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        render json: claims, status: :ok
      end

      # Retrieves details for a specific claim
      #
      # @param id [String] The ID of the claim to retrieve
      # @return [JSON] Claim details with status 200
      # @raise [Common::Exceptions::ServiceUnavailable] If feature toggle is disabled
      # @raise [Common::Exceptions::BadRequest] If the request is invalid
      # @raise [Common::Exceptions::ResourceNotFound] If the claim is not found
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

      # Creates a new claim with mileage expense
      #
      # @param appointment_datetime [String] The datetime of the appointment
      # @return [JSON] Created claim with status 201
      # @raise [Common::Exceptions::ServiceUnavailable] If feature toggle is disabled
      # @raise [Common::Exceptions::BadRequest] If the request is invalid
      # @raise [Common::Exceptions::ResourceNotFound] If the appointment is not found
      # @raise [Common::Exceptions::InternalServerError] If there's a service error
      def create
        unless Flipper.enabled?(:travel_pay_submit_mileage_expense, @current_user)
          message = 'Travel Pay mileage expense submission unavailable per feature toggle'
          Rails.logger.error(message:)
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          Rails.logger.info(message: 'SMOC transaction START')

          appt_id = get_appt_or_raise(params['appointment_datetime'])
          claim_id = get_claim_id(appt_id)

          Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => params['appointment_datetime'] })

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

      # Validates the X-Client-GUID header and looks up the corresponding client number
      #
      # @raise [Common::Exceptions::BadRequest] If the header is missing or invalid
      def validate_client_guid
        client_guid = request.headers['X-Client-GUID']
        raise Common::Exceptions::BadRequest, message: 'X-Client-GUID header is required' if client_guid.nil?

        @client_number = TravelPay::ClientGuidHelper.get_client_number(client_guid)
      rescue TravelPay::ClientGuidHelper::ClientGuidNotFoundError => e
        raise Common::Exceptions::BadRequest, message: e.message
      end

      # Creates or returns an instance of AuthManager with the client number
      #
      # @return [TravelPay::AuthManager] The auth manager instance
      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(@client_number, @current_user)
      end

      # Creates or returns an instance of ClaimsService
      #
      # @return [TravelPay::ClaimsService] The claims service instance
      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager)
      end

      # Creates or returns an instance of AppointmentsService
      #
      # @return [TravelPay::AppointmentsService] The appointments service instance
      def appts_service
        @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
      end

      # Creates or returns an instance of ExpensesService
      #
      # @return [TravelPay::ExpensesService] The expenses service instance
      def expense_service
        @expense_service ||= TravelPay::ExpensesService.new(auth_manager)
      end

      # Filters sensitive information from logs
      #
      # Replaces claim IDs with a placeholder in logs for security
      def scrub_logs
        logger.filter = lambda do |log|
          if log.name =~ /TravelPay/
            log.payload[:params]['id'] = 'SCRUBBED_CLAIM_ID'
            log.payload[:path] = log.payload[:path].gsub(%r{(.+claims/)(.+)}, '\1SCRUBBED_CLAIM_ID')

            # Conditional because no referer if directly using the API
            if log.named_tags.key? :referer
              log.named_tags[:referer] = log.named_tags[:referer].gsub(%r{(.+claims/)(.+)(.+)}, '\1SCRUBBED_CLAIM_ID')
            end
          end
          # After the log has been scrubbed, make sure it is logged:
          true
        end
      end

      # Retrieves an appointment ID for the given datetime
      #
      # @param appt_datetime [String] The datetime of the appointment
      # @return [String] The appointment ID
      # @raise [Common::Exceptions::ResourceNotFound] If the appointment is not found
      def get_appt_or_raise(appt_datetime)
        appt_not_found_msg = "No appointment found for #{appt_datetime}"
        Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{appt_datetime}")
        appt = appts_service.get_appointment_by_date_time({ 'appt_datetime' => appt_datetime })

        if appt[:data].nil?
          Rails.logger.error(message: appt_not_found_msg)
          raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
        end

        appt[:data]['id']
      end

      # Creates a new claim for the given appointment ID
      #
      # @param appt_id [String] The appointment ID
      # @return [String] The claim ID
      def get_claim_id(appt_id)
        Rails.logger.info(message: 'SMOC transaction: Create claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end
    end
  end
end
