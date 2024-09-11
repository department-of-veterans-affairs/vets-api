# frozen_string_literal: true

require 'csv'
require 'fileutils'

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
        raise 'Submission was not found' unless submission

        @benefits_intake_uuid = submission.benefits_intake_uuid

        assign_instance_variables(defaults)
      end

      def run
        log_info("Processing submission: #{benefits_intake_uuid}")

        FileUtils.mkdir_p(temp_directory_path)

        process_submission_files

        upload_temp_folder_to_s3

        FileUtils.rm_f(temp_directory_path)

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
        write_tempfile(submission_pdf_filename, Base64.decode64(generate_pdf_content))
      end

      def upload_temp_folder_to_s3
        Find.find(temp_directory_path) do |path|
          next if File.directory?(path)

          relative_path = path.sub(temp_directory_path, '')
          s3_path = "#{output_directory_path}/#{relative_path}"

          File.open(path, 'rb') do |file|
            pdf = save_file_to_s3(s3_path, file.read)
            sign_s3_file_url(pdf) if relative_path == submission_pdf_filename
          end
        end
      end

      def generate_pdf_content
        raise 'Missing PDF file to upload' unless file_path

        Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, File.basename(file_path))
      end

      def fetch_pdf
        path = "#{output_directory_path}/#{submission_pdf_filename}"
        s3_resource.bucket(target_bucket).object(path)
      end

      def submission_pdf_filename
        @submission_pdf_filename ||= "form_#{submission.form_data['form_number']}.pdf"
      end

      def sign_s3_file_url(pdf)
        pdf.presigned_url(:get, expires_in: 30.minutes.to_i)
      end

      def error_details(error)
        "#{error.message}\n\n#{error.backtrace.join("\n")}"
      end

      def write_as_json_archive
        form_json = JSON.parse(submission.form_data)
        write_tempfile('form_text_archive.json', JSON.pretty_generate(form_json))
      end

      def write_as_text_archive
        form_text_archive = submission.form_data['claimDate'] ||= submission.created_at.iso8601
        write_tempfile('form_text_archive.txt', form_text_archive.to_json)
      end

      def write_metadata
        write_tempfile('metadata.json', metadata.to_json)
      end

      def write_attachments
        log_info("Processing #{attachments.count} attachments")
        attachments.each_with_index { |upload, i| process_attachment(i + 1, upload) }
        write_attachment_failure_report if attachment_failures.present?
      rescue => e
        handle_upload_error(e)
      end

      def write_manifest
        veteran_id = metadata['fileNumber']
        submission_datetime = submission.created_at
        file_name = "submission_#{benefits_intake_uuid}_#{submission_datetime}_manifest.csv"

        "#{temp_directory_path}#{file_name}".tap do |file_path|
          CSV.open(file_path, 'wb') do |csv|
            csv << ['Veteran ID', 'Submission DateTime']
            csv << [veteran_id, submission_datetime]
          end
        end
      end

      def write_tempfile(file_name, payload)
        File.write("#{temp_directory_path}#{file_name}", payload)
      end

      def process_attachment(attach_num, attachment)
        log_info("Processing attachment ##{attach_num}: #{attachment}")
        local_file = PersistentAttachment.find_by(guid: attachment)
        raise 'Local record not found' unless local_file

        write_tempfile("attachment_#{attach_num}.pdf", local_file.to_pdf)
      rescue => e
        attachment_failures << e
        handle_error('Attachment failure.', e)
        raise e
      end

      def write_attachment_failure_report
        write_tempfile('attachment_failures.txt', JSON.pretty_generate(attachment_failures))
      end

      def save_file_to_s3(path, content)
        s3_resource.bucket(target_bucket).object(path).tap { |obj| obj.put(body: content) }
      end

      def output_directory_path
        @output_directory_path ||= "#{parent_dir}/#{benefits_intake_uuid}"
      end

      def attachment_failures
        @attachment_failures ||= []
      end

      def temp_directory_path
        @temp_directory_path ||= Rails.root.join("tmp/#{benefits_intake_uuid}-#{SecureRandom.hex}/").to_s
      end

      def attachment_path
        @attachment_path ||= "#{output_directory_path}/attachments"
      end
    end
  end
end
