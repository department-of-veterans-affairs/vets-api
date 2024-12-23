# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestExpiration < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving
  end
end
