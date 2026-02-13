# frozen_string_literal: true

module V2
  module Chip
    ##
    # A class to provide functionality related to CHIP service. This class needs to be instantiated
    # with a {CheckIn::V2::Session} object and check in parameters so that {Client} can be instantiated
    # appropriately.
    #
    # @!attribute [r] check_in
    #   @return [CheckIn::V2::Session]
    # @!attribute [r] response
    #   @return [V2::Chip::Response]
    # @!attribute [r] check_in_body
    #   @return [Hash]
    # @!attribute [r] chip_client
    #   @return [Client]
    # @!attribute [r] redis_client
    #   @return [RedisClient]
    # @!method client_error
    #   @return (see CheckIn::V2::Session#client_error)
    # @!method uuid
    #   @return (see CheckIn::V2::Session#uuid)
    # @!method valid?
    #   @return (see CheckIn::V2::Session#valid?)
    class Service
      extend Forwardable
      attr_reader :check_in, :response, :check_in_body, :chip_client, :redis_client

      def_delegators :check_in, :client_error, :uuid, :valid?

      ##
      # Builds a Service instance
      #
      # @param opts [Hash] options to create the object
      # @option opts [CheckIn::V2::Session] :check_in the session object
      # @option opts [Hash] :check_in_body check in request parameters
      #
      # @return [Service] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts = {})
        @check_in = opts[:check_in]
        @check_in_body = opts[:params]
        @response = Response

        @chip_client = Client.build(check_in_session: check_in)
        @redis_client = RedisClient.build
      end

      # Call the CHIP API to confirm that an appointment has been checked in. A CHIP token is required
      # and if it is either not present in Redis or cannot be retrieved from CHIP, an unauthorized
      # message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Hash] success message if successful
      # @return [Hash] unauthorized message if token is not present
      def create_check_in
        resp = if token.present?
                 chip_client.check_in_appointment(token:, appointment_ien: check_in_body[:appointment_ien],
                                                  travel_params:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end

        response.build(response: resp).handle
      end

      # Call the CHIP API to refresh appointments. CHIP doesn't return refreshed appointments in the response
      # to this call, but rather updates LoROTA data as a result of this call. Code that uses this method
      # to refresh appointments should make use of {Lorota::Client#data} to retrieve refreshed data.
      #
      # @return [Faraday::Response] success message if successful
      # @return [Faraday::Response] unauthorized message if token is not present
      def refresh_appointments
        if token.present?
          chip_client.refresh_appointments(token:, identifier_params:)
        else
          Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
        end
      end

      # Call the CHIP API to confirm pre-checkin status. A CHIP token is required
      # and if it is either not present in Redis or cannot be retrieved from CHIP, an unauthorized
      # message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Hash] success message if successful
      # @return [Hash] unauthorized message if token is not present
      def pre_check_in
        log_pre_check_in_confirmation if token.present? && Flipper.enabled?(:check_in_experience_detailed_logging)
        resp = if token.present?
                 chip_client.pre_check_in(token:, demographic_confirmations:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end

        response.build(response: resp).handle
      end

      # Call the CHIP API to set pre check-in started status. This status is set to indicate
      # that the pre check-in process was started.
      #
      # A CHIP token is required and if it is either not present in Redis or cannot
      # be retrieved from CHIP, an unauthorized message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Faraday::Response] response from CHIP
      # @return [Faraday::Response] unauthorized message if token is not present
      def set_precheckin_started
        if token.present?
          chip_client.set_precheckin_started(token:)
        else
          Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
        end
      end

      # Call the CHIP API to set echeck-in started status. This status is set to indicate
      # that the check-in process was started.
      #
      # A CHIP token is required and if it is either not present in Redis or cannot
      # be retrieved from CHIP, an unauthorized message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Faraday::Response] response from CHIP
      # @return [Faraday::Response] unauthorized message if token is not present
      def set_echeckin_started
        resp = if token.present?
                 chip_client.set_echeckin_started(token:, appointment_attributes:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end

        response.build(response: resp).handle
      end

      # Call the CHIP API to confirm demographics. A CHIP token is required
      # and if it is either not present in Redis or cannot be retrieved from CHIP, an unauthorized
      # message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Hash] success message if successful
      # @return [Hash] unauthorized message if token is not present
      # @return [Hash] invalid request message if demographic_confirmations is not present
      def confirm_demographics
        log_demographic_confirmation if token.present? && Flipper.enabled?(:check_in_experience_detailed_logging)
        resp = if check_in_body.nil?
                 Faraday::Response.new(response_body: check_in.invalid_request.to_json, status: 400)
               elsif token.present?
                 chip_client.confirm_demographics(token:, demographic_confirmations:
                   demographic_confirmations.merge(identifier_params, { uuid: check_in.uuid }))
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end

        response.build(response: resp).handle
      end

      # Call the CHIP API to refresh pre check-in data.
      #
      # A CHIP token is required and if it is either not present in Redis or cannot
      # be retrieved from CHIP, an unauthorized message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Faraday::Response] response from CHIP
      # @return [Faraday::Response] unauthorized message if token is not present
      def refresh_precheckin
        resp = if token.present?
                 chip_client.refresh_precheckin(token:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end
        response.build(response: resp).handle
      end

      # Call the CHIP API to prepare pre check-in data for day-of check-in.
      #
      # A CHIP token is required and if it is either not present in Redis or cannot
      # be retrieved from CHIP, an unauthorized message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      #
      # @return [Faraday::Response] response from CHIP
      # @return [Faraday::Response] unauthorized message if token is not present
      def initiate_check_in
        resp = if token.present?
                 chip_client.initiate_check_in(token:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end
        response.build(response: resp).handle
      end

      # Call the CHIP API to delete check-in/pre check-in data.
      #
      # A CHIP token is required and if it is either not present in Redis or cannot
      # be retrieved from CHIP, an unauthorized message is returned.
      #
      # @see https://github.com/department-of-veterans-affairs/chip CHIP API details
      #
      # @return [Faraday::Response] response from CHIP
      # @return [Faraday::Response] unauthorized message if token is not present
      def delete
        resp = if token.present?
                 chip_client.delete(token:)
               else
                 Faraday::Response.new(response_body: check_in.unauthorized_message.to_json, status: 401)
               end
        response.build(response: resp).handle
      end

      # Get the CHIP token. If the token does not already exist in Redis, a call is made to CHIP token
      # endpoint to retrieve it.
      #
      # @see Chip::Client#token
      #
      # @return [String] token
      def token
        @token ||= fetch_token
      end

      def identifier_params
        hashed_identifiers =
          Oj.load(appointment_identifiers).with_indifferent_access.dig(:data, :attributes)

        {
          patientDfn: hashed_identifiers[:patientDFN],
          stationNo: hashed_identifiers[:stationNo].to_s
        }
      end

      def travel_params
        {
          isTravelEnabled: check_in_body[:is_travel_enabled],
          travelSubmitted: check_in_body[:travel_submitted]
        }
      end

      def demographic_confirmations
        confirmed_at = Time.zone.now.iso8601

        hsh = {}

        unless check_in_body[:demographics_up_to_date].nil?
          hsh[:demographicsNeedsUpdate] = check_in_body[:demographics_up_to_date] ? false : true
          hsh[:demographicsConfirmedAt] = confirmed_at
        end

        unless check_in_body[:next_of_kin_up_to_date].nil?
          hsh[:nextOfKinNeedsUpdate] = check_in_body[:next_of_kin_up_to_date] ? false : true
          hsh[:nextOfKinConfirmedAt] = confirmed_at
        end

        unless check_in_body[:emergency_contact_up_to_date].nil?
          hsh[:emergencyContactNeedsUpdate] = check_in_body[:emergency_contact_up_to_date] ? false : true
          hsh[:emergencyContactConfirmedAt] = confirmed_at
        end

        {
          demographicConfirmations: hsh
        }
      end

      def appointment_attributes
        hashed_identifiers =
          Oj.load(appointment_identifiers).with_indifferent_access.dig(:data, :attributes)

        {
          stationNo: hashed_identifiers[:stationNo].to_s,
          appointmentIen: hashed_identifiers[:appointmentIEN].to_s
        }
      end

      def appointment_identifiers
        Rails.cache.read(
          "check_in_lorota_v2_appointment_identifiers_#{check_in.uuid}",
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      private

      def fetch_token
        token = redis_client.get
        return token if token.present?

        resp = chip_client.token
        jwt_token = Oj.load(resp.body)&.fetch('token')
        redis_client.save(token: jwt_token)
        jwt_token
      end

      def log_pre_check_in_confirmation
        confirmations = demographic_confirmations[:demographicConfirmations] || {}

        Rails.logger.info({
                            message: 'Pre-check-in confirmation sent to CHIP',
                            check_in_uuid: check_in.uuid,
                            confirmation_flags_count: confirmations.size,
                            demographics_needs_update: confirmations[:demographicsNeedsUpdate],
                            next_of_kin_needs_update: confirmations[:nextOfKinNeedsUpdate],
                            emergency_contact_needs_update: confirmations[:emergencyContactNeedsUpdate]
                          })
      end

      def log_demographic_confirmation
        return if check_in_body.blank?

        Rails.logger.info({
                            message: 'Demographics confirmation',
                            check_in_uuid: check_in.uuid,
                            demographics_up_to_date: check_in_body[:demographics_up_to_date],
                            next_of_kin_up_to_date: check_in_body[:next_of_kin_up_to_date],
                            emergency_contact_up_to_date: check_in_body[:emergency_contact_up_to_date]
                          })
      end
    end
  end
end
