# frozen_string_literal: true

# To use
# ids = <array of submission ids to archive>
# parent_dir = <the name of the s3 'folder' where these archives will be put>
#
# to see your archive in s3
# 1. go here https://console.amazonaws-us-gov.com/s3/home?region=us-gov-west-1#
# 2. login with 2fa
# 3. search for dsva-vetsgov-prod-reports
# 4. search for your parent_dir name, e.g. 526archive_aug_21st_2024
#
# If you do not provide a parent_dir, the script defaults to a folder called wipn8923-test
#
# OPTION 1: Run the script with user groupings
# - requires SubmissionDuplicateReport object
# - SubmissionArchiveHandler.new(submission_ids: ids, parent_dir:).run
#
# OPTION 2: Run without user groupings
# ids.each { |id| ArchiveSubmissionToPdf.new(submission_id: id, parent_dir:).run }
# this will just put each submission in a folder by it's id under the parent dir
module SimpleFormsApi
  module S3Service
    class ArchiveSubmissionToPdf < SimpleFormsApi::S3Service::Utils
      attr_reader :failures, :form_id, :include_json_archive, :include_text_archive,
                  :parent_dir, :quiet_pdf_failures, :quiet_upload_failures, :run_quiet,
                  :submission

      VALID_VFF_FORMS = %w[
        20-10206 20-10207 21-0845 21-0966 21-0972 21-10210
        21-4138 21-4142 21P-0847 26-4555 40-0247 40-10007
      ].freeze

      def initialize(form_id: nil, submission_id: nil, submission: nil, **options)
        defaults = default_options.merge(options)

        @failures = []
        @form_id = form_id
        @submission = submission || FormSubmission.find(submission_id)

        assign_instance_variables(defaults)
      end

      def run
        log_info("Processing submission ID: #{submission.id}")
        process_submission_files
        output_directory_path
      rescue => e
        handle_error("Failed submission: #{submission.id}", e, submission_id: submission.id)
      end

      private

      def default_options
        {
          include_json_archive: true, # include the form data as a JSON object
          include_text_archive: true, # include the form data as a text file
          parent_dir: 'wipn8923-test',
          quiet_pdf_failures: true, # skip PDF generation silently
          quiet_upload_failures: true, # skip problematic uploads silently
          run_quiet: true # silence but record errors, logged at the end
        }
      end

      def process_submission_files
        write_pdf
        write_as_json_archive if include_json_archive
        write_as_text_archive if include_text_archive
        write_user_uploads if user_uploads.present?
        write_metadata
      end

      def write_pdf
        encoded_pdf = generate_pdf_content
        save_file_to_s3("#{output_directory_path}/form.pdf", Base64.decode64(encoded_pdf))
      rescue => e
        quiet_pdf_failures ? write_pdf_error(e) : raise(e)
      end

      # TODO: update this method to support configurable pdf generation logic
      def generate_pdf_content
        service = EVSS::DisabilityCompensationForm::NonBreakeredService.new(submission.auth_headers)
        service.get_form(form_json.to_json).body['pdf']
      end

      def write_pdf_error(error)
        log_error("PDF generation failed for submission: #{submission.id}", error)
        save_file_to_s3("#{output_directory_path}/pdf_generating_failure.txt", error_details(error))
      end

      def error_details(error)
        "#{error.message}\n\n#{error.backtrace.join("\n")}"
      end

      def write_as_json_archive
        save_file_to_s3("#{output_directory_path}/form_text_archive.json", JSON.pretty_generate(form_json))
      end

      def write_as_text_archive
        save_file_to_s3("#{output_directory_path}/form_text_archive.txt", form_text_archive.to_json)
      end

      def write_metadata
        save_file_to_s3("#{output_directory_path}/metadata.json", metadata.to_json)
      end

      def write_user_uploads
        log_info("Moving #{user_uploads.count} user uploads")
        user_uploads.each { |upload| process_user_upload(upload) }
        write_failure_report if user_upload_failures.present?
      rescue => e
        handle_upload_error(e)
      end

      def process_user_upload(upload)
        log_info(
          "Processing upload: #{upload['name']} - #{upload['confirmationCode']}",
          { name: upload['name'], confirmation_code: upload['confirmationCode'] }
        )
        # TODO: update this logic in preference of a configurable attachment type
        local_file = SupportingEvidenceAttachment.find_by(guid: upload['confirmationCode'])
        raise 'Local record not found' unless local_file

        copy_file_between_buckets(local_file)
      end

      def copy_file_between_buckets(local_file)
        source_obj = s3_resource.bucket(local_file.get_file.uploader.aws_bucket).object(local_file.get_file.path)
        target_obj = s3_resource.bucket(target_bucket).object("#{user_upload_path}/#{local_file.get_file.filename}")
        target_obj.copy_from(source_obj)
      end

      def write_failure_report
        save_file_to_s3("#{output_directory_path}/user_upload_failures.txt", JSON.pretty_generate(user_upload_failures))
      end

      def save_file_to_s3(path, content)
        s3_resource.bucket(target_bucket).object(path).put(body: content)
      end

      def form_json
        @form_json ||= JSON.parse(submission.form_json)[form_id]
      end

      def form_text_archive
        submission.form.tap do |form|
          form[form_id]['claimDate'] ||= submission.created_at.iso8601
        end
      end

      def metadata
        return {} unless submission.auth_headers.present? && submission.form[form_id].present?

        extract_metadata_from_submission
      end

      # TODO: update this method to support configurable metadata
      def extract_metadata_from_submission
        address = submission.form.dig(form_id, 'veteran', 'currentMailingAddress')
        zip = [address['zipFirstFive'], address['zipLastFour']].join('-') if address.present?
        pii = JSON.parse(submission.auth_headers['va_eauth_authorization'])['authorizationResponse']
        pii.merge({
                    fileNumber: pii['va_eauth_pnid'],
                    zipCode: zip || '00000',
                    claimDate: submission.created_at.iso8601,
                    formsIncluded: map_form_inclusion
                  })
      end

      # TODO: update this method to check against configured form list
      def map_form_inclusion
        VALID_VFF_FORMS.select { |type| submission.form[type].present? }
      end

      def output_directory_path
        @output_directory_path ||= "#{parent_dir}/#{submission.id}"
      end

      def user_uploads
        @user_uploads ||= submission.form['form_uploads']
      end

      def user_upload_failures
        @user_upload_failures ||= []
      end

      def user_upload_path
        @user_upload_path ||= "#{output_directory_path}/user_uploads"
      end
    end
  end
end
