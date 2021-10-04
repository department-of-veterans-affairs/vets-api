# frozen_string_literal: true

module V2
  module Lorota
    class Service
      extend Forwardable

      attr_reader :check_in, :session, :settings, :request

      def_delegators :check_in, :client_error
      def_delegators :settings, :base_path

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @check_in = opts[:check_in]
        @session = Session.build(check_in: check_in)
        @request = Request.build(token: session.from_redis)
      end

      def token_with_permissions
        jwt = session.from_lorota

        {
          permission_data: { permissions: 'read.full', uuid: check_in.uuid, status: 'success' },
          jwt: jwt
        }
      end

      def get_check_in_data
        token = session.from_redis
        raw_data = request.get("/#{base_path}/data/#{check_in.uuid}") if token.present?
        patient_check_in = CheckIn::V2::PatientCheckIn.build(data: raw_data, check_in: check_in)

        return patient_check_in.unauthorized_message if token.blank?
        return patient_check_in.error_message if patient_check_in.error_status?

        patient_check_in.save
        patient_check_in.approved
      end
    end
  end
end
