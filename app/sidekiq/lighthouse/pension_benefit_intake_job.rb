# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'pension_21p527ez/tag_sentry'
require 'pension_21p527ez/monitor'
require 'pdf_utilities/datestamp_pdf'

##
# Sidekiq jobs sending claims to Lighthouse API
# @see https://developer.va.gov/explore/api/benefits-intake/docs
#
module Lighthouse
  ##
  # sidekig job to send pension pdf to Lighthouse:BenefitsIntake API
  #
  class PensionBenefitIntakeJob
    include Sidekiq::Job
    include SentryLogging

    # job processing error
    class PensionBenefitIntakeError < StandardError; end

    # tracking id for datadog metrics
    STATSD_KEY_PREFIX = 'worker.lighthouse.pension_benefit_intake_job'

    # `source` attribute for upload metadata
    PENSION_SOURCE = 'app/sidekiq/lighthouse/pension_benefit_intake_job.rb'

    # retry for one day
    sidekiq_options retry: 14, queue: 'low'
    sidekiq_retries_exhausted do |msg|
      pension_monitor = Pension21p527ez::Monitor.new
      begin
        claim = SavedClaim::Pension.find(msg['args'].first)
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

      # generate and validate claim pdf documents
      @form_path = process_document(@claim.to_pdf)
      @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
      @metadata = generate_metadata

      upload_document

      @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      @pension_monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

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
    # @private
    # Instantiate instance variables for _this_ job
    #
    # @raise [ActiveRecord::RecordNotFound] if unable to find UserAccount
    # @raise [PensionBenefitIntakeError] if unable to find SavedClaim::Pension
    #
    def init(saved_claim_id, user_account_uuid)
      Pension21p527ez::TagSentry.tag_sentry
      @pension_monitor = Pension21p527ez::Monitor.new

      @user_account_uuid = user_account_uuid
      @user_account = UserAccount.find(@user_account_uuid) unless @user_account_uuid.nil?
      # UserAccount.find will raise an error if unable to find the user_account record

      @claim = SavedClaim::Pension.find(saved_claim_id)
      raise PensionBenefitIntakeError, "Unable to find SavedClaim::Pension #{saved_claim_id}" unless @claim

      @intake_service = BenefitsIntake::Service.new
    end

    ##
    # @private
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
    # @private
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
    # @private
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
    # @private
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
    # @private
    # Delete temporary stamped PDF files for this job instance.
    #
    # @raise [PensionBenefitIntakeError] if unable to delete file
    #
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      @pension_monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
      raise PensionBenefitIntakeError, e.message
    end
  end
end
