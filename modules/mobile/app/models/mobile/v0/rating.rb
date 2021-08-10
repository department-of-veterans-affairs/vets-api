# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Rating < Common::Resource
      attribute :id, Types::String
      attribute :combined_disability_rating, Types::Integer
      attribute :combined_effective_date, Types::Date
      attribute :legal_effective_date, Types::Date
      attribute :individual_ratings, Types::Array
    end
  end
end
