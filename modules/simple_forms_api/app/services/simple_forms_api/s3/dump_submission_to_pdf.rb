# frozen_string_literal: true

# To use
# ids = <array of submission ids to dump>
# parent_dir = <the name of the s3 'folder' where these dumps will be put>
#
# to see your dump in s3
# 1. go here https://console.amazonaws-us-gov.com/s3/home?region=us-gov-west-1#
# 2. login with 2fa
# 3. search for dsva-vetsgov-prod-reports
# 4. search for your parent_dir name, e.g. 526dump_aug_21st_2024
#
# If you do not provide a parent_dir, the script defaults to a folder called wipn8923-test
#
# OPTION 1: Run the script with user groupings
# - requires SubmissionDuplicateReport object
# - SubmissionDumpHandler.new(submission_ids: ids, parent_dir:).run
#
# OPTION 2: Run without user groupings
# ids.each { |id| DumpSubmissionToPdf.new(submission_id: id, parent_dir:).run }
# this will just put each submission in a folder by it's id under the parent dir
class DumpSubmissionToPdf
  attr_accessor :submission, :parent_dir, :failed_uploads, :include_text_dump,
                :quiet_upload_failures, :quiet_pdf_failures, :include_json_dump, :run_quiet

  def initialize(submission_id: nil, submission: nil, **options)
    defaults = default_options.merge(options)

    @failures = []
    @submission = defaults[:submission] || FormSubmission.find(submission_id)
    @parent_dir = defaults[:parent_dir]
    @include_text_dump = defaults[:include_text_dump]
    @include_json_dump = defaults[:include_json_dump]
    @quiet_upload_failures = defaults[:quiet_upload_failures]
    @quiet_pdf_failures = defaults[:quiet_pdf_failures]
  end

  def run
    log_info("    - submission id: #{submission.id}")
    write
    write_as_json_dump if include_json_dump
    write_as_text_dump if include_text_dump
    write_user_uploads if user_uploads.present?
    write_metadata
    output_directory_path
  rescue => e
    if run_quiet
      @failures << { id: submission.id, error: e.try(:message) || e }
      log_error("failed submission: #{submission.id}")
    else
      raise e
    end
  end

  private

  def default_options
    {
      parent_dir: 'wipn8923-test',
      include_text_dump: true, # include the form data as a text file
      include_json_dump: true, # include the form data as a JSON object
      quiet_upload_failures: true, # will skip problematic user uploads if true
      quiet_pdf_failures: true, # will skip the PDF generating if it's not working
      run_quiet: true
    }
  end

  def metadata
    @metadata ||= generate_metadata
  end

  def output_directory_path
    @output_directory_path ||= "#{parent_dir}/#{submission.id}"
  end

  def s3_resource
    @s3_resource ||= Reports::Uploader.new_s3_resource
  end

  def target_bucket
    @target_bucket ||= Reports::Uploader.s3_bucket
  end

  def form_json
    @form_json ||= JSON.parse(submission.form_json)['form']
  end

  # ##
  # File Writing Helpers:
  def write
    submission_create_date = submission.created_at.iso8601
    form_json['form']['claimDate'] ||= submission_create_date
    form_json['form']['applicationExpirationDate'] = 365.days.from_now.iso8601
    service = EVSS::DisabilityCompensationForm::NonBreakeredService.new(submission.auth_headers)
    response = service.get_form(form_json.to_json)
    encoded_pdf = response.body['pdf']
    content = Base64.decode64(encoded_pdf)
    object = s3_resource.bucket(target_bucket).object("#{output_directory_path}/form.pdf")
    object.put(body: content)
  rescue => e
    if quiet_pdf_failures
      write_pdf_error(e)
    else
      raise e
    end
  end

  def write_pdf_error(error)
    content = if error.present?
                "#{error.try(:message)}\n\n#{error.try(:messages).try(:join, "\n\t - ")}"
              else
                'unknown failure'
              end
  rescue
    content = 'unknown failure'
  ensure
    object = s3_resource.bucket(target_bucket).object("#{output_directory_path}/pdf_generating_failure_explanation.txt")
    object.put(body: content)
  end

  def write_as_json_dump
    object = s3_resource.bucket(target_bucket).object("#{output_directory_path}/form_text_dump.txt")
    content = JSON.pretty_generate(submission.form)
    object.put(body: content)
  end

  def write_alternative
    new_target = s3_resource.bucket(target_bucket).object("#{output_directory_path}/form.pdf")
    new_target.upload_file(form_initial_path)
    Common::FileHelpers.delete_file_if_exists(form_initial_path)
  end

  def write_metadata
    path = "#{output_directory_path}/metadata.txt"
    object = s3_resource.bucket(target_bucket).object(path)
    object.put(body: metadata.to_json)
  end

  def write_failure_report
    path = "#{output_directory_path}/user_upload_failures.txt"
    object = s3_resource.bucket(target_bucket).object(path)
    content = JSON.pretty_generate(user_upload_failures)
    object.put(body: content)
  end

  def write_as_text_dump
    path = "#{output_directory_path}/form_text_dump.txt"
    object = s3_resource.bucket(target_bucket).object(path)
    object.put(body: form_text_dump.to_json)
  end

  def form_text_dump
    @form_text_dump ||= generate_form_text_dump
  end

  def generate_form_text_dump
    form = submission.form
    return form if form['form'].blank?

    form['form']['claimDate'] ||= submission.created_at.iso8601
    form
  end

  def user_upload_path
    @user_upload_path ||= "#{output_directory_path}/user_uploads"
  end

  def user_uploads
    @user_uploads ||= submission.form['form_uploads']
  end

  def user_upload_failures
    @user_upload_failures ||= []
  end

  # ##
  # User Upload Processing:
  def write_user_uploads
    log_info("      Moving #{user_uploads.count} user uploads:")
    user_uploads.each do |upload|
      write_user_upload upload
    rescue => e
      if quiet_upload_failures
        user_upload_failures << {
          filename: upload['name'],
          confirmationCode: upload['attachmentId'],
          attachmentId: upload['attachmentId'],
          error: e.try(:message) || e || 'unknown error'
        }
      else
        raise e
      end
    end
    write_failure_report if user_upload_failures.present?
  end

  def write_user_upload(upload_data)
    log_info("        - processing upload: #{upload_data['name']} - #{upload_data['confirmationCode']}")
    local = SupportingEvidenceAttachment.find_by(guid: upload_data['confirmationCode'])
    raise 'No local record found' if local.blank?

    read_bucket = local.get_file.uploader.aws_bucket
    aws_path = local.get_file.path
    old_obj = s3_resource.bucket(read_bucket).object(aws_path)
    new_obj = s3_resource.bucket(target_bucket).object("#{user_upload_path}/#{upload_data['name']}")
    new_obj.copy_from(old_obj)
  end

  # ##
  # Metadata Processing:
  #   create metadata json with
  #     - vet PII
  #     - formsIncluded value indicates to the reviewing admin that nothing is missing
  #     - GUIDs of failed document uploads
  def generate_metadata
    return {} unless submission.auth_headers.present? && submission.form['form'].present?

    zc = submission.form.dig('form', 'veteran', 'currentMailingAddress')
    zipcode = zc.nil? ? '00000' : [zc['zipFirstFive'], zc['zipLastFour']].join('-')
    pii = JSON.parse(submission.auth_headers['va_eauth_authorization'])['authorizationResponse']
    pii.merge({
                fileNumber: pii['va_eauth_pnid'],
                birlsfilenumber: pii['va_eauth_birlsfilenumber'],
                zipCode: zipcode,
                claimDate: submission.created_at.iso8601,
                formsIncluded: map_form_inclusion
              })
  end

  def map_form_inclusion
    %w[form1 form2].select { |type| submission.form[type].present? }
  end

  def log_info(message, **details)
    Rails.logger.info(message, details)
  end

  def log_error(message, error, **details)
    Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
  end
end
