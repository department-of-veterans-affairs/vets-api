# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module RapidReadyForDecision
  class Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_base_job'

    include Sidekiq::Worker
    include Sidekiq::Form526JobStatusTracker::JobTracker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    class NoRrdProcessorForClaim < StandardError; end

    def perform(form526_submission_id)
      form526_submission = Form526Submission.find(form526_submission_id)

      begin
        processor_class = RapidReadyForDecision::Constants.processor_class(form526_submission)
        raise NoRrdProcessorForClaim unless processor_class

        with_tracking(self.class.name, form526_submission.saved_claim_id, form526_submission_id) do
          return if form526_submission.pending_eps?

          processor = processor_class.new(form526_submission)
          processor.run
        end
      rescue => e
        # only retry if the error was raised within the "with_tracking" block
        retryable_error_handler(e) if @status_job_title
        message = "Sidekiq job id: #{jid}. The error was: #{e.message}.<br/>" \
                  "The backtrace was:\n #{e.backtrace.join(",<br/>\n ")}"
        form526_submission.send_rrd_alert_email('Rapid Ready for Decision (RRD) Job Errored', message)
        raise
      end
    end

    ## Todo later: the following will be removed in a separate PR to keep this PR small

    # Override this method to prevent the submission from getting the PDF and special issue
    def release_pdf?(_form526_submission)
      true
    end

    # Return nil to discontinue processing (i.e., doesn't generate pdf or set special issue)
    def assess_data(_form526_submission)
      raise "Method `assess_data` should be overriden by the subclass #{self.class}"
    end

    # assessed_data is results from assess_data
    def generate_pdf(_form526_submission, _assessed_data)
      # This should call a general PDF generator so that subclasses don't need to override this
      raise "Method `generate_pdf` should be overriden by the subclass #{self.class}"
    end

    # Override this method to add to form526_submission.form_json['rrd_metadata']['med_stats']
    def med_stats_hash(_form526_submission, _assessed_data); end

    # @param assessed_data [Hash] results from assess_data
    def add_medical_stats(form526_submission, assessed_data)
      med_stats_hash = med_stats_hash(form526_submission, assessed_data)
      return if med_stats_hash.blank?

      form526_submission.add_metadata(med_stats: med_stats_hash)
    end

    class AccountNotFoundError < StandardError; end

    private

    def lighthouse_client(form526_submission)
      Lighthouse::VeteransHealth::Client.new(get_icn(form526_submission))
    end

    def get_icn(form526_submission)
      account_record = account(form526_submission)
      raise AccountNotFoundError, "for user_uuid: #{form526_submission.user_uuid} or their edipi" unless account_record

      account_record.icn.presence
    end

    def account(form526_submission)
      account = Account.lookup_by_user_uuid(form526_submission.user_uuid)
      return account if account

      edipi = form526_submission.auth_headers['va_eauth_dodedipnid'].presence
      Account.find_by(edipi: edipi) if edipi
    end

    def patient_info(form526_submission)
      form526_submission.full_name.merge(birthdate: form526_submission.auth_headers['va_eauth_birthdate'])
    end

    def upload_pdf(form526_submission, pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager
        .new(form526_submission)
        .handle_attachment(pdf.render, add_to_submission: release_pdf?(form526_submission))
    end

    def set_special_issue(form526_submission)
      return unless release_pdf?(form526_submission)

      RapidReadyForDecision::RrdSpecialIssueManager.new(form526_submission).add_special_issue
    end
  end
end
