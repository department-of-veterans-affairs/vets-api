module PdfS3Operations
  extend ActiveSupport::Concern

  private

  # Upload to S3 and return a download URL
  # @param claim [SavedClaim] the claim to upload
  # @param config [SimpleFormsApi::FormRemediation::Configuration::Base] S3 config
  def upload_to_s3(claim, config:)
    form_submission_attempt = create_submission_attempt(claim)
    pdf_path = claim.to_pdf(claim.guid)

    begin
      File.open(pdf_path) do |file|
        directory = dated_directory_name(claim.form_id, form_submission_attempt.created_at.to_date)
        sanitized_file = CarrierWave::SanitizedFile.new(file)
        s3_uploader = SimpleFormsApi::FormRemediation::Uploader.new(directory:, config:)
        s3_uploader.store!(sanitized_file)
        s3_uploader.get_s3_link("#{directory}/#{sanitized_file.filename}")
      end
    ensure
      FileUtils.rm_f(pdf_path)
    end
  end

  # Creates a submission record used for dating the PDF
  def create_submission_attempt(claim)
    form_submission = FormSubmission.create!(
      form_type: claim.form_id,
      saved_claim: claim
    )
    FormSubmissionAttempt.create!(form_submission:, benefits_intake_uuid: claim.guid)
  end

  # Returns the URL of an already-created PDF
  def s3_signed_url(claim, created_at, config:)
    directory = dated_directory_name(claim.form_id, created_at)
    s3_uploader = SimpleFormsApi::FormRemediation::Uploader.new(directory:, config:)
    s3_uploader.get_s3_link("#{directory}/#{claim.form_id}_#{claim.guid}.pdf")
  end

  # The last submission attempt is used to construct the S3 file path
  def last_form_submission_attempt(benefits_intake_uuid)
    FormSubmissionAttempt.where(benefits_intake_uuid:).order(:created_at).last
  end

  # Returns e.g. `12.11.25-Form21P-8416`
  def dated_directory_name(form_number, date = Time.now.utc.to_date)
    "#{date.strftime('%-m.%d.%y')}-Form#{form_number}"
  end
end
