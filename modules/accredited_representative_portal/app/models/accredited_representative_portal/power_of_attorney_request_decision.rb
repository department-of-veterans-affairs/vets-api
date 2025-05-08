# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving

    self.inheritance_column = nil

    delegate :declination_reason, to: :resolution, allow_nil: true

    module Types
      ALL = [
        ACCEPTANCE = 'PowerOfAttorneyRequestAcceptance',
        DECLINATION = 'PowerOfAttorneyRequestDeclination'
      ].freeze
    end

    belongs_to :creator, class_name: 'UserAccount'

    validates :type, inclusion: { in: Types::ALL }

    class << self
      def create_acceptance!(**attrs)
        create_with_resolution!(type: Types::ACCEPTANCE, **attrs)
      end

      def create_declination!(**attrs)
        create_with_resolution!(type: Types::DECLINATION, **attrs)
      end

      private

      def create_with_resolution!(creator:, type:, **resolution_attrs)
        PowerOfAttorneyRequestResolution.create_with_resolving!(
          resolving: new(type:, creator:),
          **resolution_attrs
        )
      end
    end

    def accepts_reasons?
      type == Types::DECLINATION
    end
  end
end
