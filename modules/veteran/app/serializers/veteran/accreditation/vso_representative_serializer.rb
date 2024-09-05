# frozen_string_literal: true

module Veteran
  module Accreditation
    class VSORepresentativeSerializer < BaseRepresentativeSerializer
      include JSONAPI::Serializer

      attribute :organization_names

      attribute :phone, &:phone_number
    end
  end
end
