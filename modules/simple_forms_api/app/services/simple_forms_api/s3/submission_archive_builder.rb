# frozen_string_literal: true

require 'csv'
require 'fileutils'
require_relative 'utils'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiveBuilder < Utils
      def initialize(**options) # rubocop:disable Lint/MissingSuper
        assign_defaults(options)
        hydrate_submission_data unless submission_already_hydrated?
      rescue => e
        handle_error('SubmissionArchiveBuilder initialization failed', e)
      end

      def run
        FileUtils.mkdir_p(temp_directory_path)
        process_submission_files
        [temp_directory_path, submission, submission_file_path]
      rescue => e
        handle_error("Failed building submission: #{benefits_intake_uuid}", e)
      end

      private

      attr_reader :attachments, :benefits_intake_uuid, :file_path, :include_manifest, :include_metadata, :metadata,
                  :submission

      def assign_defaults(options)
        # The file paths of hydrated attachments which were originally submitted
        @attachments = options[:attachments] || nil
        # The UUID returned from the Benefits Intake API upon original submission
        @benefits_intake_uuid = options[:benefits_intake_uuid] || nil
        # The local path where the submission PDF is stored
        @file_path = options[:file_path] || nil
        # Include a CSV file containing manifest data
        @include_manifest = options[:include_manifest] || true
        # Include a JSON file containing metadata of original submission
        @include_metadata = options[:include_metadata] || true
        # Data appended to the original submission headers
        @metadata = options[:metadata] || nil
        # The FormSubmission object representing the original data payload submitted
        @submission = options[:submission] || nil
      end

      def submission_already_hydrated?
        submission && file_path && attachments && metadata
      end

      def hydrate_submission_data
        raise 'No benefits_intake_uuid was provided' unless benefits_intake_uuid

        built_submission = SubmissionBuilder.new(benefits_intake_uuid:)
        @file_path = built_submission.file_path
        @submission = built_submission.submission
        @benefits_intake_uuid = @submission&.benefits_intake_uuid
        @attachments = built_submission.attachments || []
        @metadata = built_submission.metadata
      end

      def process_submission_files
        write_pdf
        write_attachments if attachments&.any?
        write_manifest if include_manifest
        write_metadata if include_metadata
      rescue => e
        handle_error('Error during submission files processing', e)
      end

      def write_pdf
        write_tempfile("#{submission_file_path}.pdf", File.read(file_path))
      rescue => e
        handle_error('Error during submission pdf processing', e)
      end

      def write_metadata
        write_tempfile("metadata_#{submission_file_path}.json", metadata.to_json)
      rescue => e
        handle_error('Error during metadata processing', e)
      end

      def write_attachments
        log_info("Processing #{attachments.count} attachments")
        attachments.each_with_index { |file_path, i| process_attachment(i + 1, file_path) }
      rescue => e
        handle_error('Error during attachments processing', e)
      end

      def process_attachment(attachment_number, file_path)
        log_info("Processing attachment ##{attachment_number}: #{file_path}")
        write_tempfile("attachment_#{attachment_number}__#{submission_file_path}.pdf", File.read(file_path))
      rescue => e
        handle_error("Failed processing attachment #{attachment_number} (#{file_path})", e)
      end

      def write_manifest
        file_name = "manifest_#{submission_file_path}.csv"
        manifest_path = File.join(temp_directory_path, file_name)

        CSV.open(manifest_path, 'wb') do |csv|
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
      rescue => e
        handle_error("Failed writing manifest for submission: #{benefits_intake_uuid}", e)
      end

      def write_tempfile(file_name, payload)
        File.write("#{temp_directory_path}#{file_name}", payload)
      rescue => e
        handle_error("Failed writing file #{file_name} for submission: #{benefits_intake_uuid}", e)
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      rescue => e
        handle_error('Error parsing submission form data', e)
      end

      def submission_file_path
        form_number = form_data_hash['form_number']
        @submission_file_path ||= [
          Time.zone.today.strftime('%-m.%d.%y'), 'form', form_number, 'vagov', benefits_intake_uuid
        ].join('_')
      end
    end
  end
end
