# frozen_string_literal: true

module Form1010cg
  class DeliverPdfToCARMAJob
    include Sidekiq::Worker

    def perform(claim_guid)
      submission = Form1010cg::Submission.find_by!(claim_guid: claim_guid)

      # submit_attachment! does an "upsert" of the document in CARMA,
      # so this job can safely be executed multiple times.
      Form1010cg::Service.new(submission.claim, submission).submit_attachment!
      submission.destroy!
    end

    private

    def delete_file(file_path)
      File.delete(file_path) if File.exist?(file_path)
    rescue => e
      Rails.logger.error(e)
    end
  end
end
