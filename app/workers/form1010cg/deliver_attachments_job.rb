# frozen_string_literal: true

module Form1010cg
  class DeliverAttachmentsJob
    class MissingClaimException < StandardError; end

    attr_reader :submission

    include Sidekiq::Worker

    sidekiq_retries_exhausted do |msg, _e|
      StatsD.increment(
        Form1010cg::Auditor.metrics.submission.failure.attachments,
        tags: { claim_guid: msg['args'][0] }
      )
    end

    def perform(claim_guid)
      find_submission(claim_guid)

      claim_pdf_path, poa_attachment_path = Form1010cg::Service.collect_attachments(submission.claim)

      # ::submit_attachment! does an "upsert" of the document in CARMA,
      # so this job can safely be executed multiple times.
      carma_attachments = Form1010cg::Service.submit_attachments!(
        submission.carma_case_id,
        veteran_name,
        claim_pdf_path,
        poa_attachment_path
      )

      record_success(claim_guid, submission.carma_case_id, carma_attachments.to_hash)
      delete_files(claim_pdf_path, poa_attachment_path)
      delete_resources(poa_attachment_path.present?)
    end

    private

    def find_submission(claim_guid)
      Raven.tags_context(claim_guid: claim_guid)
      @submission = Form1010cg::Submission.includes(:claim).find_by!(claim_guid: claim_guid)
      raise missing_claim_error if submission.claim.nil?
    end

    def claim
      submission.claim
    end

    def attachment
      @attachment ||= Form1010cg::Attachment.find_by(guid: claim.parsed_form['poaAttachmentId'])
    end

    def veteran_name
      claim.veteran_data['fullName']
    end

    def delete_resources(delete_attachment)
      attachment.destroy! if delete_attachment # deletes the DB record and S3 object
      submission.destroy! # destroys the submission and claim
    end

    def delete_files(claim_pdf_path, poa_attachment_path)
      delete_file(claim_pdf_path)
      delete_file(poa_attachment_path) if poa_attachment_path
    end

    def delete_file(file_path)
      File.delete(file_path) if File.exist?(file_path)
    rescue => e
      logger.error(e)
    end

    def record_success(claim_guid, carma_case_id, attachments_hash)
      auditor.record(
        :attachments_delivered,
        claim_guid: claim_guid,
        carma_case_id: carma_case_id,
        attachments: attachments_hash
      )
    end

    def auditor
      Form1010cg::Auditor.new(logger)
    end

    def missing_claim_error
      MissingClaimException.new('Could not find a claim associated to this submission')
    end
  end
end
