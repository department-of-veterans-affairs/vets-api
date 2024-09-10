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
# ids.each { |id| SubmissionArchiver.new(submission_id: id, parent_dir:).run }
# this will just put each submission in a folder by it's id under the parent dir
module SimpleFormsApi
  module S3Service
    class SubmissionArchiver < Utils
      attr_reader :benefits_intake_uuid, :failures, :include_json_archive, :include_text_archive, :metadata,
                  :parent_dir, :submission

      class << self
        def fetch_presigned_url(benefits_intake_uuid)
          instance = self.class.new(benefits_intake_uuid:)
          instance.fetch_pdf(benefits_intake_uuid, form_number)
          # return presigned_url from object
        end
      end

      def initialize(benefits_intake_uuid: nil, submission: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @failures = []
        @submission = submission || FormSubmission.find_by(benefits_intake_uuid:)

        assign_instance_variables(defaults)
      end

      def run
        log_info("Processing submission ID: #{submission.id}")
        process_submission_files
        output_directory_path
      rescue => e
        handle_error("Failed submission: #{submission.id}", e, { submission_id: submission.id, benefits_intake_uuid: })
      end

      private

      def default_options
        {
          file_path: nil, # file path for the PDF file to be archived
          include_json_archive: true, # include the form data as a JSON object
          include_text_archive: true, # include the form data as a text file
          metadata: {}, # pertinent metadata for original file upload/submission
          parent_dir: 'vff-simple-forms', # S3 bucket base directory where files live
          uploads_path: ['uploadedFile'] # hierarchy where the attachments can be found
        }
      end

      def process_submission_files
        write_pdf
        write_as_json_archive if include_json_archive
        write_as_text_archive if include_text_archive
        write_attachments if attachments.present?
        write_metadata
      end

      def write_pdf
        encoded_pdf = generate_pdf_content
        pdf = save_file_to_s3(
          "#{output_directory_path}/form_#{submission.form_data['form_number']}.pdf",
          Base64.decode64(encoded_pdf)
        )
        sign_s3_file_url(pdf)
      end

      def generate_pdf_content
        raise 'Missing PDF file to upload' unless file_path

        Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, File.basename(file_path))
      end

      def fetch_pdf
        path = "#{output_directory_path}/form_#{submission.form_data['form_number']}.pdf"
        s3_resource.bucket(target_bucket).object(path)
      end

      def sign_s3_file_url(pdf)
        signed_url = pdf.presigned_url(:get, expires_in: 30.minutes.to_i)
        # TODO: How do we want to handle this?
        # submission.form_submission_attempts&.last&.update(signed_url:)
      end

      def error_details(error)
        "#{error.message}\n\n#{error.backtrace.join("\n")}"
      end

      def write_as_json_archive
        form_json = JSON.parse(submission.form_data)
        save_file_to_s3("#{output_directory_path}/form_text_archive.json", JSON.pretty_generate(form_json))
      end

      def write_as_text_archive
        form_text_archive = submission.form_data['claimDate'] ||= submission.created_at.iso8601
        save_file_to_s3("#{output_directory_path}/form_text_archive.txt", form_text_archive.to_json)
      end

      def write_metadata
        save_file_to_s3("#{output_directory_path}/metadata.json", metadata.to_json)
      end

      def write_attachments
        log_info("Moving #{attachments.count} user uploads")
        attachments.each { |upload| process_attachment(upload) }
        write_attachment_failure_report if attachment_failures.present?
      rescue => e
        handle_upload_error(e)
      end

      def process_attachment(attachment)
        log_info("Processing attachment: #{attachment}")
        local_file = PersistentAttachment.find_by(guid: attachment)
        raise 'Local record not found' unless local_file

        copy_file_between_buckets(local_file)
      rescue => e
        attachment_failures << e
        handle_error('Attachment failure.', e)
        raise e
      end

      def copy_file_between_buckets(local_file)
        source_obj = s3_resource.bucket(local_file.get_file.uploader.aws_bucket).object(local_file.get_file.path)
        target_obj = s3_resource.bucket(target_bucket).object("#{attachment_path}/#{local_file.get_file.filename}")
        target_obj.copy_from(source_obj)
      end

      def write_attachment_failure_report
        save_file_to_s3("#{output_directory_path}/attachment_failures.txt", JSON.pretty_generate(attachment_failures))
      end

      def save_file_to_s3(path, content)
        s3_resource.bucket(target_bucket).object(path).tap do |obj|
          obj.put(body: content)
        end
      end

      def output_directory_path
        @output_directory_path ||= "#{parent_dir}/#{benefits_intake_uuid}"
      end

      def attachment_failures
        @attachment_failures ||= []
      end

      def attachment_path
        @attachment_path ||= "#{output_directory_path}/attachments"
      end
    end
  end
end
