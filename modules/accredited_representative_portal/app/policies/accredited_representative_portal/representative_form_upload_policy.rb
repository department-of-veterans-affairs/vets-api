# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    include ValidatePowerOfAttorney

    def submit?
      authorize_poa
    end

    def upload_scanned_form?
      @user.user_account.active_power_of_attorney_holders.size.positive?
    end

    def submit_supporting_documents?
      @user.user_account.active_power_of_attorney_holders.size.positive?
    end
  end
end
