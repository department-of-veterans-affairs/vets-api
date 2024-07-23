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
    APPEAL_STATUSES = %w[complete error].freeze

    MAX_APPEAL_AGE_HOURS = 24

    def perform
      return unless enabled?

      evidence_to_submit_by_status.each(&:submit_to_central_mail!)
      evidence_to_submit_by_age.each(&:submit_to_central_mail!)
    end

    def evidence_to_submit_by_age
      # Get Supp Claims EvidenceSubmissions that have been uploaded to our s3 bucket, but not submitted to central_mail.
      # Preload the SupplementalClaim(supportable) association and the nested status_updates to get the submitted to
      # central mail date time to wait 24 hours after CM has the appeal to force the upload irregardless
      # of the appeal's status.
      ess = AppealsApi::EvidenceSubmission.includes(supportable: :status_updates).uploaded
                                          .where(supportable_type: APPEAL_TYPES)

      # filter out EvidenceSubmissions less than 24 hours old
      ess.filter do |es|
        # get the time since the supp claim itself was submited and accepted by central mail in hours
        cm_submitted_time = es.supportable.status_updates
                              .filter { |us| us.to == 'submitted' }
                              .max_by { |us| us.status_update_time.to_i }
                              &.status_update_time

        # if no status update to submitted record just use appeal created_at instead
        cm_submitted_time = es.supportable.created_at if cm_submitted_time.nil?

        # convert seconds to hours, if the appeal is older than the MAX_APPEAL_AGE_HOURS threshold
        # evidence submission needs to be uploaded to central mail
        (Time.zone.now - cm_submitted_time) / 3600.0 >= MAX_APPEAL_AGE_HOURS
      end
    end

    def evidence_to_submit_by_status
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
