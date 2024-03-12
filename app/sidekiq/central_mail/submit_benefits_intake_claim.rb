require 'central_mail/service'
require 'central_mail/datestamp_pdf'
require 'pension_burial/tag_sentry'
require 'benefits_intake_service/service'
require 'simple_forms_api_submission/metadata_validator'
require 'pdf_info'

module CentralMail
  class SubmitBenefitsIntakeClaim
    include Sidekiq::Job
    include SentryLogging

    class BenefitsIntakeClaimError < StandardError; end

    def perform(saved_claim_id)
      PensionBurial::TagSentry.tag_sentry
      @saved_claim_id = saved_claim_id
      log_message_to_sentry('Attempting CentralMail::SubmitSavedClaimJob', :info, generate_sentry_details)

      # flipper logic will be put here

      # response = send_claim_to_central_mail(saved_claim_id)
      response = send_claim_to_benefits_intake(saved_claim_id)

      if response.success?
        update_submission('success')
        log_message_to_sentry('CentralMail::SubmitSavedClaimJob succeeded', :info, generate_sentry_details)

        @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      else
        raise BenefitsIntakeClaimError, response.body
      end
    rescue => e
      update_submission('failed')
      log_message_to_sentry(
        'CentralMail::SubmitBenefitsIntakeClaim failed, retrying...', :warn, generate_sentry_details(e)
      )
      raise
    end

    def send_claim_to_benefits_intake(saved_claim_id)
      @claim =    SavedClaim.find(saved_claim_id)
      @pdf_path = process_record(@claim)

      @attachment_paths = @claim.persistent_attachments.map do |record|
        process_record(record)
      end

      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)

      payload = generate_payload

      Rails.logger.info('Central::SubmitBenefitsIntakeClaim Upload', {
                          file: payload[:file],
                          attachments: payload[:attachments],
                          claim_id: @claim.id,
                          benefits_intake_uuid: @lighthouse_service.uuid,
                          confirmation_number: @claim.confirmation_number
                        })
      response = @lighthouse_service.upload_doc(**payload)

      create_form_submission_attempt(@lighthouse_service.uuid)
      response
    end

    def generate_payload
      {
        upload_url: @lighthouse_service.location,
        file: split_file_and_path(@pdf_path),
        metadata: generate_metadata.to_json,
        attachments: @attachment_paths.map(&method(:split_file_and_path))
      }
    end

    # rubocop:disable Metrics/MethodLength
    def generate_metadata
      form = @claim.parsed_form
      form_pdf_metadata = get_hash_and_pages(@pdf_path)
      number_attachments = @attachment_paths.size
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']
      receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'receiveDt' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
        'uuid' => @claim.guid,
        'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
        'source' => "#{@claim.class} va.gov",
        'hashV' => form_pdf_metadata[:hash],
        'numberAttachments' => number_attachments,
        'docType' => @claim.form_id,
        'numberPages' => form_pdf_metadata[:pages]
      }

      @attachment_paths.each_with_index do |file_path, i|
        j = i + 1
        attachment_pdf_metadata =     get_hash_and_pages(file_path)
        metadata["ahash#{j}"] =       attachment_pdf_metadata[:hash]
        metadata["numberPages#{j}"] = attachment_pdf_metadata[:pages]
      end

      SimpleFormsApiSubmission::MetadataValidator.validate(metadata)
    end

    def split_file_and_path(path)
      { file: path, file_name: path.split('/').last }
    end

    def create_form_submission_attempt(intake_uuid)
      form_submission = FormSubmission.create(
        form_type: @claim.form_id,
        form_data: @claim.to_json,
        benefits_intake_uuid: intake_uuid,
        saved_claim: @claim,
      )
      FormSubmissionAttempt.create(form_submission:)
    end
  end
end
