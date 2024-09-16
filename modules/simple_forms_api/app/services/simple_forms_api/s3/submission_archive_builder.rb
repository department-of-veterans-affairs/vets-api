# frozen_string_literal: true

require 'csv'
require 'fileutils'
require_relative 'utils'

# built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiveBuilder < Utils
      def initialize(benefits_intake_uuid: nil, submission: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @submission = submission || FormSubmission.find_by(benefits_intake_uuid:)
        raise 'Submission was not found' unless @submission

        @benefits_intake_uuid = @submission.benefits_intake_uuid

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

      attr_reader :attachments, :benefits_intake_uuid, :file_path, :include_json_archive, :include_manifest,
                  :include_text_archive, :metadata, :submission

      def default_options
        {
          attachments: [], # an array of attachment confirmation codes
          file_path: nil, # file path for the PDF file to be archived
          include_json_archive: true, # include the form data as a JSON object
          include_manifest: true, # include a CSV file containing manifest data
          include_text_archive: true, # include the form data as a text file
          metadata: {} # pertinent metadata for original file upload/submission
        }
      end

      def process_submission_files
        write_pdf
        write_as_json_archive if include_json_archive
        write_as_text_archive if include_text_archive
        write_attachments unless attachments.empty?
        write_manifest if include_manifest
        write_metadata
      end

      def write_pdf
        write_tempfile(submission_pdf_filename, File.read(generate_pdf_content))
      end

      # TODO: this will be pulled out to be more team agnostic
      def generate_pdf_content
        file_path || create_pdf_content
      end

      def create_pdf_content
        form_number = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[submission.form_type]
        form = "SimpleFormsApi::#{form_number.titleize.delete(' ')}".constantize.new(form_data_hash)
        filler = SimpleFormsApi::PdfFiller.new(form_number:, form:)

        generate_file_data(filler, form, form_number)
      end

      def generate_file_data(filler, form, form_number)
        @file_path = filler.generate(timestamp: submission.created_at).tap do |path|
          validate_metadata(form)
          handle_attachments(form, form_number, path)
        end
      end

      def validate_metadata(form)
        @metadata = SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )
      end

      def handle_attachments(form, form_number, path)
        if %w[vba_40_0247 vba_40_10007].include?(form_number)
          form.handle_attachments(path)
        elsif form_number == 'vba_20_10207'
          @attachments = form.get_attachments
        end
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      end

      def submission_pdf_filename
        @submission_pdf_filename ||= "form_#{form_data_hash['form_number']}.pdf"
      end

      def error_details(error)
        "#{error.message}\n\n#{error.backtrace.join("\n")}"
      end

      def write_as_json_archive
        write_tempfile('form_json_archive.json', JSON.pretty_generate(form_data_hash))
      end

      def write_as_text_archive
        write_tempfile('form_text_archive.txt', form_data_hash.to_s)
      end

      def write_metadata
        write_tempfile('metadata.json', metadata.to_json)
      end

      def write_attachments
        log_info("Processing #{attachments.count} attachments")
        attachments.each_with_index { |upload, i| process_attachment(i + 1, upload) }
      rescue => e
        handle_upload_error(e)
      end

      # TODO: PDF attachments are the only attachment type that can be processed, change this
      def process_attachment(attachment_number, guid)
        log_info("Processing attachment ##{attachment_number}: #{guid}")
        attachment = PersistentAttachment.find_by(guid:).to_pdf
        raise 'Local record not found' unless attachment

        write_tempfile("attachment_#{attachment_number}.pdf", attachment)
      rescue => e
        attachment_failures << e
        handle_error('Attachment failure.', e)
      end

      def write_manifest
        file_name = "submission_#{benefits_intake_uuid}_#{submission.created_at}_manifest.csv"
        file_path = File.join(temp_directory_path, file_name)

        CSV.open(file_path, 'wb') do |csv|
          csv << ['Submission DateTime', 'Form Type', 'VA.gov ID', 'Veteran ID', 'First Name', 'Last Name']
          csv << [
            submission.created_at,
            form_data_hash['form_number'],
            benefits_intake_uuid,
            metadata['fileNumber'],
            metadata['veteranFirstName'],
            metadata['veteranLastName']
          ]
        end

        file_path
      end

      def write_tempfile(file_name, payload)
        File.write("#{temp_directory_path}#{file_name}", payload)
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
