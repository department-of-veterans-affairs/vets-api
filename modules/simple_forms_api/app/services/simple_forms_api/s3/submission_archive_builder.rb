# frozen_string_literal: true

require 'csv'
require 'fileutils'

module SimpleFormsApi
  module S3
    class SubmissionArchiveBuilder < Utils
      attr_reader :benefits_intake_uuid, :file_path, :include_json_archive, :include_manifest, :include_text_archive,
                  :metadata, :parent_dir, :submission

      def initialize(benefits_intake_uuid: nil, submission: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @submission = submission || FormSubmission.find_by(benefits_intake_uuid:)
        raise 'Submission was not found' unless submission

        @benefits_intake_uuid = submission.benefits_intake_uuid

        assign_instance_variables(defaults)
      end

      def run
        FileUtils.mkdir_p(temp_directory_path)

        process_submission_files

        temp_directory_path
      rescue => e
        handle_error("Failed building submission: #{submission.id}", e, { benefits_intake_uuid: })
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

      def generate_pdf_content
        regenerate_pdf_submission unless file_path

        Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, File.basename(file_path))
      end

      # TODO: this will be pulled out to be more team agnostic
      def regenerate_pdf_submission
        form_number = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[submission.form_type]
        parsed_form_data = JSON.parse(submission.form_data)
        form = "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        filler = SimpleFormsApi::PdfFiller.new(form_number:, form:)

        @file_path = filler.generate(timestamp: submission.created_at)
        @metadata = SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )

        form.handle_attachments(file_path) if %w[vba_40_0247 vba_20_10207 vba_40_10007].include? form_number

        @attachments = form.get_attachments if form_number == 'vba_20_10207'
      end

      def submission_pdf_filename
        @submission_pdf_filename ||= "form_#{submission.form_data['form_number']}.pdf"
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

      def process_attachment(attachment_number, guid)
        log_info("Processing attachment ##{attachment_number}: #{guid}")
        attachment = PersistentAttachment.find_by(guid:).to_pdf
        raise 'Local record not found' unless attachment

        write_tempfile("attachment_#{attachment_number}.pdf", attachment)
      rescue => e
        attachment_failures << e
        handle_error('Attachment failure.', e)
        raise e
      end

      def write_attachment_failure_report
        write_tempfile('attachment_failures.txt', JSON.pretty_generate(attachment_failures))
      end

      def attachment_failures
        @attachment_failures ||= []
      end

      def temp_directory_path
        @temp_directory_path ||= Rails.root.join("tmp/#{benefits_intake_uuid}-#{SecureRandom.hex}/").to_s
      end
    end
  end
end
