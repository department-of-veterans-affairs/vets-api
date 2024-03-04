# frozen_string_literal: true

module VeteranVerification
  class RatedDisabilitiesSerializer < ActiveModel::Serializer
    def id
      nil
    end

    type :disability_ratings

    attributes :combined_disability_rating, :combined_effective_date, :legal_effective_date, :individual_ratings
  end
end
