# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionArchiver < Utils
      attr_reader :benefits_intake_uuid, :file_path, :include_json_archive, :include_manifest, :include_text_archive,
                  :metadata, :parent_dir, :submission

      class << self
        def fetch_presigned_url(benefits_intake_uuid)
          instance = self.class.new(benefits_intake_uuid:)
          pdf = instance.fetch_pdf(benefits_intake_uuid)
          sign_s3_file_url(pdf)
        end
      end

      def initialize(benefits_intake_uuid: nil, submission: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

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
          attachments: [], # an array of attachment confirmation codes
          file_path: nil, # file path for the PDF file to be archived
          include_json_archive: true, # include the form data as a JSON object
          include_manifest: true, # include a CSV file containing Veteran ID & original submission datetime
          include_text_archive: true, # include the form data as a text file
          metadata: {}, # pertinent metadata for original file upload/submission
          parent_dir: 'vff-simple-forms' # S3 bucket base directory where files live
        }
      end

      def process_submission_files
        write_pdf
        write_as_json_archive if include_json_archive
        write_as_text_archive if include_text_archive
        write_attachments if attachments.present?
        write_manifest if include_manifest
        write_metadata
      end

      def write_pdf
        encoded_pdf = generate_pdf_content
        pdf = save_file_to_s3(
          "#{output_directory_path}/form_#{submission.form_data['form_number']}.pdf",
          Base64.decode64(encoded_pdf)
        )
        # TODO: do we want to immediately sign the pdf?
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
        pdf.presigned_url(:get, expires_in: 30.minutes.to_i)
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
        log_info("Moving #{attachments.count} attachments")
        attachments.each { |upload| process_attachment(upload) }
        write_attachment_failure_report if attachment_failures.present?
      rescue => e
        handle_upload_error(e)
      end

      # TODO: add this
      def write_manifest; end

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
