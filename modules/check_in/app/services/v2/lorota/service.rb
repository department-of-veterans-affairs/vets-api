# frozen_string_literal: true

module V2
  module Lorota
    ##
    # A service class to provide functionality related to LoROTA. This class needs to be instantiated
    # with a {CheckIn::V2::Session} object so that {Client} and {V2::Chip::Service} can be instantiated
    # appropriately.
    #
    # @!attribute [r] check_in
    #   @return [CheckIn::V2::Session]
    # @!attribute [r] chip_service
    #   @return [V2::Chip::Service]
    # @!attribute [r] lorota_client
    #   @return [Client]
    # @!attribute [r] redis_client
    #   @return [RedisClient]
    class Service
      extend Forwardable

      LOROTA_401_ERROR_MESSAGES = ['lastname does not match with current record',
                                   'ssn4 does not match with current record',
                                   'dob does not match with current record',
                                   'lastname or dob does not match with current record'].freeze

      LOROTA_UUID_NOT_FOUND = 'uuid not found'

      attr_reader :check_in, :chip_service, :lorota_client, :redis_client, :settings

      def_delegator :settings, :max_auth_retry_limit

      ##
      # Builds a Service instance
      #
      # @param opts [Hash] options to create the object
      # @option opts [CheckIn::V2::Session] :check_in the session object
      #
      # @return [Service] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.authentication
        @check_in = opts[:check_in]
        @chip_service = V2::Chip::Service.build(check_in:)
        @lorota_client = Client.build(check_in:)
        @redis_client = RedisClient.build
      end

      # Get the token from LoROTA by making a POST call. If the call is successful, the token is saved
      # in Redis as well for subsequent session retrieval.
      #
      # @see https://github.com/department-of-veterans-affairs/lorota#how-check-in-experience-uses-lorota How
      # Check In Experience uses LoROTA
      #
      # @return [Hash] a hash with permission data and the jwt token
      def token
        resp = lorota_client.token
        jwt_token = Oj.load(resp.body)&.fetch('token')

        redis_client.save(check_in_uuid: check_in.uuid, token: jwt_token)

        {
          permission_data: { permissions: 'read.full', uuid: check_in.uuid, status: 'success' },
          jwt: jwt_token
        }
      rescue Common::Exceptions::BackendServiceException => e
        if e.original_status == 401
          error_message_handler(e)
        else
          raise e
        end
      end

      # Get the check-in data from LoROTA. To get the data, the token (which is required for LoROTA auth)
      # is retrieved from Redis. If token is not present, an unauthorized message is returned. If the data
      # has been retrieved previously, it makes a call to CHIP to refresh the data in LoROTA first, and
      # then gets the updated data from LoROTA.
      #
      # @return [Hash] data from LoROTA if token exists and LoROTA returns successfully
      # @return [Hash] unauthorized message if token doesn't exist
      # @return [Hash] error message if LoROTA returns error
      def check_in_data
        token = redis_client.get(check_in_uuid: check_in.uuid)

        raw_data =
          if token.present?
            chip_service.refresh_appointments if refresh_appointments?

            lorota_client.data(token:)
          end

        patient_check_in = CheckIn::V2::PatientCheckIn.build(data: raw_data, check_in:)

        # Log data retrieval for debugging insurance/eligibility issues
        log_check_in_data_retrieval(patient_check_in, raw_data) if raw_data.present? && token.present?

        return patient_check_in.unauthorized_message if token.blank?
        return patient_check_in.error_message if patient_check_in.error_status?

        patient_check_in.save unless patient_check_in.check_in_type == 'preCheckIn'
        patient_check_in.approved
      end

      private

      def refresh_appointments?
        appointment_identifiers = Rails.cache.read(
          "check_in_lorota_v2_appointment_identifiers_#{check_in.uuid}",
          namespace: 'check-in-lorota-v2-cache'
        )
        appointment_identifiers.present? && !'oh'.casecmp?(check_in.facility_type)
      end

      def error_message_handler(e)
        case Oj.load(e.original_body).fetch('error').strip.downcase
        when *LOROTA_401_ERROR_MESSAGES
          retry_attempt_count = redis_client.retry_attempt_count(uuid: check_in.uuid) || 0
          if retry_attempt_count < max_auth_retry_limit.to_i
            redis_client.save_retry_attempt_count(uuid: check_in.uuid, retry_count: retry_attempt_count + 1)
            raise e
          else
            chip_service.delete
            raise CheckIn::V2::CheckinServiceException.new(status: '410', original_body: e.original_body)
          end
        when LOROTA_UUID_NOT_FOUND
          raise CheckIn::V2::CheckinServiceException.new(status: '404', original_body: e.original_body)
        else
          raise e
        end
      end

      def log_check_in_data_retrieval(patient_check_in, raw_data)
        return unless Flipper.enabled?(:check_in_experience_detailed_logging)
        return if patient_check_in.error_status?

        appointments, demographics_status = parse_check_in_response_data(raw_data)

        Rails.logger.info(build_check_in_log_data(appointments, demographics_status))
        track_appointment_eligibility(appointments)
      end

      def parse_check_in_response_data(raw_data)
        parsed_data = parse_json_with_error_handling(raw_data)
        extract_response_data(parsed_data)
      end

      def parse_json_with_error_handling(raw_data)
        Oj.load(raw_data.body)
      rescue Oj::ParseError => e
        log_parsing_error('JSON parsing failed', e)
        {}
      rescue EncodingError => e
        log_parsing_error('Encoding issue detected - possible data corruption', e)
        {}
      rescue => e
        log_parsing_error('Unexpected error parsing check-in response', e)
        {}
      end

      def log_parsing_error(message, error)
        log_method = message.include?('JSON') ? :warn : :error
        Rails.logger.send(log_method, {
                            message:,
                            check_in_uuid: check_in.uuid,
                            error: error.message
                          })
      end

      def extract_response_data(parsed_data)
        appointments = parsed_data.dig('payload', 'appointments') || []
        demographics_status = parsed_data.dig('payload', 'patientDemographicsStatus') || {}
        [appointments, demographics_status]
      end

      def build_check_in_log_data(appointments, demographics_status)
        {
          message: 'Check-in data retrieved',
          check_in_uuid: check_in.uuid,
          facility_type: check_in.facility_type,
          check_in_type: check_in.check_in_type || 'checkIn',
          appointment_count: appointments.size,
          demographics_needs_update: demographics_status['demographicsNeedsUpdate'],
          next_of_kin_needs_update: demographics_status['nextOfKinNeedsUpdate'],
          emergency_contact_needs_update: demographics_status['emergencyContactNeedsUpdate'],
          demographics_confirmed_at: demographics_status['demographicsConfirmedAt'],
          eligibility_values: appointments.map { |a| a['eligibility'] }.compact.uniq
        }
      end

      def track_appointment_eligibility(appointments)
        appointments.each do |appt|
          eligibility = appt['eligibility']&.downcase || 'unknown'
          StatsD.increment(
            CheckIn::Constants::STATSD_CHECKIN_ELIGIBILITY,
            tags: ['service:check_in', "eligibility:#{eligibility}", "facility_type:#{check_in.facility_type}"]
          )
        end
      end
    end
  end
end
