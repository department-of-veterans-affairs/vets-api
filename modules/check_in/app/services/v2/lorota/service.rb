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
    end
  end
end
