# frozen_string_literal: true

require 'jsonapi/serializer'
module Mobile
  module V0
    class LettersBeneficiarySerializer
      include JSONAPI::Serializer

      set_type :LettersBeneficiaryResponses

      attributes :benefit_information, :military_service
    end
  end
end
