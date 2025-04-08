# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    include ValidatePowerOfAttorney

    def submit?
      authorize_poa
    end

    def upload_scanned_form?
      authorize_poa
    end
  end
end
