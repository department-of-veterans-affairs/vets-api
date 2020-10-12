# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class LettersBeneficiarySerializer
      include FastJsonapi::ObjectSerializer
      set_type :evssLettersBeneficiaryResponses
      attributes :benefit_information, :military_service
    end
  end
end
