# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module RapidReadyForDecision
  class Form526BaseJob
    include Sidekiq::Worker
    include Sidekiq::Form526JobStatusTracker::JobTracker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    # @return if this claim submission was processed and fast-tracked by RRD
    def self.rrd_claim_processed?(submission)
      submission.form_json.include? RapidReadyForDecision::FastTrackPdfUploadManager::DOCUMENT_TITLE
    end

    # Fetch all claims from EVSS and return whether there are any open EP 020's.
    # This method could be moved into a Concern when ProcessorSelector adds new job classes.
    def self.pending_eps?(form526_submission)
      all_claims = EVSS::ClaimsService.new(form526_submission.auth_headers).all_claims.body
      pending = all_claims['open_claims'].any? { |claim| claim['base_end_product_code'] == '020' }
      add_metadata(form526_submission, offramp_reason: 'pending_ep') if pending
      pending
    end

    # @param metadata_hash [Hash] to be merged into form526_submission.form_json['rrd_metadata']
    def self.add_metadata(form526_submission, metadata_hash)
      form_json = JSON.parse(form526_submission.form_json)
      form_json['rrd_metadata'] ||= {}
      form_json['rrd_metadata'].deep_merge!(metadata_hash)

      form526_submission.update!(form_json: JSON.dump(form_json))
      form526_submission.invalidate_form_hash
      form526_submission
    end

    def self.rrd_status(form526_submission)
      return :processed if RapidReadyForDecision::Form526BaseJob.rrd_claim_processed?(form526_submission)

      return :pending_ep if form526_submission.form.dig('rrd_metadata', 'offramp_reason') == 'pending_ep'

      :insufficient_data
    end

    def perform(form526_submission_id)
      form526_submission = Form526Submission.find(form526_submission_id)

      begin
        with_tracking(self.class.name, form526_submission.saved_claim_id, form526_submission_id) do
          return if RapidReadyForDecision::Form526BaseJob.pending_eps?(form526_submission)

          assessed_data = assess_data(form526_submission)
          return if assessed_data.nil?

          add_medical_stats(form526_submission, assessed_data)

          pdf = generate_pdf(form526_submission, assessed_data)
          upload_pdf(form526_submission, pdf)

          set_special_issue(form526_submission) if Flipper.enabled?(:rrd_add_special_issue)
        end
      rescue => e
        # only retry if the error was raised within the "with_tracking" block
        retryable_error_handler(e) if @status_job_title
        send_fast_track_engineer_email_for_testing(form526_submission_id, e.message, e.backtrace)
        raise
      end
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

      self.class.add_metadata(form526_submission, med_stats: med_stats_hash)
    end

    class AccountNotFoundError < StandardError; end

    private

    def lighthouse_client(form526_submission)
      Lighthouse::VeteransHealth::Client.new(get_icn(form526_submission))
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
        body: body
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
      Account.find_by(edipi: edipi) if edipi
    end

    def upload_pdf(form526_submission, pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager.new(form526_submission).handle_attachment(pdf.render)
    end

    def set_special_issue(form526_submission)
      RapidReadyForDecision::RrdSpecialIssueManager.new(form526_submission).add_special_issue
    end
  end
end
