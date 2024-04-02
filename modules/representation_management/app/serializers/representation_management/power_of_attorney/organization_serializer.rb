# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorney
    class OrganizationSerializer < BaseSerializer
      attribute :type
      attribute :name

      def type
        'organization'
      end
    end
  end
end
