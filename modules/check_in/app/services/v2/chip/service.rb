# frozen_string_literal: true

module V2
  module Chip
    class Service
      extend Forwardable

      attr_reader :check_in, :request, :response, :session, :settings, :check_in_body, :chip_client, :redis_client

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

        @chip_client = Client.build(check_in_session: check_in)
        @redis_client = RedisClient.build
      end

      def create_check_in
        resp = if Flipper.enabled?('check_in_experience_chip_service_refactor')
                 if token.present?
                   chip_client.check_in_appointment(token: token, appointment_ien: check_in_body[:appointment_ien])
                 else
                   Faraday::Response.new(body: check_in.unauthorized_message.to_json, status: 401)
                 end
               else
                 token = session.retrieve
                 if token.present?
                   request.post(
                     path: "/#{base_path}/actions/check-in/#{uuid}",
                     access_token: token,
                     params: { appointmentIEN: check_in_body[:appointment_ien] }
                   )
                 else
                   Faraday::Response.new(body: check_in.unauthorized_message.to_json, status: 401)
                 end
               end

        response.build(response: resp).handle
      end

      def refresh_appointments
        if Flipper.enabled?('check_in_experience_chip_service_refactor')
          if token.present?
            chip_client.refresh_appointments(token: token, identifier_params: identifier_params)
          else
            Faraday::Response.new(body: check_in.unauthorized_message.to_json, status: 401)
          end
        else
          token = session.retrieve
          request.post(
            path: "/#{base_path}/actions/refresh-appointments/#{uuid}",
            access_token: token,
            params: identifier_params
          )
        end
      end

      def token
        @token ||= begin
          token = redis_client.get

          return token if token.present?

          resp = chip_client.token

          Oj.load(resp.body)&.fetch('token').tap do |jwt_token|
            redis_client.save(token: jwt_token)
          end
        end
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
          "check_in_lorota_v2_appointment_identifiers_#{check_in.uuid}",
          namespace: 'check-in-lorota-v2-cache'
        )
      end
    end
  end
end
