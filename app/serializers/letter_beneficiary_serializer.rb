# frozen_string_literal: true

class LetterBeneficiarySerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :benefit_information
  attribute :military_service
end
