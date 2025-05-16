# frozen_string_literal: true

require 'vets/model'

module Mobile
  module V0
    class Rating
      include Vets::Model

      attribute :id, String
      attribute :combined_disability_rating, Integer
      attribute :individual_ratings, IndividualRating, array: true, default: []
    end
  end
end
