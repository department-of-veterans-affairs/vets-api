# frozen_string_literal: true

require 'central_mail/service'
require 'pdf_utilities/datestamp_pdf'
require 'pension_burial/tag_sentry'
require 'benefits_intake_service/service'
require 'simple_forms_api_submission/metadata_validator'
require 'pdf_info'

module Lighthouse
  class SubmitBenefitsIntakeClaim
    include Sidekiq::Job
    include SentryLogging
    class BenefitsIntakeClaimError < StandardError; end

    FOREIGN_POSTALCODE = '00000'
    STATSD_KEY_PREFIX = 'worker.lighthouse.submit_benefits_intake_claim'

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 14 will result in a run time of ~25 hours
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.error(
        "Failed all retries on Lighthouse::SubmitBenefitsIntakeClaim, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(saved_claim_id)
      @claim = SavedClaim.find(saved_claim_id)

      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
      @pdf_path = if @claim.form_id == '21P-530V2'
                    process_record(@claim, @claim.created_at, @claim.form_id)
                  else
                    process_record(@claim)
                  end
      @attachment_paths = @claim.persistent_attachments.map { |record| process_record(record) }

      create_form_submission_attempt

      response = @lighthouse_service.upload_doc(**lighthouse_service_upload_payload)
      raise BenefitsIntakeClaimError, response.body unless response.success?

      Rails.logger.info('Lighthouse::SubmitBenefitsIntakeClaim succeeded', generate_log_details)
      @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
    rescue => e
      Rails.logger.warn('Lighthouse::SubmitBenefitsIntakeClaim failed, retrying...', generate_log_details(e))
      @form_submission_attempt&.fail!
      raise
    ensure
      cleanup_file_paths
    end

    def generate_metadata
      form = @claim.parsed_form
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'zipCode' => address['postalCode'],
        'source' => "#{@claim.class} va.gov",
        'docType' => @claim.form_id,
        'businessLine' => @claim.business_line
      }

      SimpleFormsApiSubmission::MetadataValidator.validate(metadata, zip_code_is_us_based: check_zipcode(address))
    end

    def process_record(record, timestamp = nil, form_id = nil)
      pdf_path = record.to_pdf
      stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5, timestamp:)
      stamped_path2 = PDFUtilities::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      )
      if form_id.present? && ['21P-530V2'].include?(form_id)
        stamped_pdf_with_form(form_id, stamped_path2, timestamp)
      else
        stamped_path2
      end
    end

    def split_file_and_path(path)
      { file: path, file_name: path.split('/').last }
    end

    private

    def lighthouse_service_upload_payload
      {
        upload_url: @lighthouse_service.location,
        file: split_file_and_path(@pdf_path),
        metadata: generate_metadata.to_json,
        attachments: @attachment_paths.map(&method(:split_file_and_path))
      }
    end

    def stamped_pdf_with_form(form_id, path, timestamp)
      PDFUtilities::DatestampPdf.new(path).run(
        text: 'Application Submitted on va.gov',
        x: 425,
        y: 675,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp:,
        page_number: 5,
        size: 9,
        template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
        multistamp: true
      )
    end

    def generate_log_details(e = nil)
      details = {
        claim_id: @claim.id,
        benefits_intake_uuid: @lighthouse_service.uuid,
        confirmation_number: @claim.confirmation_number
      }
      details['error'] = e.message if e
      details
    end

    def create_form_submission_attempt
      Rails.logger.info('Lighthouse::SubmitBenefitsIntakeClaim job starting', {
                          claim_id: @claim.id,
                          benefits_intake_uuid: @lighthouse_service.uuid,
                          confirmation_number: @claim.confirmation_number
                        })
      form_submission = FormSubmission.create(
        form_type: @claim.form_id,
        form_data: @claim.to_json,
        benefits_intake_uuid: @lighthouse_service.uuid,
        saved_claim: @claim,
        saved_claim_id: @claim.id
      )
      @form_submission_attempt = FormSubmissionAttempt.create(form_submission:)
    end

    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@pdf_path) if @pdf_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    end

    def check_zipcode(address)
      address['country'].upcase.in?(%w[USA US])
    end
  end
end
