# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    def submit?
      @record.present?
    end

    def upload_scanned_form?
      @user.power_of_attorney_holders.size.positive?
    end

    def upload_supporting_documents?
      @user.power_of_attorney_holders.size.positive?
    end
  end
end
