# frozen_string_literal: true

module VeteranVerification
  class DisabilityRatingSerializer < ActiveModel::Serializer
    attributes :rating_percentage, :effective_date, :decision
    type 'disability_ratings'

    def decision
      object.decision_text
    end
  end
end
