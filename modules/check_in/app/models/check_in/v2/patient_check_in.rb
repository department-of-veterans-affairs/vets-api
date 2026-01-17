# frozen_string_literal: true

module CheckIn
  module V2
    ##
    # A class responsible for Check-in related business logic. This class is instantiated with
    # {CheckIn::V2::Session} object and the raw response from LoROTA data, and provides
    # functionality to get the serialized data or return appropriate error response.
    #
    # @!attribute [r] settings
    #   @return [Config::Options]
    # @!attribute [r] check_in
    #   @return [Session] the session object
    # @!attribute [r] data
    #   @return [Faraday::Response] raw Response object
    # @!attribute [r] http_status
    #   @return [Integer] HTTP status of the raw response
    # @!attribute [r] http_body
    #   @return [String] HTTP body of the raw response
    # @!method redis_session_prefix
    #   @return (see Config::Options#redis_session_prefix)
    # @!method redis_token_expiry
    #   @return (see Config::Options#redis_token_expiry)
    # @!method check_in_type
    #   @return (see CheckIn::V2::Session#check_in_type)
    class PatientCheckIn
      extend Forwardable

      attr_reader :settings, :check_in, :data, :http_status, :http_body

      def_delegators :settings, :redis_session_prefix, :redis_token_expiry
      def_delegator :check_in, :check_in_type

      ##
      # Builds an instance of the class
      #
      # @param opts [Hash] options to create the object
      # @option opts [Session] :check_in the session object
      # @option opts [Faraday::Response] :data the check in data

      # @return [CheckIn::V2::PatientCheckIn] an instance of this class
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @check_in = opts[:check_in]
        @data = opts[:data]
        @http_status = data&.status
        @http_body = data&.body
      end

      # Save the appointment identifiers in Redis
      #
      # @return [Boolean]
      def save
        Rails.cache.write(
          build_session_id_prefix,
          appointment_identifiers_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: redis_token_expiry
        )
      end

      # Get the serialized patient data
      #
      # @return [Hash] payload with appointment, demographics and demographics status data
      def approved
        appt_hash = Oj.load(http_body).merge(uuid: check_in.uuid).with_indifferent_access
        log_response_structure(appt_hash) if Flipper.enabled?(:check_in_experience_detailed_logging)
        appt_struct = OpenStruct.new(appt_hash)
        appt_serializer = AppointmentDataSerializer.new(appt_struct)

        appt_serializer.serializable_hash.dig(:data, :attributes).merge(id: check_in.uuid)
      end

      def appointment_identifiers_json
        appt_hash = Oj.load(http_body).merge(uuid: check_in.uuid).with_indifferent_access
        appt_struct = OpenStruct.new(appt_hash)
        appt_serializer = AppointmentIdentifiersSerializer.new(appt_struct)

        Oj.dump(appt_serializer.serializable_hash)
      end

      def build_session_id_prefix
        "#{redis_session_prefix}_appointment_identifiers_#{check_in.uuid}"
      end

      def error_message
        { error: true, message: Oj.load(http_body), status: http_status }
      end

      def unauthorized_message
        { permissions: 'read.none', status: 'success', uuid: check_in.uuid }
      end

      def error_status?
        [401, 404, 403, 500, 501, 502, 503, 504].include?(http_status)
      end

      private

      def log_response_structure(data)
        # Log presence of key fields to identify missing insurance data
        payload = data[:payload] || {}
        demographics = payload[:demographics] || {}
        demographics_status = payload[:patientDemographicsStatus] || {}

        Rails.logger.info(build_response_log_data(payload, demographics, demographics_status))
        track_demographics_flags(demographics_status)
      end

      def build_response_log_data(payload, demographics, demographics_status)
        {
          message: 'Check-in response structure',
          check_in_uuid: check_in.uuid,
          has_appointments: payload[:appointments].present?,
          has_demographics: demographics.present?,
          has_demographics_status: demographics_status.present?,
          demographics_keys: demographics.keys.sort,
          demographics_status_keys: demographics_status.keys.sort,
          appointment_fields_sample: payload[:appointments]&.first&.keys&.sort || []
        }
      end

      def track_demographics_flags(demographics_status)
        return if demographics_status.blank?

        %w[demographicsNeedsUpdate nextOfKinNeedsUpdate emergencyContactNeedsUpdate].each do |flag|
          value = demographics_status[flag]
          next if value.nil?

          StatsD.increment(
            CheckIn::Constants::STATSD_CHECKIN_DEMOGRAPHICS_STATUS,
            tags: ['service:check_in', "flag:#{flag.underscore}", "needs_update:#{value}"]
          )
        end
      end
    end
  end
end
