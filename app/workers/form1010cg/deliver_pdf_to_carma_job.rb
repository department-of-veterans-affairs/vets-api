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
      Form1010cg::Service.submit_attachment!(submission.carma_case_id, veteran_name, '10-10CG', file_path)
      delete_file file_path
      submission.destroy! # destroys the submission and claim
    end

    private

    def delete_file(file_path)
      File.delete(file_path) if File.exist?(file_path)
    rescue => e
      Rails.logger.error(e)
    end

    def missing_claim_error
      MissingClaimException.new(
        'Could not find a claim associated to this submission'
      )
    end
  end
end
