# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestExpiration < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving

    class << self
      def create_with_resolution!(**resolution_attrs)
        PowerOfAttorneyRequestResolution.create_with_resolving!(
          resolving: new,
          **resolution_attrs
        )
      end
    end
  end
end
