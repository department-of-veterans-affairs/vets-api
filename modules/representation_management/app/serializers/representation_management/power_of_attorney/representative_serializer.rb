# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorney
    class RepresentativeSerializer < BaseSerializer
      include JSONAPI::Serializer

      attribute :type do
        'representative'
      end

      attribute :email
      attribute :name, &:full_name
      attribute :phone, &:phone_number
    end
  end
end
