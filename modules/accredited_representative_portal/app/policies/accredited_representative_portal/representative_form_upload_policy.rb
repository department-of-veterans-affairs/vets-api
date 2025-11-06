# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    def submit?
      @record.present?
    end

    def submit_all_claim?
      submit?
    end

    def upload_scanned_form?
      @user.representative?
    end

    def upload_supporting_documents?
      @user.representative?
    end
  end
end
