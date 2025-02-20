# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class ExpirationSerializer < ResolutionSerializer
      attribute(:type) { 'expiration' }
    end
  end
end
