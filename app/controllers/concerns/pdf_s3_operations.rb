# frozen_string_literal: true

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
      form_data: claim.to_json,
      saved_claim: claim,
      saved_claim_id: claim.id,
      user_account_id: claim.user_account_id
    )
    FormSubmissionAttempt.create!(form_submission:, benefits_intake_uuid: claim.guid)
  end

  ## Returns the URL of an already-created PDF
  #
  #  @param claim [SavedClaim] the claim to upload
  #  @param created_at [Date] Date used in S3 bucket
  #  @param config [Config] SimpleFormsApi::FormRemediation::Configuration::Base needed for s3 settings
  #  @param form_class [PdfFormBase] the pdf filler class needed for overflow? ex: IncreaseCompensation::PdfFill::Va218940v1
  def s3_signed_url(claim, created_at, config:, form_class: nil)
    form_id = claim.form_id
    directory = dated_directory_name(form_id, created_at)
    s3_uploader = SimpleFormsApi::FormRemediation::Uploader.new(directory:, config:)
    final = overflow?(claim, created_at, form_class:)
    s3_uploader.get_s3_link("#{directory}/#{form_id}_#{claim.guid}#{final}.pdf") || nil
  rescue => e
    Rails.logger.warn(
      "[PdfS3Operations] S3 Fetch Signed Url | form #{form_id}", error: e.message
    )
    nil
  end

  # The last submission attempt is used to construct the S3 file path
  def last_form_submission_attempt(benefits_intake_uuid)
    FormSubmissionAttempt.where(benefits_intake_uuid:).order(:created_at).last
  end

  # Returns e.g. `12.11.25-Form21P-8416`
  def dated_directory_name(form_number, date = Time.now.utc.to_date)
    "#{date.strftime('%-m.%d.%y')}-Form#{form_number}"
  end

  ## returns a string to append to the filename based on existence of overflow pages.
  #  @param claim [SavedClaim] the claim to upload
  #  @param created_at [Date] Date/TimeStamp used in the file name
  #  @param form_class [PdfFormBase] the pdf filler class ex: IncreaseCompensation::PdfFill::Va218940v1
  #
  # the PDF Filler will append the string "_final" to the end of the file name if the data
  # overflows to addinational pages. because we dont hold on to the url or filename we have
  # to regenerate the pdf to determine if filename has changed.
  def overflow?(claim, created_at, form_class:)
    return '' if form_class.nil?

    merged_form_data = form_class.new(claim.parsed_form).merge_fields({})
    hash_converter = ::PdfFill::Filler.make_hash_converter(
      claim.form_id,
      form_class,
      created_at,
      {}
    )
    hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)
    hash_converter.extras_generator.text? ? '_final' : ''
  end
end
