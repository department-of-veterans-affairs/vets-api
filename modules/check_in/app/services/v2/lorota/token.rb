# frozen_string_literal: true

module V2
  module Lorota
    class Token
      extend Forwardable

      attr_reader :request, :claims_token, :check_in, :settings
      attr_accessor :access_token

      def_delegators :settings, :base_path

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @check_in = opts[:check_in]
        @claims_token = ClaimsToken.build(check_in: check_in).sign_assertion
        @request = Request.build(claims_token: claims_token)
      end

      def fetch
        resp = request.post("/#{base_path}/token", {})

        self.access_token = Oj.load(resp.body)&.fetch('token')
        self
      end
    end
  end
end
