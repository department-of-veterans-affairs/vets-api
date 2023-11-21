# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimOverview < Common::Resource
      CACHE_VERSION = 1

      include Mobile::V0::Concerns::RedisCaching

      redis_config REDIS_CONFIG[:mobile_app_claims_store], CACHE_VERSION

      attribute :id, Types::String
      attribute :type, Types::String
      attribute :subtype, Types::String
      attribute :completed, Types::Bool
      attribute :date_filed, Types::Date
      attribute :updated_at, Types::Date
      attribute :display_title, Types::String
      attribute :decision_letter_sent, Types::Bool
    end
  end
end
