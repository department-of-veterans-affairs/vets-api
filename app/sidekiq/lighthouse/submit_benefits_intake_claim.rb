# frozen_string_literal: true

require 'central_mail/service'
require 'pdf_utilities/datestamp_pdf'
require 'pcpg/monitor'
require 'benefits_intake_service/service'
require 'lighthouse/benefits_intake/metadata'
require 'pdf_info'

module Lighthouse
  class SubmitBenefitsIntakeClaim
    include Sidekiq::Job
    include SentryLogging

    class BenefitsIntakeClaimError < StandardError; end

    FOREIGN_POSTALCODE = '00000'
    STATSD_KEY_PREFIX = 'worker.lighthouse.submit_benefits_intake_claim'

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    RETRY = 16

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.error(
        "Failed all retries on Lighthouse::SubmitBenefitsIntakeClaim, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(saved_claim_id)
      init(saved_claim_id)

      # Create document stamps
      @pdf_path = process_record(@claim)

      @attachment_paths = @claim.persistent_attachments.map { |record| process_record(record) }

      create_form_submission_attempt

      response = @lighthouse_service.upload_doc(**lighthouse_service_upload_payload)
      raise BenefitsIntakeClaimError, response.body unless response.success?

      Rails.logger.info('Lighthouse::SubmitBenefitsIntakeClaim succeeded', generate_log_details)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")

      send_confirmation_email

      @lighthouse_service.uuid
    rescue => e
      Rails.logger.warn('Lighthouse::SubmitBenefitsIntakeClaim failed, retrying...', generate_log_details(e))
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
      @form_submission_attempt&.fail!
      raise
    ensure
      cleanup_file_paths
    end

    def init(saved_claim_id)
      @claim = SavedClaim.find(saved_claim_id)

      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
    end

    def generate_metadata
      form = @claim.parsed_form
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']

      # also validates/manipulates the metadata
      ::BenefitsIntake::Metadata.generate(
        veteran_full_name['first'],
        veteran_full_name['last'],
        form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        address['postalCode'],
        "#{@claim.class} va.gov",
        @claim.form_id,
        @claim.business_line
      )
    end

    def process_record(record)
      document = stamp_pdf(record)

      @lighthouse_service.valid_document?(document:)
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.document_upload_error")
      raise e
    end

    def stamp_pdf(record)
      pdf_path = record.to_pdf
      # coordinates 0, 0 is bottom left of the PDF
      # This is the bottom left of the form, right under the form date, e.g. "AUG 2022"
      stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5,
                                                                   timestamp: record.created_at)
      # This is the top right of the PDF, above "OMB approved line"
      PDFUtilities::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      )
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

    def generate_log_details(e = nil)
      details = {
        claim_id: @claim&.id,
        benefits_intake_uuid: @lighthouse_service&.uuid,
        confirmation_number: @claim&.confirmation_number,
        form_id: @claim&.form_id
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
      FormSubmissionAttempt.transaction do
        form_submission = FormSubmission.create(
          form_type: @claim.form_id,
          form_data: @claim.to_json,
          saved_claim: @claim,
          saved_claim_id: @claim.id
        )
        @form_submission_attempt = FormSubmissionAttempt.create(form_submission:,
                                                                benefits_intake_uuid: @lighthouse_service.uuid)
      end
    end

    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@pdf_path) if @pdf_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    end

    def check_zipcode(address)
      address['country'].upcase.in?(%w[USA US])
    end

    def send_confirmation_email
      @claim.respond_to?(:send_confirmation_email) && @claim.send_confirmation_email
    rescue => e
      Rails.logger.warn('Lighthouse::SubmitBenefitsIntakeClaim send_confirmation_email failed',
                        generate_log_details(e))
      StatsD.increment("#{STATSD_KEY_PREFIX}.send_confirmation_email.failure")
    end
  end
end
