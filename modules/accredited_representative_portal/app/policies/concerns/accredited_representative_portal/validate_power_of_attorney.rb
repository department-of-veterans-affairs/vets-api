# frozen_string_literal: true

module AccreditedRepresentativePortal
  module ValidatePowerOfAttorney
    extend ActiveSupport::Concern

    def validate_claimant_representative
      @record.present?
    end
  end
end
