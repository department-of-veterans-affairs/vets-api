# frozen_string_literal: true

module Form1010cg
  class DeliverAttachmentsJob
    # class MissingClaimException < StandardError; end

    attr_reader :claim

    include Sidekiq::Worker

    def perform(claim_guid)
      find_claim(claim_guid)

      claim_pdf_path, poa_attachment_path = Form1010cg::Service.collect_attachments(claim)
      carma_attachments = Form1010cg::Service.submit_attachments!(
        submission.carma_case_id,
        veteran_name,
        claim_pdf_path,
        poa_attachment_path
      )

      record_success(claim_guid, submission.carma_case_id, carma_attachments.to_hash)
      delete_files(claim_pdf_path, poa_attachment_path)
      attachment&.destroy! # deletes the DB record and S3 object
      claim.destroy! # destroys the submission and claim
    end

    private

    def find_claim(claim_guid)
      @claim ||= SavedClaim::CaregiversAssistanceClaim.includes(:submission).find_by(guid: claim_guid)
    end

    def submission
      claim.submission
    end

    def attachment
      @attachment ||= Form1010cg::Attachment.find_by(guid: claim.parsed_form['poaAttachmentId'])
    end

    def veteran_name
      claim.veteran_data['fullName']
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
  end
end
