# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorney
    class OrganizationSerializer < BaseSerializer
      include JSONAPI::Serializer

      attribute :type do
        'organization'
      end

      attribute :name
    end
  end
end
