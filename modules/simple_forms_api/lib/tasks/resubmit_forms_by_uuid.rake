# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

# Invoke this as follows (tested on ZShell):
#   rails "simple_forms_api:resubmit_forms_by_uuid[abc-123 def-456]"
namespace :simple_forms_api do
  task :resubmit_forms_by_uuid, [:benefits_intake_uuids] => :environment do |_, args|
    benefits_intake_uuids = args[:benefits_intake_uuids].split
    benefits_intake_uuids.each do |benefits_intake_uuid|
      # Get the original submission
      form_submission_attempt = FormSubmissionAttempt.find_by(benefits_intake_uuid:)
      form_submission = form_submission_attempt&.form_submission
      next unless form_submission

      # Re-generate the form PDF
      form_id = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[form_submission.form_type]
      parsed_form_data = JSON.parse(form_submission.form_data)
      form = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
      filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, form:)
      file_path = filler.generate(timestamp: form_submission.created_at)
      metadata = SimpleFormsApiSubmission::MetadataValidator.validate(form.metadata,
                                                                      zip_code_is_us_based: form.zip_code_is_us_based)
      form.handle_attachments(file_path) if %w[vba_40_0247 vba_20_10207 vba_40_10007].include? form_id

      # Attempt to re-submit
      lighthouse_service = BenefitsIntake::Service.new
      location, uuid = lighthouse_service.request_upload
      FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
      Rails.logger.info(
        'Simple forms api - preparing to resubmit PDF to benefits intake',
        { location:, uuid: }
      )
      response = lighthouse_service.perform_upload(metadata: metadata.to_json, document: file_path,
                                                   upload_url: location)

      Rails.logger.info(
        'Simple forms api - resubmitted PDF to benefits intake',
        { status: response.status, uuid: }
      )
    end
  end
end
