# frozen_string_literal: true

class VREVBMSDocumentUploadJob
  include Sidekiq::Job

  STATSD_KEY_PREFIX = 'worker.vre.vbms_document_upload_job'

  sidekiq_options retry: 16

  sidekiq_retries_exhausted do |msg, _ex|
    claim_id = msg['args'][0]
    Rails.logger.error("VRE_VBMS_BACKFILL_RETRIES_EXHAUSTED: Claim ID #{claim_id} failed after all retries")
    StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
  end

  def perform(claim_id)
    claim = SavedClaim::VeteranReadinessEmploymentClaim.find(claim_id)
    updated_form = claim.parsed_form
    updated_form['signatureDate'] = claim.created_at.to_date
    claim.update!(form: updated_form.to_json)

    uuid = claim.user_account.present? ? claim.user_account.id : 'manual-run-missing-user-account'
    claim.upload_to_vbms(user: OpenStruct.new(uuid:))

    Rails.logger.info "VRE_VBMS_BACKFILL_SUCCESS: Claim ID #{claim_id} processed successfully"
  rescue => e
    Rails.logger.error "VRE_VBMS_BACKFILL_FAILURE: Claim ID #{claim_id} - #{e.class}: An error occurred during VBMS upload"
    raise # Re-raise to trigger Sidekiq retry
  end
end
