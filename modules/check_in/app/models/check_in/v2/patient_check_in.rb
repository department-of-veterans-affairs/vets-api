# frozen_string_literal: true

module CheckIn
  module V2
    class PatientCheckIn
      extend Forwardable

      attr_reader :settings, :check_in, :data, :http_status, :http_body

      def_delegators :settings, :redis_session_prefix, :redis_token_expiry
      def_delegator :check_in, :check_in_type

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

      def save
        Rails.cache.write(
          build_session_id_prefix,
          appointment_identifiers_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: redis_token_expiry
        )
      end

      def approved
        appt_hash = Oj.load(http_body).merge(uuid: check_in.uuid).with_indifferent_access
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
    end
  end
end
