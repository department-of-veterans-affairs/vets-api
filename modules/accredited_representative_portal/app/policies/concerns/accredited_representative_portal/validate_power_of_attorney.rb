# frozen_string_literal: true

module AccreditedRepresentativePortal
  module ValidatePowerOfAttorney
    extend ActiveSupport::Concern

    def authorize_poa
      @record.present?
    end
  end
end
