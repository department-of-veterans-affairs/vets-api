# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'pensions/tag_sentry'
require 'pensions/monitor'
require 'pdf_utilities/datestamp_pdf'

module Pensions
  ##
  # sidekig job to send pension pdf to Lighthouse:BenefitsIntake API
  # @see https://developer.va.gov/explore/api/benefits-intake/docs
  #
  class PensionBenefitIntakeJob
    include Sidekiq::Job
    include SentryLogging

    ##
    # generic job processing error
    #
    class PensionBenefitIntakeError < StandardError; end

    # tracking id for datadog metrics
    STATSD_KEY_PREFIX = 'worker.lighthouse.pension_benefit_intake_job'

    # `source` attribute for upload metadata
    PENSION_SOURCE = __FILE__

    # retry for one day
    sidekiq_options retry: 14, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      pension_monitor = Pensions::Monitor.new
      begin
        claim = Pensions::SavedClaim.find(msg['args'].first)
      rescue
        claim = nil
      end
      pension_monitor.track_submission_exhaustion(msg, claim)
    end

    ##
    # Process claim pdfs and upload to Benefits Intake API
    # On success send confirmation email
    #
    # @param saved_claim_id [Integer] the pension claim id
    # @param user_account_uuid [UUID] the user submitting the form
    #
    # @return [UUID] benefits intake upload uuid
    #
    def perform(saved_claim_id, user_account_uuid = nil)
      init(saved_claim_id, user_account_uuid)

      return if form_submission_pending_or_success

      # generate and validate claim pdf documents
      @form_path = process_document(@claim.to_pdf)
      @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
      @metadata = generate_metadata

      upload_document

      @pension_monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

      send_confirmation_email

      @intake_service.uuid
    rescue => e
      @pension_monitor.track_submission_retry(@claim, @intake_service, @user_account_uuid, e)
      @form_submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end

    private

    ##
    # Instantiate instance variables for _this_ job
    #
    # @raise [ActiveRecord::RecordNotFound] if unable to find UserAccount
    # @raise [PensionBenefitIntakeError] if unable to find SavedClaim::Pension
    #
    # @param (see #perform)
    #
    def init(saved_claim_id, user_account_uuid)
      Pensions::TagSentry.tag_sentry
      @pension_monitor = Pensions::Monitor.new

      @user_account_uuid = user_account_uuid
      @user_account = UserAccount.find(@user_account_uuid) unless @user_account_uuid.nil?
      # UserAccount.find will raise an error if unable to find the user_account record

      @claim = Pensions::SavedClaim.find(saved_claim_id)
      raise PensionBenefitIntakeError, "Unable to find SavedClaim::Pension #{saved_claim_id}" unless @claim

      @intake_service = BenefitsIntake::Service.new
    end

    ##
    # Check FormSubmissionAttempts for record with 'pending' or 'success'
    #
    # @return true if FormSubmissionAttempt has 'pending' or 'success'
    # @return false if unable to find a FormSubmission or FormSubmissionAttempt not 'pending' or 'success'
    #
    def form_submission_pending_or_success
      @claim&.form_submissions&.any? do |form_submission|
        form_submission.non_failure_attempt.present?
      end || false
    end

    ##
    # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
    #
    # @param file_path [String] pdf file path
    #
    # @return [String] path to stamped PDF
    #
    def process_document(file_path)
      document = PDFUtilities::DatestampPdf.new(file_path).run(text: 'VA.GOV', x: 5, y: 5)
      document = PDFUtilities::DatestampPdf.new(document).run(
        text: 'FDC Reviewed - VA.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )

      @intake_service.valid_document?(document:)
    end

    ##
    # Upload generated pdf to Benefits Intake API
    #
    # @raise [PensionBenefitIntakeError] on upload failure
    #
    def upload_document
      # upload must be performed within 15 minutes of this request
      @intake_service.request_upload
      @pension_monitor.track_submission_begun(@claim, @intake_service, @user_account_uuid)
      form_submission_polling

      payload = {
        upload_url: @intake_service.location,
        document: @form_path,
        metadata: @metadata.to_json,
        attachments: @attachment_paths
      }

      @pension_monitor.track_submission_attempted(@claim, @intake_service, @user_account_uuid, payload)
      response = @intake_service.perform_upload(**payload)
      raise PensionBenefitIntakeError, response.to_s unless response.success?
    end

    ##
    # Generate form metadata to send in upload to Benefits Intake API
    #
    # @see SavedClaim.parsed_form
    # @see BenefitsIntake::Metadata#generate
    #
    # @return [Hash] generated metadata for upload
    #
    def generate_metadata
      form = @claim.parsed_form
      address = form['claimantAddress'] || form['veteranAddress']

      # also validates/maniuplates the metadata
      BenefitsIntake::Metadata.generate(
        form['veteranFullName']['first'],
        form['veteranFullName']['last'],
        form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        address['postalCode'],
        PENSION_SOURCE,
        @claim.form_id,
        @claim.business_line
      )
    end

    ##
    # Insert submission polling entries
    #
    # @see FormSubmission
    # @see FormSubmissionAttempt
    #
    def form_submission_polling
      form_submission = {
        form_type: @claim.form_id,
        form_data: @claim.to_json,
        benefits_intake_uuid: @intake_service.uuid,
        saved_claim: @claim,
        saved_claim_id: @claim.id
      }
      form_submission[:user_account] = @user_account unless @user_account_uuid.nil?

      @form_submission = FormSubmission.create(**form_submission)
      @form_submission_attempt = FormSubmissionAttempt.create(form_submission: @form_submission)

      Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @intake_service.uuid)
    end

    ##
    # Being VANotify job to send email to veteran
    #
    def send_confirmation_email
      @claim.respond_to?(:send_confirmation_email) && @claim.send_confirmation_email
    rescue => e
      @pension_monitor.track_send_confirmation_email_failure(@claim, @intake_service, @user_account_uuid, e)
    end

    ##
    # Delete temporary stamped PDF files for this job instance
    # catches any error, logs but does NOT re-raise - prevent job retry
    #
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      @pension_monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
    end
  end
end
