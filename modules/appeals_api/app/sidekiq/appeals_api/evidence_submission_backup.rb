# frozen_string_literal: true

require 'sidekiq'

# Ensures that appeal evidence received "late" (i.e. after the appeal itself has
# reached "success," "complete," or "error" status) is submitted to Central Mail
module AppealsApi
  class EvidenceSubmissionBackup
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false

    APPEAL_TYPES = [NoticeOfDisagreement.name, SupplementalClaim.name].freeze
    APPEAL_STATUSES = %w[success complete error].freeze

    def perform
      return unless enabled?

      evidence_to_submit.each(&:submit_to_central_mail!)
    end

    def evidence_to_submit
      preloaded_evidence_submissions.select { |es| APPEAL_STATUSES.include?(es.supportable.status) }
    end

    private

    def preloaded_evidence_submissions
      evidence_submissions = EvidenceSubmission.uploaded.preload(:supportable)

      preloader = ActiveRecord::Associations::Preloader.new
      preloader.preload(evidence_submissions.select { |es| APPEAL_TYPES.include?(es.supportable_type) },
                        supportable: :status)

      evidence_submissions
    end

    def enabled?
      Flipper.enabled?(:decision_review_delay_evidence)
    end
  end
end
