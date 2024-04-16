# frozen_string_literal: true

require 'benefits_intake_service/service'
require 'central_mail/datestamp_pdf'
require 'simple_forms_api_submission/metadata_validator'
require 'pension_21p527ez/tag_sentry'
require 'pension_21p527ez/monitor'

module Lighthouse
  class PensionBenefitIntakeJob
    include Sidekiq::Job
    include SentryLogging

    class PensionBenefitIntakeError < StandardError; end

    STATSD_KEY_PREFIX = 'worker.lighthouse.pension_benefit_intake_job'
    FOREIGN_POSTALCODE = '00000'
    PENSION_BUSINESSLINE = 'PMC'
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
    # rubocop:disable Metrics/MethodLength
    def perform(saved_claim_id, user_uuid = nil)
      Pension21p527ez::TagSentry.tag_sentry
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id
      @claim = SavedClaim::Pension.find(saved_claim_id)
      raise PensionBenefitIntakeError, "Unable to find SavedClaim::Pension #{saved_claim_id}" unless @claim

      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
      pension_monitor.track_submission_begun(@claim, @lighthouse_service, @user_uuid)

      form_submission_polling

      @form_path = process_pdf(@claim.to_pdf)
      @attachment_paths = @claim.persistent_attachments.map { |pa| process_pdf(pa.to_pdf) }

      metadata = generate_form_metadata_lh
      payload = {
        upload_url: @lighthouse_service.location,
        file: split_file_and_path(@form_path),
        metadata: metadata.to_json,
        attachments: @attachment_paths.map(&method(:split_file_and_path))
      }

      pension_monitor.track_submission_attempted(@claim, @lighthouse_service, @user_uuid, payload)
      response = @lighthouse_service.upload_doc(**payload)

      check_success(response)
    rescue => e
      pension_monitor.track_submission_retry(@claim, @lighthouse_service, @user_uuid, e)
      @form_submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end
    # rubocop:enable Metrics/MethodLength

    # Create a temp stamped PDF, validate the PDF satisfies Benefits Intake specification
    #
    # Raises PensionBenefitIntakeError if PDF is invalid
    #
    # @param [String] pdf_path
    # @return [String] path to temp stamped PDF
    def process_pdf(pdf_path)
      stamped_path = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5)
      stamped_path = CentralMail::DatestampPdf.new(stamped_path).run(
        text: 'FDC Reviewed - va.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )

      response = BenefitsIntakeService::Service.new.validate_document(doc_path: stamped_path)
      raise PensionBenefitIntakeError, "Invalid Document: #{response}" unless response.success?

      stamped_path
    end

    # Format doc path to send in upload to Benefits Intake API
    #
    # @param [String] path
    # @return [Hash] { file:, file_name: }
    def split_file_and_path(path)
      { file: path, file_name: path.split('/').last }
    end

    # Generate form metadata to send in upload to Benefits Intake API
    #
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    # @see SavedClaim.parsed_form
    # @return [Hash]
    def generate_form_metadata_lh
      form = @claim.parsed_form
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
        'docType' => @claim.form_id,
        'businessLine' => PENSION_BUSINESSLINE,
        'source' => PENSION_SOURCE
      }

      SimpleFormsApiSubmission::MetadataValidator.validate(metadata)
    end

    # Check benefits service upload_form response. On success send confirmation email.
    #
    # Raises PensionBenefitIntakeError unless response.success?
    #
    # @param [Object] response
    def check_success(response)
      if response.success?
        pension_monitor.track_submission_success(@claim, @lighthouse_service, @user_uuid)

        @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      else
        raise PensionBenefitIntakeError, response.to_s
      end
    end

    # Insert submission polling entries
    def form_submission_polling
      form_submission = FormSubmission.create(
        form_type: @claim.form_id,
        form_data: @claim.to_json,
        benefits_intake_uuid: @lighthouse_service.uuid,
        saved_claim: @claim,
        saved_claim_id: @claim.id
      )
      @form_submission_attempt = FormSubmissionAttempt.create(form_submission:)

      Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @lighthouse_service.uuid)
    end

    # Delete temporary stamped PDF files for this instance.
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      pension_monitor.track_file_cleanup_error(@claim, @lighthouse_service, @user_uuid, e)
      raise e
    end

    private

    def pension_monitor
      Pension21p527ez::Monitor.new
    end
  end
end
