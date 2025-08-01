# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class TravelPayClaims < Common::Resource
      attribute :id, Types::String
      attribute :claims, Types::Array.of(TravelPayClaimSummary)
      attribute :total_count, Types::Integer
      attribute :page_number, Types::Integer
    end
  end
end
