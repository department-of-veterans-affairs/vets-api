# frozen_string_literal: true

module RapidReadyForDecision
  class RrdProcessor
    attr_reader :form526_submission

    def initialize(form526_submission)
      @form526_submission = form526_submission
    end

    def run
      assessed_data = assess_data
      return if assessed_data.nil?

      add_medical_stats(assessed_data)

      pdf = generate_pdf(assessed_data)
      upload_pdf(pdf)

      set_special_issue if Flipper.enabled?(:rrd_add_special_issue)
    end

    # Return nil to discontinue processing (i.e., doesn't generate pdf or set special issue)
    def assess_data
      raise "Method `assess_data` should be overriden by the subclass #{self.class}"
    end

    # assessed_data is results from assess_data
    def generate_pdf(_assessed_data)
      # This should call a general PDF generator so that subclasses don't need to override this
      raise "Method `generate_pdf` should be overriden by the subclass #{self.class}"
    end

    # Override this method to prevent the submission from getting the PDF and special issue
    def release_pdf?
      true
    end

    def upload_pdf(pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager
        .new(form526_submission)
        .handle_attachment(pdf.render, add_to_submission: release_pdf?)
    end

    def set_special_issue
      return unless release_pdf?

      RapidReadyForDecision::RrdSpecialIssueManager.new(form526_submission).add_special_issue
    end

    # Override this method to add to form526_submission.form_json['rrd_metadata']['med_stats']
    def med_stats_hash(_assessed_data); end

    # @param assessed_data [Hash] results from assess_data
    def add_medical_stats(assessed_data)
      med_stats_hash = med_stats_hash(assessed_data)
      return if med_stats_hash.blank?

      form526_submission.add_metadata(med_stats: med_stats_hash)
    end

    def send_fast_track_engineer_email_for_testing(job_id, error_message, backtrace)
      # TODO: This should be removed once we have basic metrics
      # on this feature and the visibility is imporved.
      body = <<~BODY
        A claim errored in the #{Settings.vsp_environment} environment \
        with Form 526 submission id: #{form526_submission.id} and Sidekiq job id: #{job_id}.<br/>
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

    class AccountNotFoundError < StandardError; end

    private

    def lighthouse_client
      Lighthouse::VeteransHealth::Client.new(icn)
    end

    def icn
      account_record = account
      raise AccountNotFoundError, "for user_uuid: #{form526_submission.user_uuid} or their edipi" unless account_record

      account_record.icn.presence
    end

    def account
      account = Account.lookup_by_user_uuid(form526_submission.user_uuid)
      return account if account

      edipi = form526_submission.auth_headers['va_eauth_dodedipnid'].presence
      Account.find_by(edipi: edipi) if edipi
    end
  end
end
