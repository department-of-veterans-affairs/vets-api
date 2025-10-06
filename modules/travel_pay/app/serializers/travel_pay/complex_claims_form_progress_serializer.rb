# frozen_string_literal: true

module TravelPay
  class ComplexClaimsFormProgressSerializer
    include JSONAPI::Serializer

    attribute :choices

    def choices
      object[:choices]
    end
  end
end
