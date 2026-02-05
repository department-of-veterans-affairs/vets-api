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
    old_vbms_document_id = updated_form['documentId']
    updated_form['signatureDate'] = claim.created_at.to_date
    claim.update!(form: updated_form.to_json)

    uuid = claim.user_account.present? ? claim.user_account.id : 'manual-run-missing-user-account'
    claim.upload_to_vbms(user: OpenStruct.new(uuid:))

    new_vbms_document_id = claim.reload.parsed_form['documentId']

    Rails.logger.info('VRE_VBMS_BACKFILL_SUCCESS',
                      claim_id:,
                      old_vbms_document_id:,
                      new_vbms_document_id:)
  rescue => e
    Rails.logger.error('VRE_VBMS_BACKFILL_FAILURE',
                       claim_id:,
                       old_vbms_document_id:,
                       exception_class: e.class.name,
                       exception_message: e.message)
    raise # Re-raise to trigger Sidekiq retry
  end
end
