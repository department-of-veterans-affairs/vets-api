# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorney
    class OrganizationSerializer < BaseSerializer
      def type
        'organization'
      end

      delegate :name, to: :object

      delegate :phone, to: :object
    end
  end
end
