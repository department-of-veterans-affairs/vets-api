# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'pension_21p527ez/tag_sentry'
require 'pension_21p527ez/monitor'
require 'pdf_utilities/datestamp_pdf'

module Lighthouse
  class PensionBenefitIntakeJob
    include Sidekiq::Job
    include SentryLogging

    class PensionBenefitIntakeError < StandardError; end

    STATSD_KEY_PREFIX = 'worker.lighthouse.pension_benefit_intake_job'
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

    # Process claim pdfs and upload to Benefits Intake API
    # https://developer.va.gov/explore/api/benefits-intake/docs
    #
    # On success send confirmation email
    # Raises PensionBenefitIntakeError
    #
    # @param [Integer] saved_claim_id
    #
    # rubocop:disable Metrics/MethodLength
    def perform(saved_claim_id, user_uuid = nil)
      init(saved_claim_id, user_uuid)

      # generate and validate claim pdf documents
      @form_path = process_document(@claim.to_pdf)
      @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
      @metadata = generate_metadata

      # upload must be performed within 15 minutes of this request
      @intake_service.request_upload
      @pension_monitor.track_submission_begun(@claim, @intake_service, @user_uuid)
      form_submission_polling

      payload = {
        upload_url: @intake_service.location,
        document: @form_path,
        metadata: @metadata.to_json,
        attachments: @attachment_paths
      }

      @pension_monitor.track_submission_attempted(@claim, @intake_service, @user_uuid, payload)
      response = @intake_service.perform_upload(**payload)
      raise PensionBenefitIntakeError, response.to_s unless response.success?

      @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      @pension_monitor.track_submission_success(@claim, @intake_service, @user_uuid)

      @intake_service.uuid
    rescue => e
      @pension_monitor.track_submission_retry(@claim, @intake_service, @user_uuid, e)
      @form_submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end
    # rubocop:enable Metrics/MethodLength

    private

    def init(saved_claim_id, user_uuid)
      Pension21p527ez::TagSentry.tag_sentry
      @pension_monitor = Pension21p527ez::Monitor.new

      @user_uuid = user_uuid
      @claim = SavedClaim::Pension.find(saved_claim_id)
      raise PensionBenefitIntakeError, "Unable to find SavedClaim::Pension #{saved_claim_id}" unless @claim

      @intake_service = BenefitsIntake::Service.new
    end

    # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
    #
    # @param [String] file_path
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
    # Generate form metadata to send in upload to Benefits Intake API
    #
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    # @see SavedClaim.parsed_form
    # @see BenefitsIntake::Metadata
    #
    # @return [Hash]
    #
    def generate_metadata
      form = @claim.parsed_form
      address = form['claimantAddress'] || form['veteranAddress']

      # also validates
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
    def form_submission_polling
      form_submission = FormSubmission.create(
        form_type: @claim.form_id,
        form_data: @claim.to_json,
        benefits_intake_uuid: @intake_service.uuid,
        saved_claim: @claim,
        saved_claim_id: @claim.id
      )
      @form_submission_attempt = FormSubmissionAttempt.create(form_submission:)

      Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @intake_service.uuid)
    end

    ##
    # Delete temporary stamped PDF files for this instance.
    #
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      @pension_monitor.track_file_cleanup_error(@claim, @intake_service, @user_uuid, e)
      raise PensionBenefitIntakeError, e.message
    end
  end
end
