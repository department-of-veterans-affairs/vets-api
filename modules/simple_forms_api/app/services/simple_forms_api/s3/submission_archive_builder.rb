# frozen_string_literal: true

require 'csv'
require 'fileutils'
require_relative 'utils'

# built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiveBuilder < Utils
      def initialize(benefits_intake_uuid:, file_path:, submission:, attachments:, metadata:, **options) # rubocop:disable Lint/MissingSuper
        raise 'No benefits_intake_uuid was provided' unless benefits_intake_uuid

        @benefits_intake_uuid = benefits_intake_uuid
        @file_path = file_path || rebuilt_submission.file_path
        @submission = submission || rebuilt_submission.submission
        @attachments = attachments || rebuilt_submission.attachments
        @metadata = metadata || rebuilt_submission.metadata

        defaults = default_options.merge(options)
        assign_instance_variables(defaults)
      end

      def run
        FileUtils.mkdir_p(temp_directory_path)

        process_submission_files

        temp_directory_path
      rescue => e
        handle_error("Failed building submission: #{benefits_intake_uuid}", e)
      end

      private

      attr_reader :attachments, :benefits_intake_uuid, :file_path, :include_json_archive, :include_manifest,
                  :include_text_archive, :metadata, :submission

      def default_options
        {
          include_json_archive: true, # include the form data as a JSON object
          include_manifest: true, # include a CSV file containing manifest data
          include_text_archive: true # include the form data as a text file
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
        write_tempfile(submission_pdf_filename, File.read(file_path))
      end

      def rebuilt_submission
        @rebuilt_submission ||= SubmissionBuilder.new(benefits_intake_uuid:)
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

      def process_attachment(attachment_number, guid)
        log_info("Processing attachment ##{attachment_number}: #{guid}")
        attachment = PersistentAttachment.find_by(guid:).to_pdf
        raise "Attachment was not found: #{guid}" unless attachment

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
    end
  end
end
