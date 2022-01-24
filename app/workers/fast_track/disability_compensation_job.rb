# frozen_string_literal: true

require 'prawn'
require 'prawn/table'
require 'lighthouse/veterans_health/client'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module FastTrack
  class DisabilityCompensationJob
    include Sidekiq::Worker
    include Sidekiq::Form526JobStatusTracker::JobTracker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    sidekiq_retries_exhausted do |msg, _ex|
      submission_id = msg['args'].first
      submission = Form526Submission.new
      submission.start_evss_submission(nil, { 'submission_id' => submission_id })
    end

    STATSD_KEY_PREFIX = 'worker.fast_track.disability_compensation_job'

    def perform(form526_submission_id, full_name)
      form526_submission = Form526Submission.find(form526_submission_id)
      client = Lighthouse::VeteransHealth::Client.new(get_icn(form526_submission))

      begin
        return if bp_readings(client).blank?

        with_tracking(self.class.name, form526_submission.saved_claim_id, form526_submission_id) do
          pdf = pdf(full_name, bp_readings(client), medications(client))
          upload_pdf_and_attach_special_issue(form526_submission, pdf)
        end
      rescue => e
        retryable_error_handler(e)
        send_fast_track_engineer_email_for_testing(form526_submission_id, e.message, e.backtrace)
        raise
      end
    end

    private

    def bp_readings(client)
      @bp_readings ||= client.list_resource('observations')
      @bp_readings.present? ? FastTrack::HypertensionObservationData.new(@bp_readings).transform : []
    end

    def medications(client)
      @medications ||= client.list_resource('medications')
      @medications.present? ? FastTrack::HypertensionMedicationRequestData.new(@medications).transform : []
    end

    def send_fast_track_engineer_email_for_testing(form526_submission_id, error_message, backtrace)
      # TODO: This should be removed once we have basic metrics
      # on this feature and the visibility is imporved.
      body = "A claim just errored on the #{Rails.env} environment " \
             "with submission id: #{form526_submission_id} and job_id #{jid}." \
             "The error was: #{error_message}. The backtrace was: #{backtrace}"
      ActionMailer::Base.mail(
        from: ApplicationMailer.default[:from],
        to: 'natasha.ibrahim@gsa.gov, emily.theis@gsa.gov, julia.l.allen@gsa.gov, tadhg.ohiggins@gsa.gov',
        subject: 'Fast Track Hypertension Errored',
        body: body
      ).deliver_now
    end

    def get_icn(form526_submission)
      account(form526_submission).icn.presence
    end

    def account(form526_submission)
      user_uuid = form526_submission.user_uuid
      @account ||= Account.where(idme_uuid: user_uuid)
                          .or(Account.where(logingov_uuid: user_uuid))
                          .or(Account.where(edipi: form526_submission.auth_headers['va_eauthdodedipnid'])).first!
    end

    def upload_pdf_and_attach_special_issue(form526_submission, pdf)
      FastTrack::HypertensionUploadManager.new(form526_submission).handle_attachment(pdf.render)
      if Flipper.enabled?(:disability_hypertension_compensation_fast_track_add_rrd)
        FastTrack::HypertensionSpecialIssueManager.new(form526_submission).add_special_issue
      end
    end

    def pdf(full_name, bpreadings, medications)
      FastTrack::HypertensionPdfGenerator.new(full_name, bpreadings, medications).generate
    end
  end
end
