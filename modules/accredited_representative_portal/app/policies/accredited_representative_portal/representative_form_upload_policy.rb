# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    include ValidatePowerOfAttorney

    def submit?
      authorize_poa
    end

    def upload_scanned_form?
      @user.user_account.power_of_attorney_holders_length.positive?
    end

    def upload_supporting_documents?
      @user.user_account.power_of_attorney_holders_length.positive?
    end
  end
end
