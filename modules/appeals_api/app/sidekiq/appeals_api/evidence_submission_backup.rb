# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

# Ensures that appeal evidence received "late" (i.e. after the appeal itself has
# reached "success," "complete," or "error" status) is submitted to Central Mail
module AppealsApi
  class EvidenceSubmissionBackup
    include Sidekiq::Job
    include Sidekiq::MonitoredWorker

    # Only retry for ~30 minutes since this job runs every hour
    sidekiq_options retry: 5

    APPEAL_TYPES = [NoticeOfDisagreement.name, SupplementalClaim.name].freeze
    APPEAL_STATUSES = %w[success complete error].freeze

    def perform
      return unless enabled?

      evidence_to_submit.each(&:submit_to_central_mail!)
    end

    def evidence_to_submit
      preloaded_evidence_submissions.select { |es| APPEAL_STATUSES.include?(es.supportable.status) }
    end

    def retry_limits_for_notification
      [5]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end

    private

    def preloaded_evidence_submissions
      evidence_submissions = EvidenceSubmission.uploaded.preload(:supportable)
      supported_evidence_submissions = evidence_submissions.select { |es| APPEAL_TYPES.include?(es.supportable_type) }
      preloader = ActiveRecord::Associations::Preloader.new(records: supported_evidence_submissions,
                                                            associations: { supportable: :status })
      preloader.call

      evidence_submissions
    end

    def enabled?
      Flipper.enabled?(:decision_review_delay_evidence)
    end
  end
end
