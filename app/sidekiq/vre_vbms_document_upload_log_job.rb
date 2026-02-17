# frozen_string_literal: true

class VREVBMSDocumentUploadLogJob
  include Sidekiq::Job

  STATSD_KEY_PREFIX = 'worker.vre.vbms_document_upload_log_job'

  sidekiq_options retry: 2

  sidekiq_retries_exhausted do |msg, _ex|
    claim_id = msg['args'][0]
    Rails.logger.error("VREVBMSDocumentUploadLogJob: Claim ID #{claim_id} failed after all retries")
    StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
  end

  def perform(claim_id)
    claim = SavedClaim::VeteranReadinessEmploymentClaim.find(claim_id)
    parsed_form = claim.parsed_form
    document_id = parsed_form['documentId']
    signature_date = parsed_form['signatureDate']
    created_at = claim.created_at

    Rails.logger.info('VREVBMSDocumentUploadLogJobSuccess',
                      claim_id:,
                      document_id:,
                      signature_date:,
                      created_at:)
  rescue => e
    Rails.logger.error('VREVBMSDocumentUploadLogJobFailure',
                       claim_id:,
                       exception_class: e.class.name,
                       exception_message: e.message)
    raise # Re-raise to trigger Sidekiq retry
  end
end
