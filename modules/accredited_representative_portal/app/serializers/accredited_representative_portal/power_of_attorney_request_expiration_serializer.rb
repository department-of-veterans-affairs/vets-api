# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestExpirationSerializer < PowerOfAttorneyRequestResolutionSerializer
    attribute(:type) { 'expiration' }
  end
end
