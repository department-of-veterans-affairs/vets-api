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
        return response.build(response: client_error).handle unless valid?

        token = session.retrieve
        resp = request.post(path: "/#{base_path}/actions/check-in/#{uuid}", access_token: token, params: check_in_body)

        response.build(response: resp).handle
      end
    end
  end
end
