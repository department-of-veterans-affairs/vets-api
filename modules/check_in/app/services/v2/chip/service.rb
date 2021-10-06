# frozen_string_literal: true

module V2
  module Chip
    class Service
      extend Forwardable

      attr_reader :check_in, :request, :response, :session, :settings, :check_in_body

      def_delegators :check_in, :client_error, :uuid, :valid?
      def_delegators :settings, :base_path

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts = {})
        @settings = Settings.check_in.chip_api_v2
        @check_in = opts[:check_in]
        @check_in_body = opts[:params]
        @request = Request.build
        @response = Response
        @session = Session.build
      end

      def create_check_in
        token = session.retrieve
        resp =
          if token.present?
            request.post(
              path: "/#{base_path}/actions/check-in/#{uuid}",
              access_token: token,
              params: { appointmentIEN: check_in_body[:appointment_ien] }
            )

          else
            Faraday::Response.new(body: check_in.unauthorized_message.to_json, status: 401)
          end

        response.build(response: resp).handle
      end

      def refresh_appointments
        token = session.retrieve

        request.post(
          path: "/#{base_path}/actions/refresh-appointments/#{uuid}",
          access_token: token,
          params: identifier_params
        )
      end

      def identifier_params
        hashed_identifiers =
          Oj.load(appointment_identifiers).with_indifferent_access.dig(:data, :attributes)

        {
          patientDFN: hashed_identifiers[:patientDFN],
          stationNo: hashed_identifiers[:stationNo]
        }
      end

      def appointment_identifiers
        Rails.cache.read(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          namespace: 'check-in-lorota-v2-cache'
        )
      end
    end
  end
end
