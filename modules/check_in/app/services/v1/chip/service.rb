# frozen_string_literal: true

module V1
  module Chip
    class Service
      extend Forwardable

      attr_reader :check_in, :request, :response, :session, :settings

      def_delegators :check_in, :client_error, :uuid, :valid?
      def_delegators :settings, :base_path

      def self.build(check_in)
        new(check_in)
      end

      def initialize(check_in)
        @settings = Settings.check_in.chip_api_v1
        @check_in = check_in
        @request = Request.build
        @response = Response
        @session = Session.build
      end

      def create_check_in
        return response.build(response: client_error).handle unless valid?

        token = session.retrieve
        resp = request.post(path: "/#{base_path}/actions/check-in/#{uuid}", access_token: token)

        response.build(response: resp).handle
      end
    end
  end
end
