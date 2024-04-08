# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorney
    class RepresentativeSerializer < BaseSerializer
      attribute :type
      attribute :name
      attribute :email

      def type
        'representative'
      end

      def name
        object.full_name
      end

      def phone
        object.phone_number
      end
    end
  end
end
