# frozen_string_literal: true

module TravelPay
  class ComplexClaimsFormSessionSerializer
    include JSONAPI::Serializer

    has_many :complex_claims_form_choices

    def complex_claims_form_choices
      object.complex_claims_form_choices.order(:expense_type)
    end
  end
end
