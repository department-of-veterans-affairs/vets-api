# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimOverview < Common::Resource
      attribute :id, Types::String
      attribute :type, Types::String
      attribute :subtype, Types::String
      attribute :completed, Types::Bool
      attribute :date_filed, Types::Date
      attribute :updated_at, Types::DateTime
    end
  end
end