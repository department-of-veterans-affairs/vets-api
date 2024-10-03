# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'simple_forms_api/form_submission_remediation/configuration/base'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchive
      def initialize(config: SimpleFormsApi::FormSubmissionRemediation::Configuration::Base.new, **options)
        @config = config
        @temp_directory_path = config.temp_directory_path
        @include_manifest = config.include_manifest || true
        @include_metadata = config.include_metadata || true

        assign_defaults(options)
        hydrate_submission_data unless submission_already_hydrated?
      rescue => e
        config.handle_error('SubmissionArchiveBuilder initialization failed', e)
      end

      def build!
        create_temp_directory
        process_submission_files
        [temp_directory_path, submission, submission_file_path]
      rescue => e
        config.handle_error("Failed building submission: #{id}", e)
      end

      private

      attr_reader :attachments, :config, :file_path, :id, :include_manifest, :include_metadata, :metadata, :submission,
                  :temp_directory_path

      def assign_defaults(options)
        # The file paths of any hydrated attachments which were originally included in the submission
        @attachments = options[:attachments]
        # The local path where the submission PDF is stored
        @file_path = options[:file_path]
        # The FormSubmission object representing the original data payload submitted
        @submission = options[:submission]
        # The UUID returned from the Benefits Intake API upon original submission
        @id = @submission&.send(config.id_type) || options[:id]
        # Data appended to the original submission headers
        @metadata = options[:metadata]
      end

      def submission_already_hydrated?
        submission && file_path && attachments && metadata
      end

      def hydrate_submission_data
        raise "No #{config.id_type} was provided" unless id

        built_submission = config.remediation_data_class.new(id:).hydrate!
        # The local path where the submission PDF is stored
        @file_path = built_submission.file_path
        # The FormSubmission object representing the original data payload submitted
        @submission = built_submission.submission
        # The UUID returned from the Benefits Intake API upon original submission
        @id = submission&.send(config.id_type)
        # The file paths of any hydrated attachments which were originally included in the submission
        @attachments = built_submission.attachments || []
        # Data appended to the original submission headers
        @metadata = built_submission.metadata
      end

      def create_temp_directory
        FileUtils.mkdir_p(config.temp_directory_path)
      end

      def process_submission_files
        [
          -> { write_pdf },
          -> { write_attachments if attachments&.any? },
          -> { write_manifest if include_manifest },
          -> { write_metadata if include_metadata }
        ].each do |task|
          safely_execute_task(task)
        end
      end

      def safely_execute_task(task)
        task.call
      rescue => e
        config.handle_error("Error during processing task: #{task.source_location}", e)
      end

      def write_pdf
        write_file("#{submission_file_path}.pdf", File.read(file_path), 'submission pdf')
      end

      def write_metadata
        write_file("metadata_#{submission_file_path}.json", metadata.to_json, 'metadata')
      end

      def write_attachments
        config.log_info("Processing #{attachments.count} attachments")
        attachments.each_with_index { |attachment, i| process_attachment(i + 1, attachment) }
      end

      def process_attachment(attachment_number, file_path)
        config.log_info("Processing attachment ##{attachment_number}: #{file_path}")
        write_file("attachment_#{attachment_number}__#{submission_file_path}.pdf", File.read(file_path), 'attachment')
      end

      def write_manifest
        file_name = "manifest_#{submission_file_path}.csv"
        manifest_path = File.join(temp_directory_path, file_name)

        CSV.open(manifest_path, 'wb') do |csv|
          csv << %w[SubmissionDateTime FormType VAGovID VeteranID FirstName LastName]
          csv << [
            submission.created_at,
            form_data_hash['form_number'],
            id,
            metadata['fileNumber'],
            metadata['veteranFirstName'],
            metadata['veteranLastName']
          ]
        end
      rescue => e
        config.handle_error("Failed writing manifest for submission: #{id}", e)
      end

      def write_file(file_name, payload, file_description)
        File.write(File.join(config.temp_directory_path, file_name), payload)
      rescue => e
        config.handle_error("Failed writing #{file_description} file #{file_name} for submission: #{id}", e)
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      rescue JSON::ParserError => e
        config.handle_error('Error parsing submission form data', e)
      end

      def submission_file_path
        form_number = form_data_hash['form_number']
        @submission_file_path ||= [
          Time.zone.today.strftime('%-m.%d.%y'), 'form', form_number, 'vagov', id
        ].join('_')
      end
    end
  end
end
