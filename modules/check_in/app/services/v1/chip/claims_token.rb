# frozen_string_literal: true

module V1
  module Chip
    class ClaimsToken
      extend Forwardable

      attr_reader :settings

      def_delegators :settings, :tmp_api_id, :tmp_api_username, :tmp_api_user

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v1
      end

      def static
        @static ||= Base64.encode64("#{tmp_api_username}:#{tmp_api_user}")
      end
    end
  end
end
