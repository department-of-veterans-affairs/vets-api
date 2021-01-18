# frozen_string_literal: true

module Form1010cg
  class DeliverPdfToCARMAJob
    class MissingClaimException < StandardError; end

    include Sidekiq::Worker

    def perform(claim_guid)
      submission = Form1010cg::Submission.includes(:claim).find_by!(claim_guid: claim_guid)

      raise missing_claim_error if submission.claim.nil?

      file_path = submission.claim.to_pdf(sign: true)
      veteran_name = submission.claim.veteran_data['fullName']

      # submit_attachment! does an "upsert" of the document in CARMA,
      # so this job can safely be executed multiple times.
      carma_attachments = Form1010cg::Service.submit_attachment!(
        submission.carma_case_id,
        veteran_name,
        '10-10CG',
        file_path
      )

      record_success(claim_guid, submission.carma_case_id, carma_attachments.to_hash)

      delete_file file_path
      submission.destroy! # destroys the submission and claim
    end

    private

    def delete_file(file_path)
      File.delete(file_path) if File.exist?(file_path)
    rescue => e
      logger.error(e)
    end

    def missing_claim_error
      MissingClaimException.new(
        'Could not find a claim associated to this submission'
      )
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
