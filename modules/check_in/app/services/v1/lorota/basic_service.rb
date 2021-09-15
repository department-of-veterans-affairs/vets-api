# frozen_string_literal: true

module V1
  module Lorota
    class BasicService
      extend Forwardable

      attr_reader :check_in, :response, :session, :settings, :request

      def_delegators :check_in, :client_error, :valid?
      def_delegators :settings, :base_path

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v1
        @check_in = opts[:check_in]
        @session = BasicSession.build(check_in: check_in)
        @request = Request.build(token: session.from_redis)
        @response = Response
      end

      def get_or_create_token
        data = session.from_redis || session.from_lorota

        format_data(data)
      end

      def get_check_in
        token = session.from_redis

        if token.present?
          data = request.get("/#{base_path}/data/#{check_in.uuid}")

          Oj.load(data.body)
        end
      end

      def format_data(data)
        body = { permissions: permissions, uuid: check_in.uuid, status: 'success', jwt: data }

        response.build(response: Faraday::Response.new(body: body, status: 200)).handle
      end

      def permissions
        'read.basic'
      end
    end
  end
end
