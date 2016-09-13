# frozen_string_literal: true
require 'common/models/base'
require 'common/models/attribute_types/utc_time'
module Common
  module Client
    # A generic session model - see how RX implements it
    class Session < Common::Base
      EXPIRATION_THRESHOLD_SECONDS = 20

      attribute :user_id, Integer
      attribute :expires_at, Common::UTCTime
      attribute :token, String

      def expired?
        return true if expires_at.nil?
        expires_at.to_i <= Time.now.utc.to_i + EXPIRATION_THRESHOLD_SECONDS
      end

      def valid?
        user_id.is_a?(Fixnum)
      end

      def original_json
        nil
      end
    end
  end
end
