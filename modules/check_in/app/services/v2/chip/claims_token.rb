# frozen_string_literal: true

module V2
  module Chip
    class ClaimsToken
      extend Forwardable

      attr_reader :settings

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v2
      end

      def static
        @static ||= Base64.encode64("#{tmp_api_username}:#{tmp_api_user}")
      end

      def use_vaec_cie_endpoints?
        Flipper.enabled?('check_in_experience_use_vaec_cie_endpoints') || false
      end

      def tmp_api_id
        use_vaec_cie_endpoints? ? settings.tmp_api_id_v2 : settings.tmp_api_id
      end

      def tmp_api_username
        use_vaec_cie_endpoints? ? settings.tmp_api_username_v2 : settings.tmp_api_username
      end

      def tmp_api_user
        use_vaec_cie_endpoints? ? settings.tmp_api_user_v2 : settings.tmp_api_user
      end
    end
  end
end
