# frozen_string_literal: true

module TravelPay
  class ComplexClaimsFormChoiceSerializer
    include JSONAPI::Serializer

    attributes :expense_type, :form_progress

    delegate :expense_type, to: :object

    def form_progress
      object.form_progress || []
    end
  end
end
