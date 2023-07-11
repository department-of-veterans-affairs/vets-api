# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Immunization < Common::Resource
      CACHE_VERSION = 1

      include Mobile::V0::Concerns::RedisCaching

      redis_config REDIS_CONFIG[:mobile_app_immunizations_store], CACHE_VERSION

      attribute :id, Types::String
      attribute :cvx_code, Types::Coercible::Integer.optional
      attribute :date, Types::DateTime.optional
      attribute :dose_number, Types::String.optional
      attribute :dose_series, Types::String.optional
      attribute :group_name, Types::String.optional
      attribute :location_id, Types::String.optional
      attribute :manufacturer, Types::String.optional
      attribute :note, Types::String.optional
      attribute :reaction, Types::String.optional
      attribute :short_description, Types::String.optional
    end
  end
end
