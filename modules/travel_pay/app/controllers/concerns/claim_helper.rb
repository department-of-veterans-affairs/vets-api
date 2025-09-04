# frozen_string_literal: true

module ClaimHelper
  extend ActiveSupport::Concern

  def create_claim(appt_id, claim_type)
    Rails.logger.info(message: "Create #{claim_type} claim")
    claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

    claim['claimId']
  end
end
