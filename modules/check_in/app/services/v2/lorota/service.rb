# frozen_string_literal: true

module V2
  module Lorota
    class Service
      extend Forwardable

      attr_reader :check_in, :chip_service, :lorota_client, :redis_client

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @check_in = opts[:check_in]
        @chip_service = V2::Chip::Service.build(check_in: check_in)
        @lorota_client = Client.build(check_in: check_in)
        @redis_client = RedisClient.build
      end

      def token
        resp = lorota_client.token
        jwt_token = Oj.load(resp.body)&.fetch('token')

        redis_client.save(check_in_uuid: check_in.uuid, token: jwt_token)

        {
          permission_data: { permissions: 'read.full', uuid: check_in.uuid, status: 'success' },
          jwt: jwt_token
        }
      end

      def check_in_data
        token = redis_client.get(check_in_uuid: check_in.uuid)

        raw_data =
          if token.present?
            chip_service.refresh_appointments if appointment_identifiers.present?

            lorota_client.data(token: token)
          end

        patient_check_in = CheckIn::V2::PatientCheckIn.build(data: raw_data, check_in: check_in)

        return patient_check_in.unauthorized_message if token.blank?
        return patient_check_in.error_message if patient_check_in.error_status?

        patient_check_in.save
        patient_check_in.approved
      end

      def appointment_identifiers
        Rails.cache.read(
          "check_in_lorota_v2_appointment_identifiers_#{check_in.uuid}",
          namespace: 'check-in-lorota-v2-cache'
        )
      end
    end
  end
end
