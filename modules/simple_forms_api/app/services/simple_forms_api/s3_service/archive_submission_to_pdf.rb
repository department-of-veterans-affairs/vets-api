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
# If you do not provide a parent_dir, the script defaults to a folder called vff-simple-forms
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
      attr_reader :failures, :include_json_archive, :include_text_archive, :metadata,
                  :parent_dir, :quiet_pdf_failures, :quiet_upload_failures, :run_quiet,
                  :submission

      VALID_VFF_FORMS = %w[
        20-10206 20-10207 21-0845 21-0966 21-0972 21-10210
        21-4138 21-4142 21P-0847 26-4555 40-0247 40-10007
      ].freeze

      def initialize(submission_id: nil, submission: nil, **options)
        defaults = default_options.merge(options)

        @failures = []
        @submission = submission || FormSubmission.find(submission_id)

        assign_instance_variables(defaults)
      end

      def run
        log_info("Processing submission ID: #{submission.id}")
        process_submission_files
        output_directory_path
      rescue => e
        handle_error("Failed submission: #{submission.id}", e, { submission_id: submission.id })
      end

      private

      def default_options
        {
          file_path: nil, # file path for the PDF file to be archived
          include_json_archive: true, # include the form data as a JSON object
          include_text_archive: true, # include the form data as a text file
          metadata: {},
          parent_dir: 'vff-simple-forms',
          quiet_pdf_failures: true, # skip PDF generation silently
          quiet_upload_failures: true, # skip problematic uploads silently
          run_quiet: true, # silence but record errors, logged at the end
          uploads_path: ['uploadedFile'] # hierarchy where the attachments can be found
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
        pdf = save_file_to_s3(
          "#{output_directory_path}/form_#{submission.form_data['form_number']}.pdf",
          Base64.decode64(encoded_pdf)
        )
        sign_s3_file_url(pdf)
      rescue => e
        quiet_pdf_failures ? write_pdf_error(e) : raise(e)
      end

      def generate_pdf_content
        raise 'Missing PDF file to upload' unless file_path

        Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, File.basename(file_path))
      end

      def sign_s3_file_url(pdf)
        signed_url = pdf.presigned_url(:get, expires_in: 1.year.to_i)
        submission.form_submission_attempts&.last&.update(signed_url:)
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
        s3_resource.bucket(target_bucket).object(path).tap do |obj|
          obj.put(body: content)
        end
      end

      def form_json
        @form_json ||= JSON.parse(submission.form_data)
      end

      def form_text_archive
        submission.form_data['claimDate'] ||= submission.created_at.iso8601
      end

      # TODO: update this method to check against configured form list
      def map_form_inclusion
        VALID_VFF_FORMS.select { |type| submission.form_number == type }
      end

      def output_directory_path
        @output_directory_path ||= "#{parent_dir}/#{submission.id}"
      end

      def user_uploads
        @user_uploads ||= submission.fetch(*uploads_path, nil)
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
