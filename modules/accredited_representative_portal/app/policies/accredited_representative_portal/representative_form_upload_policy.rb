# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class RepresentativeFormUploadPolicy < ApplicationPolicy
    def submit?
      authorize
    end

    def upload_scanned_form?
      authorize
    end

    private

    def authorize
      return false unless @user

      poa_code_response = BenefitsClaims::Service.new(@record).get_power_of_attorney
      claimant_poa_code = poa_code_response.dig('data', 'attributes', 'code')

      return false if claimant_poa_code.blank?

      @user.user_account.active_power_of_attorney_holders.map(&:poa_code).include? claimant_poa_code
    end
  end
end
