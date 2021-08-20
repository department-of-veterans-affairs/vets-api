# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class IndividualRating < Common::Resource
      attribute :decision, Types::String
      attribute :effective_date, Types::Date
      attribute :rating_percentage, Types::Integer
      attribute :diagnostic_text, Types::String
    end
  end
end
