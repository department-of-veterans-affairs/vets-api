# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module RapidReadyForDecision
  class DisabilityCompensationJob
    include Sidekiq::Worker
    include Sidekiq::Form526JobStatusTracker::JobTracker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    STATSD_KEY_PREFIX = 'worker.fast_track.disability_compensation_job'

    def perform(form526_submission_id)
      form526_submission = Form526Submission.find(form526_submission_id)

      begin
        with_tracking(self.class.name, form526_submission.saved_claim_id, form526_submission_id) do
          return if form526_submission.pending_eps?

          client = Lighthouse::VeteransHealth::Client.new(get_icn(form526_submission))

          return if bp_readings(client).blank?

          claim_context = RapidReadyForDecision::ClaimContext.new(form526_submission)
          add_bp_readings_stats(form526_submission, bp_readings(client))

          pdf = pdf(patient_info(form526_submission), bp_readings(client), medications(client))
          upload_pdf_and_attach_special_issue(claim_context, pdf)
        end
      rescue => e
        # only retry if the error was raised within the "with_tracking" block
        retryable_error_handler(e) if @status_job_title
        send_fast_track_engineer_email_for_testing(form526_submission_id, e.message, e.backtrace)
        raise
      end
    end

    class AccountNotFoundError < StandardError; end

    private

    def patient_info(form526_submission)
      form526_submission.full_name.merge(birthdate: form526_submission.auth_headers['va_eauth_birthdate'])
    end

    def bp_readings(client)
      @bp_readings ||= client.list_bp_observations
      @bp_readings.present? ? RapidReadyForDecision::LighthouseObservationData.new(@bp_readings).transform : []
    end

    def medications(client)
      @medications ||= client.list_medication_requests
      @medications.present? ? RapidReadyForDecision::LighthouseMedicationRequestData.new(@medications).transform : []
    end

    def add_bp_readings_stats(form526_submission, bp_readings)
      med_stats_hash = { bp_readings_count: bp_readings.size }
      form526_submission.save_metadata(med_stats: med_stats_hash)
    end

    def send_fast_track_engineer_email_for_testing(form526_submission_id, error_message, backtrace)
      # TODO: This should be removed once we have basic metrics
      # on this feature and the visibility is imporved.
      body = <<~BODY
        A claim errored in the #{Settings.vsp_environment} environment \
        with Form 526 submission id: #{form526_submission_id} and Sidekiq job id: #{jid}.<br/>
        <br/>
        The error was: #{error_message}. The backtrace was:\n #{backtrace.join(",<br/>\n ")}
      BODY
      ActionMailer::Base.mail(
        from: ApplicationMailer.default[:from],
        to: Settings.rrd.alerts.recipients,
        subject: 'Rapid Ready for Decision (RRD) Job Errored',
        body:
      ).deliver_now
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
      Account.find_by(edipi:) if edipi
    end

    def upload_pdf_and_attach_special_issue(claim_context, pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager.new(claim_context).handle_attachment(pdf.render)
      RapidReadyForDecision::RrdSpecialIssueManager.new(claim_context).add_special_issue
    end

    def pdf(patient_info, bpreadings, medications)
      assessed_data = {
        bp_readings: bpreadings,
        medications:
      }
      RapidReadyForDecision::FastTrackPdfGenerator.new(patient_info, assessed_data, :hypertension).generate
    end
  end
end
