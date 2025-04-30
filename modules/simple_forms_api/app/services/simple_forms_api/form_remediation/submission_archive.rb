# frozen_string_literal: true

require_relative 'file_utilities'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module FormRemediation
    class NoConfigurationError < StandardError; end

    class SubmissionArchive
      include FileUtilities

      def initialize(config:, **options)
        raise NoConfigurationError, 'No configuration was provided' unless config

        @config = config
        @temp_directory_path = config.temp_directory_path
        @pdf_already_exists = options[:file_path] && File.exist?(options[:file_path])

        initialize_data(options)
        hydrate_submission_data unless data_hydrated?
      rescue NoConfigurationError => e
        Rails.logger.error(e)
        raise e
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def build!
        create_directory!(temp_directory_path)
        process_files

        final_path = determine_final_path
        [final_path, manifest_entry]
      rescue => e
        config.handle_error("Failed building submission: #{id}", e)
      end

      def retrieval_data
        extension = archive_type == :submission ? 'pdf' : 'zip'
        final_path = "#{temp_directory_path}#{submission_file_name}.#{extension}"
        [final_path, manifest_entry]
      end

      private

      attr_reader :archive_type, :attachments, :config, :file_path, :id, :metadata, :pdf_already_exists, :submission,
                  :temp_directory_path

      def initialize_data(options)
        @archive_type ||= options.fetch(:type, :remediation)
        @attachments ||= options[:attachments]
        @file_path ||= options[:file_path]
        @id ||= fetch_id(options)
        @metadata ||= options[:metadata]
        @submission ||= options[:submission]
      end

      def fetch_id(options)
        options[:submission]&.latest_attempt&.send(config.id_type) || options[:id]
      end

      def data_hydrated?
        submission && file_path && attachments && metadata
      end

      def hydrate_submission_data
        raise "No #{config.id_type} was provided" unless id

        built_submission = if config.respond_to?(:create_remediation_data)
                             config.create_remediation_data(id:).hydrate!
                           else
                             config.remediation_data_class.new(id:, config:).hydrate!
                           end

        initialize_data(
          attachments: built_submission.attachments,
          file_path: built_submission.file_path,
          id: built_submission.submission&.latest_attempt&.send(config.id_type),
          metadata: built_submission.metadata,
          submission: built_submission.submission,
          type: archive_type
        )
      end

      def process_files
        processing_tasks.each { |task| safely_execute(task) }
      end

      def processing_tasks
        [
          -> { write_pdf },
          -> { write_attachments if attachments&.any? },
          -> { write_metadata if config.include_metadata }
        ]
      end

      def safely_execute(task)
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
        raise "Attachment file not found: #{file_path}" unless File.exist?(file_path)

        create_file("attachment_#{attachment_number}__#{submission_file_name}.pdf", File.read(file_path), 'attachment')
      end

      def data_exists_for_manifest?
        submission&.created_at && form_number && id && metadata
      end

      def manifest_entry
        return unless data_exists_for_manifest?

        [
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

      def determine_final_path
        return "#{temp_directory_path}#{submission_file_name}.pdf" if archive_type == :submission

        zip_directory!(config.parent_dir, temp_directory_path, submission_file_name)
      end

      def submission_file_name
        @submission_file_name ||= unique_file_name(form_number, id)
      end

      def form_number
        @form_number ||= metadata&.dig('docType') || submission_form_number
      end

      def submission_form_number
        submission ? JSON.parse(submission.form_data)['form_number'] : nil
      end
    end
  end
end
