# frozen_string_literal: true

module V1
  module Chip
    class Token
      extend Forwardable

      attr_reader :request, :claims_token, :settings
      attr_accessor :access_token

      def_delegators :settings, :base_path

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v1
        @request = Request.build
        @claims_token = ClaimsToken.build
      end

      def fetch
        response = request.post(path: "/#{base_path}/token", claims_token: claims_token.static)

        self.access_token = Oj.load(response.body)['token']
        self
      end

      def ttl_duration
        900
      end

      def created_at
        @created_at ||= Time.zone.now.utc.to_i
      end
    end
  end
end
