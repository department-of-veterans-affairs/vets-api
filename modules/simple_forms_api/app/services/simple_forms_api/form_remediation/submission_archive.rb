# frozen_string_literal: true

require_relative 'file_utilities'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module FormRemediation
    class SubmissionArchive
      include FileUtilities

      def initialize(config:, **options)
        @config = config
        @temp_directory_path = config.temp_directory_path
        @include_manifest = config.include_manifest
        @include_metadata = config.include_metadata
        @manifest_entry = nil

        assign_data(options)
        hydrate_submission_data

        @form_number = JSON.parse(submission&.form_data)['form_number']
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def build!
        create_temp_directory!(temp_directory_path)
        process_submission_files

        return "#{submission_file_name}.pdf" if archive_type == :submission

        zip_path = zip_directory!(config.parent_dir, temp_directory_path, submission_file_name)

        [zip_path, manifest_entry]
      rescue => e
        config.handle_error("Failed building submission: #{id}", e)
      end

      private

      attr_reader :archive_type, :attachments, :config, :file_path, :form_number, :id, :include_manifest,
                  :include_metadata, :manifest_entry, :metadata, :submission, :temp_directory_path

      def assign_data(options)
        @archive_type = options[:type] || :remediation
        @attachments = options[:attachments] || []
        @file_path = options[:file_path]
        @id = options[:submission]&.send(config.id_type) || options[:id]
        @metadata = options[:metadata]
        @submission = options[:submission]
      end

      def submission_already_hydrated?
        submission && file_path && attachments && metadata
      end

      def hydrate_submission_data
        return if submission_already_hydrated?

        raise "No #{config.id_type} was provided" unless id

        built_submission = config.remediation_data_class.new(id:, config:).hydrate!

        assign_data(
          attachments: built_submission.attachments,
          file_path: built_submission.file_path,
          id: built_submission.submission&.send(config.id_type),
          metadata: built_submission.metadata,
          submission: built_submission.submission,
          type: @archive_type
        )
      end

      def process_submission_files
        [
          -> { write_pdf },
          -> { write_attachments if attachments&.any? },
          -> { build_manifest_csv_entry if include_manifest },
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
        create_file("#{submission_file_name}.pdf", File.read(file_path), 'submission pdf')
      end

      def write_metadata
        create_file("metadata_#{submission_file_name}.json", metadata.to_json, 'metadata')
      end

      def write_attachments
        config.log_info("Processing #{attachments.count} attachments")
        attachments.each_with_index { |attachment, i| process_attachment(i + 1, attachment) }
      end

      def process_attachment(attachment_number, file_path)
        config.log_info("Processing attachment ##{attachment_number}: #{file_path}")
        create_file("attachment_#{attachment_number}__#{submission_file_name}.pdf", File.read(file_path), 'attachment')
      end

      def build_manifest_csv_entry
        @manifest_entry = [
          submission.created_at,
          form_number,
          id,
          metadata['fileNumber'],
          metadata['veteranFirstName'],
          metadata['veteranLastName']
        ]
      end

      def create_file(file_name, payload, file_description)
        write_file(temp_directory_path, file_name, payload)
      rescue => e
        config.handle_error("Failed writing #{file_description} file #{file_name} for submission: #{id}", e)
      end

      def submission_file_name
        @submission_file_name ||= unique_file_name(form_number, id)
      end
    end
  end
end
