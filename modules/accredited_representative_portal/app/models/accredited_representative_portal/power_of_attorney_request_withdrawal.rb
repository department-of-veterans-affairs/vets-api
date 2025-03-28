# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestWithdrawal < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving

    self.inheritance_column = nil

    module Types
      ALL = [
        REPLACEMENT = 'PowerOfAttorneyRequestReplacement'
      ].freeze
    end

    belongs_to :superseding_power_of_attorney_request,
               class_name: 'PowerOfAttorneyRequest',
               optional: true

    validates :type, inclusion: { in: Types::ALL }

    class << self
      def create_replacement!(**attrs)
        create_with_resolution!(type: Types::REPLACEMENT, **attrs)
      end

      private

      def create_with_resolution!(type:, superseding_power_of_attorney_request:, **resolution_attrs)
        PowerOfAttorneyRequestResolution.create_with_resolving!(
          resolving: new(type:, superseding_power_of_attorney_request:),
          **resolution_attrs
        )
      end
    end
  end
end
