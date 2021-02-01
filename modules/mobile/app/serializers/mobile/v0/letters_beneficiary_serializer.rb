# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class LettersBeneficiarySerializer
      include JSONAPI::Serializer
      set_type :evssLettersBeneficiaryResponses
      attributes :benefit_information, :military_service

      def initialize(id, resource, options = {})
        resource = LettersBeneficiaryStruct.new(id, resource.benefit_information, resource.military_service)
        super(resource, options)
      end
    end

    LettersBeneficiaryStruct = Struct.new(:id, :benefit_information, :military_service)
  end
end
